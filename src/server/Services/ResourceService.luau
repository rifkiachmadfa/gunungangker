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
	local copy = template:Clone()
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
			if pool == nil then
				continue
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
	if not ensureAsset(setId, def) then
		return false, "template resource tidak ditemukan"
	end
	local pool = getPool(setId, def)
	if pool == nil then
		return false, "titik spawn tidak ditemukan"
	end

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
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player: Player)
		playerSets[player] = nil
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
