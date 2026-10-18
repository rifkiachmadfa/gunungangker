--!strict
--[[
	SurvivalService (SERVER) — pemilik tunggal state Hunger & Thirst.

	- State disimpan per pemain sebagai Attribute di objek Player: "Hunger", "Thirst".
	  Attribute yang ditulis server otomatis ter-replikasi ke client (read-only untuk client).
	- Decay berjalan di server berdasarkan SurvivalConfig. Client tidak bisa mengubah nilai.
	- Decay dijeda selama pemain tidak punya karakter hidup (mati / belum spawn).
	- Belum ada efek saat stat mencapai 0 (knock/slow menunggu keputusan Q1 di GAME_CONTEXT).

	API server (untuk sistem lain, mis. shop CP1):
		SurvivalService.Get(player, statName) -> number?
		SurvivalService.Add(player, statName, amount) -> number?   -- amount boleh negatif
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SurvivalConfig") :: ModuleScript) :: any

local SurvivalService = {}

-- Akumulator waktu decay per pemain per stat.
local accumulators: { [Player]: { [string]: number } } = {}
local started = false

local function isAlive(player: Player): boolean
	local character = player.Character
	if not character then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function writeStat(player: Player, statName: string, value: number): number
	local def = Config.Stats[statName]
	local clamped = math.clamp(value, 0, def.Max)
	player:SetAttribute(statName, clamped)
	return clamped
end

function SurvivalService.Get(player: Player, statName: string): number?
	if Config.Stats[statName] == nil then
		return nil
	end
	local value = player:GetAttribute(statName)
	if type(value) == "number" then
		return value
	end
	return nil
end

function SurvivalService.Add(player: Player, statName: string, amount: number): number?
	if Config.Stats[statName] == nil then
		warn(`[SurvivalService] Stat tidak dikenal: {statName}`)
		return nil
	end
	-- Tolak NaN / inf / non-number.
	if type(amount) ~= "number" or amount ~= amount or amount == math.huge or amount == -math.huge then
		warn(`[SurvivalService] Amount tidak valid untuk {statName}`)
		return nil
	end
	local current = SurvivalService.Get(player, statName)
	if current == nil then
		return nil
	end
	return writeStat(player, statName, current + amount)
end

local function onPlayerAdded(player: Player)
	local acc: { [string]: number } = {}
	for statName, def in Config.Stats do
		acc[statName] = 0
		writeStat(player, statName, def.Start)
	end
	accumulators[player] = acc
end

local function onPlayerRemoving(player: Player)
	accumulators[player] = nil
end

local function step(dt: number)
	for player, acc in accumulators do
		if not isAlive(player) then
			continue
		end
		for statName, def in Config.Stats do
			if def.DecayInterval <= 0 or def.DecayAmount == 0 then
				continue
			end
			local elapsed = (acc[statName] or 0) + dt
			if elapsed >= def.DecayInterval then
				local ticks = math.floor(elapsed / def.DecayInterval)
				elapsed -= ticks * def.DecayInterval
				local current = SurvivalService.Get(player, statName)
				if current ~= nil then
					writeStat(player, statName, current - def.DecayAmount * ticks)
				end
			end
			acc[statName] = elapsed
		end
	end
end

function SurvivalService.Start()
	if started then
		return
	end
	started = true

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	RunService.Heartbeat:Connect(step)
end

return SurvivalService
