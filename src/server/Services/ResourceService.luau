--!strict
--[[
	ResourceService (SERVER) — resource personal yang tersebar di dunia (ranting CP1; nanti batu/sesajen).

	Aturan:
	  - Tiap pemain punya set titik aktif sendiri (ActiveCount dari pool titik spawn). Pemain lain tidak
	    melihat atau menghabiskan resource ini.
	  - Pengambilan DIDETEKSI SERVER: pemain mendekati titik aktif (PickupRadius) -> terambil otomatis.
	    Tidak ada Remote dari client, jadi tidak bisa dipalsukan.
	  - Resource terambil -> hilang -> setelah RespawnDelay muncul di titik BERBEDA (bukan titik yang baru
	    diambil, dan bukan titik yang sedang aktif). Jumlah aktif tidak pernah melebihi ActiveCount.
	  - Daftar titik aktif ditulis ke Player attribute (ResourceConfig...Attribute, nama dipisah koma).
	    Client menggambar model lokal dari attribute itu (ResourceRenderer).
	  - Service ini TIDAK tahu soal quest; ia hanya memberi tahu lewat OnCollected. QuestService
	    yang menghitung progres.
	  - Bila set punya ItemId, item masuk inventory (InventoryService) SEBELUM OnCollected dipanggil.
	    Stack penuh / template Tool hilang = resource tidak terambil dan tetap di dunia.
	  - PickupMode "Prompt" (ranting CP1): pengambilan lewat ProximityPrompt TAHAN (Prompt.HoldDuration) yang
	    dibuat server di tiap Part titik spawn (nama "ResourcePrompt"). Server memvalidasi: titik aktif untuk
	    pemain itu, hold benar-benar dimulai (PromptButtonHoldBegan) dan berlangsung >= HoldDuration (diukur
	    SERVER, bukan engine), karakter hidup, dan jarak. Client hanya menyembunyikan prompt titik yang tidak
	    aktif untuk dirinya (ResourceRenderer); itu kosmetik, bukan keamanan. Tidak ada Remote baru.
	    Mode "Proximity" (default): deteksi jarak otomatis seperti semula.
	  - Template berupa Tool diubah menjadi Model saat disalin ke ReplicatedStorage agar client bisa menggambarnya.

	Template model: ServerStorage/<TemplatePath> disalin (klon) ke ReplicatedStorage/<AssetsFolder>/<AssetName>
	saat Activate pertama; asli tidak diubah. Bila template atau titik spawn tidak ditemukan, Activate
	gagal (return false + alasan) dan tidak ada yang muncul.

	API server:
	  ResourceService.Activate(player, setId) -> (boolean, string?)
	  ResourceService.Deactivate(player, setId)          -- hapus semua resource set itu untuk pemain
	  ResourceService.IsActive(player, setId) -> boolean
	  ResourceService.GetActive(player, setId) -> { string }
	  ResourceService.OnCollected(fn) -> disconnect      -- fn(player, setId, pointName)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("ResourceConfig") :: ModuleScript) :: any
local ItemConfig = require(Shared:WaitForChild("ItemConfig") :: ModuleScript) :: any
local ServerRoot = (script.Parent :: Instance).Parent :: Instance
local Interaction = require(ServerRoot:WaitForChild("Util"):WaitForChild("Interaction") :: ModuleScript) :: any
local InventoryService = require((script.Parent :: Instance):WaitForChild("InventoryService") :: ModuleScript) :: any

local PROMPT_NAME: string = Config.PromptName
-- Toleransi (detik) Triggered datang TERLAMBAT setelah HoldBegan; Triggered sah tiba tepat setelah hold selesai.
local MAX_HOLD_OVERRUN = 10

local ResourceService = {}

type SetState = {
	Active: { [string]: boolean },
	Count: number,
}

type PointPool = {
	List: { BasePart },
	ByName: { [string]: BasePart },
}

type CollectedCallback = (player: Player, setId: string, pointName: string) -> ()

local rng = Random.new()
local pools: { [string]: PointPool } = {}
local playerSets: { [Player]: { [string]: SetState } } = {}
local collectedCallbacks: { CollectedCallback } = {}
local started = false

type HoldRecord = {
	Prompt: ProximityPrompt,
	StartedAt: number,
}
-- Satu hold aktif per pemain; waktu mulai diukur server saat PromptButtonHoldBegan.
local holds: { [Player]: HoldRecord } = {}
local promptsBound: { [string]: boolean } = {}

--------------------------------------------------------------------------------
-- Util
--------------------------------------------------------------------------------

local function resolvePath(root: Instance, path: { string }): Instance?
	local current: Instance? = root
	for _, name in path do
		if current == nil then
			return nil
		end
		current = current:FindFirstChild(name)
	end
	return current
end

local function pathText(path: { string }): string
	return table.concat(path, ".")
end

local function writeAttribute(player: Player, def: any, state: SetState)
	local names: { string } = {}
	for name in state.Active do
		table.insert(names, name)
	end
	table.sort(names)
	player:SetAttribute(def.Attribute, table.concat(names, ","))
end

-- Titik spawn dicari saat dibutuhkan (dan di-cache setelah berhasil), bukan hanya saat Start,
-- agar tahan terhadap urutan load Workspace.
local function getPool(setId: string, def: any): PointPool?
	local cached = pools[setId]
	if cached ~= nil then
		return cached
	end

	local folder = resolvePath(Workspace, def.SpawnerFolder)
	if folder == nil then
		warn(`[ResourceService] Folder spawner Workspace.{pathText(def.SpawnerFolder)} tidak ditemukan (set {setId}).`)
		return nil
	end

	local pool: PointPool = { List = {}, ByName = {} }
	local prefix: string = def.SpawnerPrefix
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") and string.sub(child.Name, 1, #prefix) == prefix then
			if string.find(child.Name, ",", 1, true) ~= nil then
				warn(`[ResourceService] Titik '{child.Name}' dilewati: nama tidak boleh mengandung koma.`)
			elseif pool.ByName[child.Name] ~= nil then
				warn(`[ResourceService] Titik '{child.Name}' ganda; yang kedua dilewati.`)
			else
				table.insert(pool.List, child)
				pool.ByName[child.Name] = child
			end
		end
	end

	if #pool.List == 0 then
		warn(`[ResourceService] Tidak ada titik berawalan '{prefix}' di {folder:GetFullName()} (set {setId}).`)
		return nil
	end
	if #pool.List <= def.ActiveCount then
		warn(`[ResourceService] Set {setId}: titik ({#pool.List}) <= ActiveCount ({def.ActiveCount}); resource tidak bisa pindah ke titik lain.`)
	end

	pools[setId] = pool
	return pool
end

-- Salin template ke ReplicatedStorage agar client bisa menggambarnya.
local function toolToModel(tool: Tool): Model
	local model = Instance.new("Model")
	model.Name = tool.Name
	for _, child in tool:GetChildren() do
		if not child:IsA("BaseScript") then
			child.Parent = model
		end
	end
	local handle = model:FindFirstChild("Handle")
	if handle ~= nil and handle:IsA("BasePart") then
		model.PrimaryPart = handle
	end
	tool:Destroy()
	return model
end

local function ensureAsset(setId: string, def: any): boolean
	local folder = ReplicatedStorage:FindFirstChild(Config.AssetsFolder)
	if folder == nil then
		local created = Instance.new("Folder")
		created.Name = Config.AssetsFolder
		created.Parent = ReplicatedStorage
		folder = created
	end
	local assets = folder :: Instance
	if assets:FindFirstChild(def.AssetName) ~= nil then
		return true
	end

	local template = resolvePath(ServerStorage, def.TemplatePath)
	if template == nil then
		warn(`[ResourceService] Template ServerStorage.{pathText(def.TemplatePath)} tidak ditemukan (set {setId}).`)
		return false
	end
	local copy: Instance = template:Clone()
	if copy:IsA("Tool") then
		copy = toolToModel(copy) -- Tool bukan PVInstance; client perlu Model/BasePart
	end
	copy.Name = def.AssetName
	copy.Parent = assets
	return true
end

local function pickPoint(pool: PointPool, state: SetState, avoidName: string?): BasePart?
	local candidates: { BasePart } = {}
	for _, part in pool.List do
		if part.Parent ~= nil and not state.Active[part.Name] and part.Name ~= avoidName then
			table.insert(candidates, part)
		end
	end
	if #candidates == 0 then
		return nil
	end
	return candidates[rng:NextInteger(1, #candidates)]
end

local function isCurrent(player: Player, setId: string, state: SetState): boolean
	local sets = playerSets[player]
	return sets ~= nil and sets[setId] == state
end

--------------------------------------------------------------------------------
-- Spawn & pickup
--------------------------------------------------------------------------------

local function spawnOne(player: Player, setId: string, def: any, state: SetState, avoidName: string?)
	if not isCurrent(player, setId, state) or state.Count >= def.ActiveCount then
		return
	end
	local pool = pools[setId]
	if pool == nil then
		return
	end
	local part = pickPoint(pool, state, avoidName)
	if part == nil then
		return
	end
	state.Active[part.Name] = true
	state.Count += 1
	writeAttribute(player, def, state)
end

local function collect(player: Player, setId: string, def: any, state: SetState, pointName: string)
	-- Item masuk inventory dulu. Ditolak (stack penuh/template hilang) = resource tetap di dunia;
	-- dicoba lagi pada pemeriksaan berikutnya. Tidak ada yield di sini, jadi tidak ada celah ganda.
	if def.ItemId ~= nil and not InventoryService.AddItem(player, def.ItemId, 1) then
		return
	end

	state.Active[pointName] = nil
	state.Count -= 1
	writeAttribute(player, def, state)

	for _, callback in collectedCallbacks do
		local ok, err = pcall(callback, player, setId, pointName)
		if not ok then
			warn(`[ResourceService] OnCollected error: {tostring(err)}`)
		end
	end

	-- Callback (mis. QuestService) boleh menonaktifkan set; jangan respawn bila begitu.
	if not isCurrent(player, setId, state) then
		return
	end
	if def.RespawnDelay > 0 then
		task.delay(def.RespawnDelay, function()
			spawnOne(player, setId, def, state, pointName)
		end)
	else
		spawnOne(player, setId, def, state, pointName)
	end
end

--------------------------------------------------------------------------------
-- Pengambilan via ProximityPrompt tahan (PickupMode = "Prompt")
--------------------------------------------------------------------------------

local function debugReject(player: Player, setId: string, pointName: string, reason: string)
	if Config.Debug then
		print(`[ResourceService] Prompt ditolak: {player.Name} {setId}/{pointName}: {reason}`)
	end
end

local function holdNeeded(promptDef: any): number
	return math.max(0, promptDef.HoldDuration - promptDef.HoldTolerance)
end

local function onHoldBegan(player: Player, prompt: ProximityPrompt)
	holds[player] = { Prompt = prompt, StartedAt = os.clock() }
end

local function onHoldEnded(player: Player, prompt: ProximityPrompt, promptDef: any)
	local hold = holds[player]
	if hold == nil or hold.Prompt ~= prompt then
		return
	end
	-- Dilepas sebelum waktunya = batal. Dilepas setelah selesai dibiarkan: Triggered bisa tiba
	-- sebelum atau sesudah event ini, dan akan mengonsumsi catatan hold.
	if os.clock() - hold.StartedAt < holdNeeded(promptDef) then
		holds[player] = nil
	end
end

local function onPromptTriggered(player: Player, setId: string, def: any, prompt: ProximityPrompt, pointName: string)
	local hold = holds[player]
	holds[player] = nil -- satu hold = satu percobaan ambil

	local sets = playerSets[player]
	local state = if sets ~= nil then sets[setId] else nil
	if state == nil or not state.Active[pointName] then
		return debugReject(player, setId, pointName, "titik tidak aktif untuk pemain ini")
	end
	if hold == nil or hold.Prompt ~= prompt then
		return debugReject(player, setId, pointName, "tidak ada hold yang dimulai pada prompt ini (HoldBegan tidak diterima)")
	end

	local promptDef = def.Prompt
	local elapsed = os.clock() - hold.StartedAt
	if elapsed < holdNeeded(promptDef) then
		return debugReject(player, setId, pointName, `tahan terlalu singkat ({string.format("%.1f", elapsed)} dtk)`)
	end
	if elapsed > promptDef.HoldDuration + MAX_HOLD_OVERRUN then
		return debugReject(player, setId, pointName, "hold kedaluwarsa")
	end

	local root = Interaction.GetAliveRoot(player)
	local position = Interaction.GetPromptPosition(prompt)
	if root == nil or position == nil then
		return debugReject(player, setId, pointName, "karakter tidak hidup / posisi prompt tidak ada")
	end
	if (root.Position - position).Magnitude > prompt.MaxActivationDistance + promptDef.DistanceTolerance then
		return debugReject(player, setId, pointName, "terlalu jauh")
	end

	collect(player, setId, def, state, pointName)
end

-- Buat (sekali per set) satu prompt di tiap Part titik spawn dan sambungkan event-nya.
local function ensurePrompts(setId: string, def: any, pool: PointPool)
	if def.PickupMode ~= "Prompt" or promptsBound[setId] then
		return
	end
	promptsBound[setId] = true

	local promptDef = def.Prompt
	for _, part in pool.List do
		local existing = part:FindFirstChild(PROMPT_NAME)
		local prompt: ProximityPrompt
		if existing ~= nil and existing:IsA("ProximityPrompt") then
			prompt = existing
		else
			prompt = Instance.new("ProximityPrompt")
			prompt.Name = PROMPT_NAME
		end
		-- Config sebagai sumber kebenaran. Enabled tetap true di server; client menyembunyikan secara lokal
		-- prompt titik yang tidak aktif untuk dirinya (server tetap menolak pengambilan titik tidak aktif).
		prompt.ActionText = promptDef.ActionText
		prompt.ObjectText = promptDef.ObjectText
		prompt.HoldDuration = promptDef.HoldDuration
		prompt.MaxActivationDistance = promptDef.MaxActivationDistance
		prompt.RequiresLineOfSight = promptDef.RequiresLineOfSight
		prompt.Enabled = true
		prompt.Parent = part

		local pointName = part.Name
		prompt.PromptButtonHoldBegan:Connect(function(player: Player)
			onHoldBegan(player, prompt)
		end)
		prompt.PromptButtonHoldEnded:Connect(function(player: Player)
			onHoldEnded(player, prompt, promptDef)
		end)
		prompt.Triggered:Connect(function(player: Player)
			onPromptTriggered(player, setId, def, prompt, pointName)
		end)
	end
end

local function step()
	for player, sets in playerSets do
		local root = Interaction.GetAliveRoot(player)
		if root == nil then
			continue
		end
		local position = root.Position
		for setId, state in sets do
			local def = Config.Sets[setId]
			local pool = pools[setId]
			if pool == nil or def.PickupMode == "Prompt" then
				continue -- mode Prompt: pengambilan lewat ProximityPrompt, bukan jarak otomatis
			end
			-- Salinan daftar: state.Active berubah selama iterasi.
			local names: { string } = {}
			for name in state.Active do
				table.insert(names, name)
			end
			for _, name in names do
				if not isCurrent(player, setId, state) then
					break -- set dinonaktifkan oleh callback
				end
				local part = pool.ByName[name]
				if state.Active[name] and part ~= nil and part.Parent ~= nil then
					local delta = position - part.Position
					local horizontal = Vector3.new(delta.X, 0, delta.Z).Magnitude
					if horizontal <= def.PickupRadius and math.abs(delta.Y) <= def.VerticalTolerance then
						collect(player, setId, def, state, name)
					end
				end
			end
		end
	end
end

--------------------------------------------------------------------------------
-- API
--------------------------------------------------------------------------------

function ResourceService.Activate(player: Player, setId: string): (boolean, string?)
	local def = Config.Sets[setId]
	if def == nil then
		return false, `set '{setId}' tidak ada di ResourceConfig`
	end
	local sets = playerSets[player]
	if sets == nil then
		return false, "pemain tidak terdaftar"
	end
	if sets[setId] ~= nil then
		return true, nil -- sudah aktif
	end
	if def.ItemId ~= nil then
		if ItemConfig.Items[def.ItemId] == nil then
			return false, `ItemId '{def.ItemId}' tidak ada di ItemConfig`
		end
		if not InventoryService.IsAvailable(def.ItemId) then
			return false, "template Tool item tidak ditemukan"
		end
	end
	if def.PickupMode == "Prompt" then
		local p = def.Prompt
		if type(p) ~= "table" or type(p.HoldDuration) ~= "number" or p.HoldDuration <= 0 then
			return false, "PickupMode 'Prompt' butuh Prompt.HoldDuration > 0"
		end
		if type(p.HoldTolerance) ~= "number" or p.HoldTolerance < 0 or p.HoldTolerance >= p.HoldDuration then
			return false, "Prompt.HoldTolerance harus >= 0 dan < HoldDuration"
		end
		if type(p.MaxActivationDistance) ~= "number" or p.MaxActivationDistance <= 0 or type(p.DistanceTolerance) ~= "number" or p.DistanceTolerance < 0 then
			return false, "Prompt.MaxActivationDistance harus > 0 dan DistanceTolerance >= 0"
		end
	elseif def.PickupMode ~= nil and def.PickupMode ~= "Proximity" then
		return false, `PickupMode '{tostring(def.PickupMode)}' tidak dikenal`
	end
	if not ensureAsset(setId, def) then
		return false, "template resource tidak ditemukan"
	end
	local pool = getPool(setId, def)
	if pool == nil then
		return false, "titik spawn tidak ditemukan"
	end
	ensurePrompts(setId, def, pool)

	local state: SetState = { Active = {}, Count = 0 }
	sets[setId] = state

	-- Acak titik awal (Fisher-Yates pada salinan).
	local shuffled: { BasePart } = table.clone(pool.List)
	for i = #shuffled, 2, -1 do
		local j = rng:NextInteger(1, i)
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end
	for i = 1, math.min(def.ActiveCount, #shuffled) do
		state.Active[shuffled[i].Name] = true
		state.Count += 1
	end
	writeAttribute(player, def, state)
	return true, nil
end

function ResourceService.Deactivate(player: Player, setId: string)
	local def = Config.Sets[setId]
	local sets = playerSets[player]
	if def == nil or sets == nil or sets[setId] == nil then
		return
	end
	sets[setId] = nil -- membuat respawn tertunda menjadi no-op (isCurrent = false)
	player:SetAttribute(def.Attribute, "")
end

function ResourceService.IsActive(player: Player, setId: string): boolean
	local sets = playerSets[player]
	return sets ~= nil and sets[setId] ~= nil
end

function ResourceService.GetActive(player: Player, setId: string): { string }
	local names: { string } = {}
	local sets = playerSets[player]
	local state = if sets ~= nil then sets[setId] else nil
	if state ~= nil then
		for name in state.Active do
			table.insert(names, name)
		end
		table.sort(names)
	end
	return names
end

function ResourceService.OnCollected(callback: CollectedCallback): () -> ()
	table.insert(collectedCallbacks, callback)
	return function()
		local index = table.find(collectedCallbacks, callback)
		if index ~= nil then
			table.remove(collectedCallbacks, index)
		end
	end
end

function ResourceService.Start()
	if started then
		return
	end
	started = true

	local function onPlayerAdded(player: Player)
		playerSets[player] = {}
		for _, def in Config.Sets do
			player:SetAttribute(def.Attribute, "")
		end
	end
	-- Salin template ke ReplicatedStorage SEJAK AWAL, bukan menunggu Activate pertama. Client hanya menunggu
	-- template sebentar (ASSET_WAIT_TIMEOUT); pemain yang bergabung lebih dulu tidak boleh kehabisan waktu
	-- hanya karena pemain lain belum bicara ke NPC. Idempoten: Activate memanggil ensureAsset lagi.
	for setId, def in Config.Sets do
		ensureAsset(setId, def)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player: Player)
		playerSets[player] = nil
		holds[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= Config.CheckInterval then
			elapsed = 0
			step()
		end
	end)
end

return ResourceService
