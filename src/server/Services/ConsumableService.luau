--!strict
--[[
	ConsumableService (SERVER) — makanan/minuman di dunia yang menambah Hunger/Thirst.

	Alur: pemain menekan ProximityPrompt -> server validasi -> SurvivalService.Add.

	Cara memasang di Studio (tanpa mengubah script):
	  1. Beri CollectionService tag "Food" (menambah Hunger) atau "Drink" (menambah Thirst)
	     pada Model/Part makanan atau minuman. Tag bisa diubah di SurvivalConfig.
	  2. Jika objek sudah punya ProximityPrompt (di dalamnya), prompt itu dipakai apa adanya.
	     Jika belum, server membuatkan satu (ActionText "Makan"/"Minum").
	  3. (Opsional) Attribute di objek: ConsumeAmount, ConsumeCooldown untuk override per objek.

	Validasi server: karakter hidup, tag masih terpasang, jarak ke prompt, cooldown per pemain,
	dan stat belum penuh (jika penuh: tidak ada efek dan cooldown tidak terpakai).
	Objek tidak dihapus setelah dipakai; state bersifat personal (cooldown per pemain).

	TOOL DI BACKPACK (Air, Ciki — reward CP1): Config.Consumables.Items[itemId].
	  InventoryService memanggil OnToolCreated setiap Tool item dibuat; di sini Tool.Activated disambung.
	  Pemain meng-equip Tool lalu menekan/mengetuk -> server validasi -> SurvivalService.Add.
	  Validasi server: Tool sedang di-equip pemain itu (Parent = Character), karakter hidup, item benar-benar
	  dimiliki (InventoryService.GetCount, bukan sekadar ada Tool-nya), stat belum penuh (penuh: tidak ada
	  efek dan cooldown tidak terpakai), cooldown per pemain per item. Tool tidak habis dipakai (DEC-018).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SurvivalConfig") :: ModuleScript) :: any
local ItemConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ItemConfig") :: ModuleScript) :: any
local SurvivalService = require((script.Parent :: Instance):WaitForChild("SurvivalService") :: ModuleScript) :: any
local InventoryService = require((script.Parent :: Instance):WaitForChild("InventoryService") :: ModuleScript) :: any

local AMOUNT_ATTRIBUTE = "ConsumeAmount"
local COOLDOWN_ATTRIBUTE = "ConsumeCooldown"
local MAX_COOLDOWN = 3600
-- Awalan key cooldown Tool di lastUse, agar tidak bentrok dengan typeName (Food/Drink) scope Player.
local ITEM_KEY_PREFIX = "Item:"

local ConsumableService = {}

type Binding = {
	Prompt: ProximityPrompt,
	CreatedPrompt: boolean,
	Connection: RBXScriptConnection,
}

-- bindings[typeName][instance]
local bindings: { [string]: { [Instance]: Binding } } = {}
-- lastUse[player][key] = os.clock() terakhir berhasil. key = Instance (scope Object) atau typeName (scope Player).
local lastUse: { [Player]: { [any]: number } } = {}
-- Item Tool yang lolos validasi config: itemDefs[itemId] = Config.Consumables.Items[itemId].
local itemDefs: { [string]: any } = {}
local started = false

local function readNumberAttribute(instance: Instance, name: string, default: number, minValue: number, maxValue: number): number
	local value = instance:GetAttribute(name)
	if type(value) == "number" and value == value and value >= minValue and value <= maxValue then
		return value
	end
	return default
end

local function getPromptPosition(prompt: ProximityPrompt): Vector3?
	local parent = prompt.Parent
	if parent == nil then
		return nil
	end
	if parent:IsA("BasePart") then
		return parent.Position
	elseif parent:IsA("Attachment") then
		return parent.WorldPosition
	elseif parent:IsA("Model") then
		return parent:GetPivot().Position
	end
	return nil
end

local function getAliveRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root ~= nil and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function onTriggered(instance: Instance, typeName: string, def: any, binding: Binding, player: Player)
	-- Objek sudah dihapus / tag dicabut.
	if instance.Parent == nil or not CollectionService:HasTag(instance, def.Tag) then
		return
	end
	local prompt = binding.Prompt

	-- Karakter hidup + jarak (jangan percaya client; Triggered bisa dipanggil exploit dari jauh).
	local root = getAliveRoot(player)
	if root == nil then
		return
	end
	local promptPosition = getPromptPosition(prompt)
	if promptPosition == nil then
		return
	end
	local maxDistance = prompt.MaxActivationDistance + Config.Consumables.DistanceTolerance
	if (root.Position - promptPosition).Magnitude > maxDistance then
		return
	end

	-- Stat sudah penuh: tidak ada efek, cooldown tidak terpakai.
	local statDef = Config.Stats[def.Stat]
	local current = SurvivalService.Get(player, def.Stat)
	if statDef == nil or current == nil or current >= statDef.Max then
		return
	end

	-- Cooldown per pemain.
	local amount = readNumberAttribute(instance, AMOUNT_ATTRIBUTE, def.Amount, 0, statDef.Max)
	local cooldown = readNumberAttribute(instance, COOLDOWN_ATTRIBUTE, def.Cooldown, 0, MAX_COOLDOWN)
	local key: any = if Config.Consumables.CooldownScope == "Player" then typeName else instance
	local playerUse = lastUse[player]
	if playerUse == nil then
		return -- pemain sudah keluar
	end
	local now = os.clock()
	local last = playerUse[key]
	if last ~= nil and now - last < cooldown then
		return
	end

	if amount <= 0 then
		return
	end
	if SurvivalService.Add(player, def.Stat, amount) ~= nil then
		playerUse[key] = now
	end
end

local function onToolActivated(player: Player, itemId: string, tool: Tool)
	local def = itemDefs[itemId]
	if def == nil then
		return
	end

	-- Tool harus sedang di-equip pemain ini dan karakternya hidup.
	local character = player.Character
	if character == nil or tool.Parent ~= character or getAliveRoot(player) == nil then
		return
	end

	-- Kepemilikan dari data server (InventoryService), bukan dari keberadaan Tool.
	if InventoryService.GetCount(player, itemId) < 1 then
		return
	end

	-- Stat sudah penuh: tidak ada efek, cooldown tidak terpakai.
	local statDef = Config.Stats[def.Stat]
	local current = SurvivalService.Get(player, def.Stat)
	if statDef == nil or current == nil or current >= statDef.Max then
		return
	end

	-- Cooldown per pemain per item (Activated bisa dispam client).
	local playerUse = lastUse[player]
	if playerUse == nil then
		return -- pemain sudah keluar
	end
	local key = ITEM_KEY_PREFIX .. itemId
	local now = os.clock()
	local last = playerUse[key]
	if last ~= nil and now - last < def.Cooldown then
		return
	end

	if SurvivalService.Add(player, def.Stat, def.Amount) ~= nil then
		playerUse[key] = now
	end
end

local function findOrCreatePrompt(instance: Instance, def: any): (ProximityPrompt?, boolean)
	if instance:IsA("ProximityPrompt") then
		return instance, false
	end
	local existing = instance:FindFirstChildWhichIsA("ProximityPrompt", true)
	if existing ~= nil then
		return existing, false
	end

	local host: Instance? = nil
	if instance:IsA("BasePart") then
		host = instance
	elseif instance:IsA("Model") then
		host = instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
	end
	if host == nil then
		return nil, false
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ConsumePrompt"
	prompt.ActionText = def.ActionText
	prompt.ObjectText = instance.Name
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = Config.Consumables.PromptDistance
	prompt.Parent = host
	return prompt, true
end

local function bind(typeName: string, def: any, instance: Instance)
	local typeBindings = bindings[typeName]
	if typeBindings[instance] ~= nil then
		return
	end
	local prompt, created = findOrCreatePrompt(instance, def)
	if prompt == nil then
		warn(`[ConsumableService] {instance:GetFullName()} ber-tag {def.Tag} tapi tidak punya ProximityPrompt dan bukan Model/Part; dilewati.`)
		return
	end

	local binding: Binding = {
		Prompt = prompt,
		CreatedPrompt = created,
		Connection = (nil :: any),
	}
	binding.Connection = prompt.Triggered:Connect(function(player: Player)
		onTriggered(instance, typeName, def, binding, player)
	end)
	typeBindings[instance] = binding
end

local function unbind(typeName: string, instance: Instance)
	local binding = bindings[typeName][instance]
	if binding == nil then
		return
	end
	bindings[typeName][instance] = nil
	binding.Connection:Disconnect()
	if binding.CreatedPrompt then
		binding.Prompt:Destroy()
	end
end

local function validateDef(typeName: string, def: any): boolean
	if type(def) ~= "table" or type(def.Tag) ~= "string" or def.Tag == "" then
		warn(`[ConsumableService] Config {typeName}: Tag tidak valid.`)
		return false
	end
	if Config.Stats[def.Stat] == nil then
		warn(`[ConsumableService] Config {typeName}: Stat '{tostring(def.Stat)}' tidak ada di Config.Stats.`)
		return false
	end
	if type(def.Amount) ~= "number" or def.Amount <= 0 then
		warn(`[ConsumableService] Config {typeName}: Amount harus > 0.`)
		return false
	end
	if type(def.Cooldown) ~= "number" or def.Cooldown < 0 then
		warn(`[ConsumableService] Config {typeName}: Cooldown harus >= 0.`)
		return false
	end
	return true
end

local function validateItemDef(itemId: string, def: any): boolean
	if ItemConfig.Items[itemId] == nil then
		warn(`[ConsumableService] Config Consumables.Items.{itemId}: itemId tidak ada di ItemConfig.Items.`)
		return false
	end
	if type(def) ~= "table" or Config.Stats[def.Stat] == nil then
		warn(`[ConsumableService] Config Consumables.Items.{itemId}: Stat tidak valid.`)
		return false
	end
	if type(def.Amount) ~= "number" or def.Amount ~= def.Amount or def.Amount <= 0 then
		warn(`[ConsumableService] Config Consumables.Items.{itemId}: Amount harus > 0.`)
		return false
	end
	if type(def.Cooldown) ~= "number" or def.Cooldown ~= def.Cooldown or def.Cooldown < 0 then
		warn(`[ConsumableService] Config Consumables.Items.{itemId}: Cooldown harus >= 0.`)
		return false
	end
	return true
end

function ConsumableService.Start()
	if started then
		return
	end
	started = true

	Players.PlayerAdded:Connect(function(player: Player)
		lastUse[player] = setmetatable({}, { __mode = "k" }) :: any
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastUse[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		lastUse[player] = setmetatable({}, { __mode = "k" }) :: any
	end

	for typeName, def in Config.Consumables.Types do
		if not validateDef(typeName, def) then
			continue
		end
		bindings[typeName] = {}
		for _, instance in CollectionService:GetTagged(def.Tag) do
			bind(typeName, def, instance)
		end
		CollectionService:GetInstanceAddedSignal(def.Tag):Connect(function(instance: Instance)
			bind(typeName, def, instance)
		end)
		CollectionService:GetInstanceRemovedSignal(def.Tag):Connect(function(instance: Instance)
			unbind(typeName, instance)
		end)
	end

	-- Tool di Backpack: sambungkan Tool.Activated tiap kali InventoryService membuat Tool item.
	for itemId, def in Config.Consumables.Items do
		if validateItemDef(itemId, def) then
			itemDefs[itemId] = def
		end
	end
	InventoryService.OnToolCreated(function(player: Player, itemId: string, tool: Tool)
		if itemDefs[itemId] == nil then
			return
		end
		-- Koneksi ikut hilang saat Tool dihancurkan (respawn / jumlah 0); Tool baru memicu callback lagi.
		tool.Activated:Connect(function()
			onToolActivated(player, itemId, tool)
		end)
	end)
end

return ConsumableService
