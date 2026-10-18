--!strict
--[[
	Remotes — akses RemoteEvent terpusat di ReplicatedStorage.Remotes.

	Server : Remotes.Get(name) membuat RemoteEvent bila belum ada (idempoten).
	Client : Remotes.Get(name) menunggu RemoteEvent dibuat server (WaitForChild).

	Kontrak setiap Remote WAJIB dicatat di .ai/GAME_CONTEXT.md bagian 13.
	Tidak ada perubahan mapping Rojo: folder dibuat saat runtime oleh server.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local Remotes = {}

local function getFolder(): Folder
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if existing ~= nil and existing:IsA("Folder") then
			return existing :: Folder
		end
		local folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
		return folder
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

function Remotes.Get(name: string): RemoteEvent
	local folder = getFolder()
	if RunService:IsServer() then
		local existing = folder:FindFirstChild(name)
		if existing ~= nil then
			if existing:IsA("RemoteEvent") then
				return existing :: RemoteEvent
			end
			error(`[Remotes] '{name}' sudah ada tetapi bukan RemoteEvent`)
		end
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		return remote
	end
	return folder:WaitForChild(name) :: RemoteEvent
end

return Remotes
