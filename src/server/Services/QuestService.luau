--!strict
--[[
	QuestService (SERVER) — pemilik tunggal progres quest per pemain.

	State per quest: None -> Active -> ReadyToTurnIn -> Completed (personal, tidak dibagi antar pemain).

	Alur CP1_Ranting:
	  1. Dialog Ibu Warung -> Action "CP1.AcceptQuest" -> Accept: ResourceService.Activate (10 ranting
	     aktif dari 20 titik, personal) dan state = Active.
	  2. Pemain mendekati ranting -> ResourceService mendeteksi di server -> OnCollected -> progres +1.
	     Ranting hilang dan muncul di titik berbeda (diurus ResourceService).
	  3. Progres = Target -> state = ReadyToTurnIn, sisa ranting dihapus, event "ReadyToTurnIn".
	  4. Kembali ke Ibu Warung -> dialog node Entry.ReadyToTurnIn -> Action "CP1.TurnIn" -> Completed.
	  Reward (Tool makanan/minuman) BELUM ada; sistem Backpack nanti memakai Subscribe("Completed").

	Replikasi ke client (read-only) lewat Player attribute, untuk Notification/HUD nanti:
	  Quest_<id>_State    (string)
	  Quest_<id>_Progress (number)

	API server:
	  QuestService.GetState(player, questId) -> string?
	  QuestService.GetProgress(player, questId) -> number?
	  QuestService.Accept(player, questId) -> boolean
	  QuestService.TurnIn(player, questId) -> boolean
	  QuestService.Subscribe(fn) -> disconnect
	      fn(event, player, questId, data). event: "Accepted" | "Progress" | "ReadyToTurnIn" | "Completed".
	      data = { Progress, Target } (Progress/ReadyToTurnIn) atau {} (lainnya).
	      Notification System akan memakai ini; QuestService tidak tahu soal UI.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("QuestConfig") :: ModuleScript) :: any
local ResourceConfig = require(Shared:WaitForChild("ResourceConfig") :: ModuleScript) :: any
local DialogueConfig = require(Shared:WaitForChild("DialogueConfig") :: ModuleScript) :: any

local Services = script.Parent :: Instance
local ResourceService = require(Services:WaitForChild("ResourceService") :: ModuleScript) :: any
local DialogueService = require(Services:WaitForChild("DialogueService") :: ModuleScript) :: any

local QuestService = {}

type Entry = {
	State: string,
	Progress: number,
}

type Subscriber = (event: string, player: Player, questId: string, data: any) -> ()

local entries: { [Player]: { [string]: Entry } } = {}
local subscribers: { Subscriber } = {}
-- Hanya quest yang lolos validasi config.
local quests: { [string]: any } = {}
local started = false

local function log(message: string)
	if Config.Debug then
		print(`[QuestService] {message}`)
	end
end

local function getEntry(player: Player, questId: string): Entry?
	local playerEntries = entries[player]
	if playerEntries == nil then
		return nil
	end
	return playerEntries[questId]
end

local function writeAttributes(player: Player, questId: string, entry: Entry)
	player:SetAttribute(`Quest_{questId}_State`, entry.State)
	player:SetAttribute(`Quest_{questId}_Progress`, entry.Progress)
end

local function emit(event: string, player: Player, questId: string, data: any)
	for _, subscriber in table.clone(subscribers) do
		local ok, err = pcall(subscriber, event, player, questId, data)
		if not ok then
			warn(`[QuestService] Subscriber error pada '{event}': {tostring(err)}`)
		end
	end
end

--------------------------------------------------------------------------------
-- Transisi state
--------------------------------------------------------------------------------

function QuestService.GetState(player: Player, questId: string): string?
	local entry = getEntry(player, questId)
	return if entry ~= nil then entry.State else nil
end

function QuestService.GetProgress(player: Player, questId: string): number?
	local entry = getEntry(player, questId)
	return if entry ~= nil then entry.Progress else nil
end

function QuestService.Accept(player: Player, questId: string): boolean
	local def = quests[questId]
	local entry = getEntry(player, questId)
	if def == nil or entry == nil or entry.State ~= "None" then
		return false
	end

	local ok, reason = ResourceService.Activate(player, def.ResourceSet)
	if not ok then
		warn(`[QuestService] Quest {questId} gagal dimulai untuk {player.Name}: {tostring(reason)}`)
		return false
	end

	entry.State = "Active"
	entry.Progress = 0
	writeAttributes(player, questId, entry)
	log(`{player.Name} menerima {questId}: 0/{def.Target}`)
	emit("Accepted", player, questId, {})
	return true
end

function QuestService.TurnIn(player: Player, questId: string): boolean
	local entry = getEntry(player, questId)
	if entry == nil or entry.State ~= "ReadyToTurnIn" then
		return false
	end
	entry.State = "Completed"
	writeAttributes(player, questId, entry)
	log(`{player.Name} menyelesaikan {questId}`)
	emit("Completed", player, questId, {})
	return true
end

function QuestService.Subscribe(subscriber: Subscriber): () -> ()
	table.insert(subscribers, subscriber)
	return function()
		local index = table.find(subscribers, subscriber)
		if index ~= nil then
			table.remove(subscribers, index)
		end
	end
end

local function onCollected(player: Player, setId: string, _pointName: string)
	for questId, def in quests do
		if def.ResourceSet ~= setId then
			continue
		end
		local entry = getEntry(player, questId)
		if entry == nil or entry.State ~= "Active" or entry.Progress >= def.Target then
			continue
		end

		entry.Progress += 1
		log(`{player.Name} {questId}: {entry.Progress}/{def.Target}`)
		if entry.Progress >= def.Target then
			entry.State = "ReadyToTurnIn"
			-- Cukup; hapus sisa resource (ResourceService juga membatalkan respawn tertunda).
			ResourceService.Deactivate(player, setId)
			writeAttributes(player, questId, entry)
			emit("Progress", player, questId, { Progress = entry.Progress, Target = def.Target })
			log(`{player.Name} {questId}: siap diserahkan`)
			emit("ReadyToTurnIn", player, questId, { Progress = entry.Progress, Target = def.Target })
		else
			writeAttributes(player, questId, entry)
			emit("Progress", player, questId, { Progress = entry.Progress, Target = def.Target })
		end
	end
end

--------------------------------------------------------------------------------
-- Validasi config & wiring ke Dialogue
--------------------------------------------------------------------------------

local function validateQuest(questId: string, def: any): boolean
	local function fail(message: string): boolean
		warn(`[QuestService] Config Quests.{questId}: {message}; quest dilewati.`)
		return false
	end

	if type(def) ~= "table" or def.Type ~= "Collect" then
		return fail("Type harus 'Collect'")
	end
	if type(def.Target) ~= "number" or def.Target < 1 or def.Target ~= math.floor(def.Target) then
		return fail("Target harus bilangan bulat >= 1")
	end
	local setDef = ResourceConfig.Sets[def.ResourceSet]
	if setDef == nil then
		return fail(`ResourceSet '{tostring(def.ResourceSet)}' tidak ada di ResourceConfig`)
	end
	if setDef.ActiveCount < 1 then
		return fail("ResourceSet.ActiveCount harus >= 1")
	end
	local npc = DialogueConfig.Npcs[def.NpcId]
	if npc == nil then
		return fail(`NpcId '{tostring(def.NpcId)}' tidak ada di DialogueConfig`)
	end
	if type(def.VariablePrefix) ~= "string" or def.VariablePrefix == "" then
		return fail("VariablePrefix tidak valid")
	end
	if type(def.Actions) ~= "table" or type(def.Actions.Accept) ~= "string" or type(def.Actions.TurnIn) ~= "string" then
		return fail("Actions.Accept dan Actions.TurnIn harus string")
	end
	for key, nodeId in def.Entry do
		if npc.Nodes[nodeId] == nil then
			return fail(`Entry.{key} menunjuk node '{tostring(nodeId)}' yang tidak ada di dialog {def.NpcId}`)
		end
	end
	return true
end

local function wireDialogue(questId: string, def: any)
	DialogueService.RegisterAction(def.Actions.Accept, function(player: Player, context: any)
		if context.NpcId == def.NpcId then
			QuestService.Accept(player, questId)
		end
	end)
	DialogueService.RegisterAction(def.Actions.TurnIn, function(player: Player, context: any)
		if context.NpcId == def.NpcId then
			QuestService.TurnIn(player, questId)
		end
	end)

	DialogueService.RegisterTextVariable(`{def.VariablePrefix}Count`, function(player: Player): number
		return QuestService.GetProgress(player, questId) or 0
	end)
	DialogueService.RegisterTextVariable(`{def.VariablePrefix}Target`, function(_player: Player): number
		return def.Target
	end)

	-- Satu quest per NPC saat ini; bila nanti ada lebih dari satu, resolver perlu digabung.
	DialogueService.RegisterEntryResolver(def.NpcId, function(player: Player): string?
		local state = QuestService.GetState(player, questId)
		if state == nil or state == "None" then
			return nil -- pakai node Start
		end
		return def.Entry[state]
	end)
end

function QuestService.Start()
	if started then
		return
	end
	started = true

	local function onPlayerAdded(player: Player)
		local playerEntries: { [string]: Entry } = {}
		for questId in quests do
			local entry: Entry = { State = "None", Progress = 0 }
			playerEntries[questId] = entry
			writeAttributes(player, questId, entry)
		end
		entries[player] = playerEntries
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player: Player)
		entries[player] = nil
	end)

	for questId, def in Config.Quests do
		if validateQuest(questId, def) then
			quests[questId] = def
			wireDialogue(questId, def)
		end
	end
	ResourceService.OnCollected(onCollected)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return QuestService
