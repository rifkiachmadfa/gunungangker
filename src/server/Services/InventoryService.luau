--!strict
--[[
	InventoryService (SERVER) — pemilik tunggal inventory item yang bisa di-stack.

	- Jumlah item disimpan di server (counts[player][itemId]). Tool di Backpack hanya presentasi:
	  satu Tool per itemId, bernama "<DisplayName> xN", Attribute Tool "ItemId" dan "Count".
	- Jumlah juga ditulis ke Attribute Player "Item_<itemId>" (read-only untuk client; untuk HUD/quest UI).
	- Tool di-Clone dari ServerStorage/<TemplatePath> (ItemConfig). Template asli tidak diubah.
	- Tool dibangun ulang dari data server setelah respawn. Inventory TIDAK hilang saat mati (DEC-013).
	- Tool tidak bisa di-drop (CanBeDropped = false) agar stack tidak terduplikasi.

	API server:
		InventoryService.IsAvailable(itemId) -> boolean                          -- template Tool ada?
		InventoryService.GetCount(player, itemId) -> number
		InventoryService.AddItem(player, itemId, amount) -> (boolean, number)    -- (berhasil, jumlah masuk)
		InventoryService.RemoveItem(player, itemId, amount) -> boolean           -- atomik: semua atau tidak sama sekali
		InventoryService.OnToolCreated(fn) -> disconnect                         -- fn(player, itemId, tool)
			Dipanggil setiap Tool item baru dibuat di Backpack (item pertama kali masuk, atau dibangun ulang
			setelah respawn). Untuk sistem yang perlu menyambung event ke Tool (mis. ConsumableService).
			Tool dengan ItemId sama TIDAK memicu ulang saat jumlah berubah.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ItemConfig") :: ModuleScript) :: any

local ATTR_ITEM_ID = "ItemId"
local ATTR_COUNT = "Count"
local PLAYER_ATTR_PREFIX = "Item_"

local InventoryService = {}

local counts: { [Player]: { [string]: number } } = {}
local templates: { [string]: Tool } = {}
local warnedMissing: { [string]: boolean } = {}
local toolCreatedCallbacks: { (player: Player, itemId: string, tool: Tool) -> () } = {}
local started = false

local function isWholePositive(n: any): boolean
	return type(n) == "number" and n == n and n > 0 and n == math.floor(n) and n < math.huge
end

local function resolvePath(root: Instance, path: { string }, depth: number?): Instance?
	local current: Instance? = root
	for i = 1, depth or #path do
		if current == nil then
			return nil
		end
		current = current:FindFirstChild(path[i])
	end
	return current
end

-- Daftar Tool di folder induk template, untuk membantu mencari salah ketik nama.
local function describeSiblings(path: { string }): string
	local parent = resolvePath(ServerStorage, path, #path - 1)
	if parent == nil then
		return `folder ServerStorage.{table.concat(path, ".", 1, #path - 1)} tidak ditemukan`
	end
	local names: { string } = {}
	for _, child in parent:GetChildren() do
		if child:IsA("Tool") then
			table.insert(names, child.Name)
		end
	end
	return if #names == 0 then "tidak ada Tool di folder itu" else `Tool yang ada: {table.concat(names, ", ")}`
end

-- Cari template Tool. Di-cache setelah ketemu; bila tidak ketemu, warn sekali per item.
local function resolveTemplate(itemId: string): Tool?
	local cached = templates[itemId]
	if cached ~= nil and cached.Parent ~= nil then
		return cached
	end
	local def = Config.Items[itemId]
	if def == nil then
		return nil
	end

	local found = resolvePath(ServerStorage, def.TemplatePath)
	if found ~= nil and found:IsA("Tool") then
		if found.RequiresHandle and found:FindFirstChild("Handle") == nil then
			warn(`[InventoryService] {found:GetFullName()} RequiresHandle=true tapi tidak punya Part "Handle"; Tool tidak bisa di-equip.`)
		end
		templates[itemId] = found
		return found
	end

	if not warnedMissing[itemId] then
		warnedMissing[itemId] = true
		warn(`[InventoryService] Template Tool ServerStorage.{table.concat(def.TemplatePath, ".")} tidak ditemukan atau bukan Tool ({describeSiblings(def.TemplatePath)}). Item {itemId} tidak bisa ditambahkan.`)
	end
	return nil
end

-- Semua Tool milik itemId (Backpack + Character). Normalnya satu.
local function findTools(player: Player, itemId: string): { Tool }
	local found: { Tool } = {}
	local containers: { Instance? } = { player:FindFirstChildOfClass("Backpack"), player.Character }
	for _, container in containers do
		if container ~= nil then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute(ATTR_ITEM_ID) == itemId then
					table.insert(found, child)
				end
			end
		end
	end
	return found
end

-- Samakan Tool dengan data server. Idempoten: aman dipanggil berulang.
local function syncTool(player: Player, itemId: string)
	local inv = counts[player]
	local def = Config.Items[itemId]
	if inv == nil or def == nil then
		return
	end
	local count = inv[itemId] or 0
	player:SetAttribute(PLAYER_ATTR_PREFIX .. itemId, count)

	local tools = findTools(player, itemId)
	-- Buang duplikat (jaga-jaga); sisakan satu.
	for i = 2, #tools do
		tools[i]:Destroy()
	end
	local tool: Tool? = tools[1]

	if count <= 0 then
		if tool ~= nil then
			tool:Destroy()
		end
		return
	end

	if tool == nil then
		local backpack = player:FindFirstChildOfClass("Backpack")
		local template = resolveTemplate(itemId)
		if backpack == nil or template == nil then
			return -- dibangun ulang saat Backpack tersedia
		end
		local clone = template:Clone()
		clone.CanBeDropped = false
		clone:SetAttribute(ATTR_ITEM_ID, itemId)
		clone.Parent = backpack
		tool = clone
		for _, callback in table.clone(toolCreatedCallbacks) do
			local ok, err = pcall(callback, player, itemId, clone)
			if not ok then
				warn(`[InventoryService] Callback OnToolCreated error untuk {itemId}: {tostring(err)}`)
			end
		end
	end

	local label = if def.ShowCount == false then def.DisplayName else `{def.DisplayName} x{count}`
	local t = tool :: Tool
	t:SetAttribute(ATTR_COUNT, count)
	t.Name = label
	t.ToolTip = label
end

local function syncAll(player: Player)
	if counts[player] == nil then
		return
	end
	for itemId in Config.Items do
		syncTool(player, itemId)
	end
end

function InventoryService.IsAvailable(itemId: string): boolean
	return resolveTemplate(itemId) ~= nil
end

function InventoryService.GetCount(player: Player, itemId: string): number
	local inv = counts[player]
	return if inv ~= nil then (inv[itemId] or 0) else 0
end

function InventoryService.AddItem(player: Player, itemId: string, amount: number): (boolean, number)
	local def = Config.Items[itemId]
	local inv = counts[player]
	if def == nil or inv == nil or not isWholePositive(amount) then
		return false, 0
	end
	local room = def.MaxStack - (inv[itemId] or 0)
	if room <= 0 then
		return false, 0 -- stack penuh
	end
	-- Template wajib ada: tanpa Tool, pemain tidak melihat item dan resource akan "hilang".
	if resolveTemplate(itemId) == nil then
		return false, 0
	end
	local added = math.min(room, amount)
	inv[itemId] = (inv[itemId] or 0) + added
	syncTool(player, itemId)
	return true, added
end

function InventoryService.RemoveItem(player: Player, itemId: string, amount: number): boolean
	local inv = counts[player]
	if Config.Items[itemId] == nil or inv == nil or not isWholePositive(amount) then
		return false
	end
	local have = inv[itemId] or 0
	if have < amount then
		return false
	end
	inv[itemId] = have - amount
	syncTool(player, itemId)
	return true
end

function InventoryService.OnToolCreated(callback: (player: Player, itemId: string, tool: Tool) -> ()): () -> ()
	table.insert(toolCreatedCallbacks, callback)
	return function()
		local index = table.find(toolCreatedCallbacks, callback)
		if index ~= nil then
			table.remove(toolCreatedCallbacks, index)
		end
	end
end

local function onPlayerAdded(player: Player)
	if counts[player] ~= nil then
		return
	end
	counts[player] = {}
	for itemId in Config.Items do
		player:SetAttribute(PLAYER_ATTR_PREFIX .. itemId, 0)
	end
	-- Backpack bisa dibuat ulang saat respawn; bangun ulang Tool dari data server.
	player.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Backpack") then
			syncAll(player)
		end
	end)
	player.CharacterAdded:Connect(function()
		task.defer(syncAll, player)
	end)
end

function InventoryService.Start()
	if started then
		return
	end
	started = true

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player: Player)
		counts[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return InventoryService
