--!strict
--[[
	ResourceRenderer (CLIENT) — menggambar resource personal (ranting, dst.) milik pemain lokal.

	- Hanya presentasi. Sumber kebenaran = server (ResourceService). Server menulis daftar titik aktif
	  ke Player attribute (ResourceConfig.Sets[x].Attribute, nama titik dipisah koma); client membaca
	  attribute itu dan membuat/menghapus klon model LOKAL di Workspace.LocalResources (folder hanya ada
	  di client ini, jadi pemain lain tidak melihat resource Anda).
	- Template diambil dari ReplicatedStorage.<AssetsFolder>.<AssetName> (disalin server dari ServerStorage).
	- Klon dibuat tidak bertabrakan: Anchored, CanCollide/CanTouch/CanQuery = false; Script,
	  ProximityPrompt, ClickDetector di dalam klon dihapus (pengambilan murni urusan server).
	- Pengambilan murni urusan server. Mode "Proximity": server mendeteksi pemain mendekat. Mode "Prompt":
	  server membuat ProximityPrompt tahan di Part titik spawn; client HANYA menyembunyikan (lokal) prompt
	  titik yang tidak aktif untuk pemain ini. Itu kosmetik: server tetap menolak titik tidak aktif.

	API: ResourceRenderer.Start(player)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ResourceConfig") :: ModuleScript) :: any

local ASSET_WAIT_TIMEOUT = 30
local LOCAL_FOLDER_NAME = "LocalResources"

local ResourceRenderer = {}

local started = false

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

local function sanitize(clone: Instance)
	local function clean(instance: Instance)
		if instance:IsA("BasePart") then
			instance.Anchored = true
			instance.CanCollide = false
			instance.CanTouch = false
			instance.CanQuery = false
		end
	end
	clean(clone)
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BaseScript") or descendant:IsA("ProximityPrompt") or descendant:IsA("ClickDetector") then
			descendant:Destroy()
		else
			clean(descendant)
		end
	end
end

local function bindSet(player: Player, setId: string, def: any, container: Folder)
	local assets = ReplicatedStorage:WaitForChild(Config.AssetsFolder, ASSET_WAIT_TIMEOUT)
	local template = if assets ~= nil then assets:WaitForChild(def.AssetName, ASSET_WAIT_TIMEOUT) else nil
	if template == nil then
		warn(`[ResourceRenderer] Template '{Config.AssetsFolder}.{def.AssetName}' tidak tersedia (set {setId}); resource tidak akan terlihat.`)
		return
	end

	local rendered: { [string]: Instance } = {}
	local warned: { [string]: boolean } = {}
	local wantedNow: { [string]: boolean } = {}

	-- Mode "Prompt": prompt hanya aktif di titik yang aktif untuk pemain lokal.
	local function syncPrompts()
		if def.PickupMode ~= "Prompt" then
			return
		end
		local folder = resolvePath(Workspace, def.SpawnerFolder)
		if folder == nil then
			return
		end
		for _, part in folder:GetChildren() do
			local prompt = part:FindFirstChild(Config.PromptName)
			if prompt ~= nil and prompt:IsA("ProximityPrompt") then
				prompt.Enabled = wantedNow[part.Name] == true
			end
		end
	end

	local function findSpawner(name: string): BasePart?
		local folder = resolvePath(Workspace, def.SpawnerFolder)
		local part = if folder ~= nil then folder:FindFirstChild(name) else nil
		if part ~= nil and part:IsA("BasePart") then
			return part
		end
		return nil
	end

	local function create(name: string)
		local spawner = findSpawner(name)
		if spawner == nil then
			if not warned[name] then
				warned[name] = true
				warn(`[ResourceRenderer] Titik spawn '{name}' tidak ditemukan di client (set {setId}).`)
			end
			return
		end
		local clone = template:Clone()
		if not clone:IsA("PVInstance") then
			warn(`[ResourceRenderer] Template '{def.AssetName}' harus Model atau BasePart.`)
			return
		end
		local model = clone :: PVInstance
		sanitize(model)
		model.Name = `{def.AssetName}_{name}`
		model:PivotTo(spawner.CFrame * CFrame.new(def.PlacementOffset))
		model.Parent = container
		rendered[name] = model
	end

	local function apply()
		local raw = player:GetAttribute(def.Attribute)
		local wanted: { [string]: boolean } = {}
		if type(raw) == "string" and raw ~= "" then
			for name in string.gmatch(raw, "[^,]+") do
				wanted[name] = true
			end
		end

		for name, instance in rendered do
			if not wanted[name] then
				instance:Destroy()
				rendered[name] = nil
			end
		end
		for name in wanted do
			if rendered[name] == nil then
				create(name)
			end
		end

		wantedNow = wanted
		syncPrompts()
	end

	player:GetAttributeChangedSignal(def.Attribute):Connect(apply)
	apply()

	-- Prompt dibuat server saat quest diterima dan bisa tiba di client sesudah attribute: sinkronkan lagi
	-- setiap kali prompt baru muncul. Folder titik spawn ditunggu (bukan diasumsikan sudah ada).
	if def.PickupMode == "Prompt" then
		task.spawn(function()
			local current: Instance? = Workspace
			for _, name in def.SpawnerFolder do
				if current == nil then
					return
				end
				current = current:WaitForChild(name, ASSET_WAIT_TIMEOUT)
			end
			if current == nil then
				warn(`[ResourceRenderer] Folder spawner tidak ditemukan di client (set {setId}); prompt tidak disinkronkan.`)
				return
			end
			current.DescendantAdded:Connect(function(descendant: Instance)
				if descendant.Name == Config.PromptName then
					syncPrompts()
				end
			end)
			syncPrompts()
		end)
	end
end

function ResourceRenderer.Start(player: Player)
	if started then
		return
	end
	started = true

	local container = Instance.new("Folder")
	container.Name = LOCAL_FOLDER_NAME
	container.Parent = Workspace

	for setId, def in Config.Sets do
		task.spawn(bindSet, player, setId, def, container)
	end
end

return ResourceRenderer
