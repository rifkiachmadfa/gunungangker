--!strict
--[[
	NotificationController (CLIENT) — notifikasi quest dari Player attribute milik server.

	Sumber data (read-only, ditulis QuestService):
	  Quest_<id>_State    : None | Active | ReadyToTurnIn | Completed
	  Quest_<id>_Progress : number
	Tidak ada Remote: client tidak mengirim apa pun dan tidak menentukan progres.

	Perilaku per quest (teks di QuestConfig.Quests[id].Notify):
	  Active         -> kartu tujuan "Kumpulkan ranting 0/10", bertambah tiap ranting terambil.
	  Progres naik   -> toast "Mendapatkan Ranting".
	  ReadyToTurnIn  -> tujuan berubah: "... Kembali ke Ibu Warung dan serahkan ranting".
	  Completed/None -> kartu tujuan dihapus (Completed = pemain sudah bicara dan menyerahkan ranting).

	Atribut State dan Progress ditulis server berurutan sehingga dapat tiba terpisah; render dikumpulkan
	per frame (task.defer) agar toast/tujuan selalu memakai pasangan nilai yang konsisten.

	API: NotificationController.Start(player, NotificationViewModule)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local QuestConfig = require(Shared:WaitForChild("QuestConfig") :: ModuleScript) :: any
local DialogueConfig = require(Shared:WaitForChild("DialogueConfig") :: ModuleScript) :: any
local QuestNotify = require(Shared:WaitForChild("QuestNotify") :: ModuleScript) :: any

local NotificationController = {}

local started = false

local function readState(player: Player, questId: string): string
	local value = player:GetAttribute(`Quest_{questId}_State`)
	return if type(value) == "string" then value else "None"
end

local function readProgress(player: Player, questId: string): number
	local value = player:GetAttribute(`Quest_{questId}_Progress`)
	return if type(value) == "number" then value else 0
end

local function bindQuest(player: Player, view: any, questId: string, def: any)
	local npc = DialogueConfig.Npcs[def.NpcId]
	local npcName = if npc ~= nil then npc.DisplayName else "NPC"
	local notify = def.Notify

	-- Nilai awal tidak memicu toast: dianggap sudah dilihat.
	local lastProgress = readProgress(player, questId)
	local pending = false

	local function render()
		pending = false

		local state = readState(player, questId)
		local progress = readProgress(player, questId)
		local result = QuestNotify.Evaluate(lastProgress, state, progress)
		lastProgress = progress

		if result.ShowObjective then
			local template = if state == "ReadyToTurnIn" then notify.ReadyText else notify.ActiveText
			view.SetObjective(
				questId,
				def.Title,
				QuestNotify.Format(template, { Count = progress, Target = def.Target, Npc = npcName })
			)
		else
			view.ClearObjective(questId)
		end

		if result.ShowPickupToast then
			view.Toast(QuestNotify.Format(notify.PickupText, { Count = progress, Target = def.Target, Npc = npcName }))
		end
	end

	local function schedule()
		if pending then
			return
		end
		pending = true
		task.defer(render)
	end

	player:GetAttributeChangedSignal(`Quest_{questId}_State`):Connect(schedule)
	player:GetAttributeChangedSignal(`Quest_{questId}_Progress`):Connect(schedule)

	-- Tampilan awal (mis. client menyala setelah quest sudah Active).
	render()
end

function NotificationController.Start(player: Player, viewModule: any)
	if started then
		return
	end
	started = true

	local view = viewModule.new(player)

	for questId, def in QuestConfig.Quests do
		if type(def.Notify) ~= "table" then
			warn(`[NotificationController] Quest '{questId}' tidak punya Notify di QuestConfig; notifikasi dilewati.`)
			continue
		end
		bindQuest(player, view, questId, def)
	end
end

return NotificationController
