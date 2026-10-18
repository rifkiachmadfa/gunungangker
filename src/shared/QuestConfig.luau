--!strict
--[[
	QuestConfig — definisi quest. Logika ada di QuestService; file ini hanya data.

	Debug : true = QuestService mencetak log progres ke Output (matikan setelah Notification System ada).

	Quests[questId]:
	  Title          : nama quest (untuk UI/notifikasi nanti).
	  Type           : "Collect" (satu-satunya tipe saat ini): kumpulkan Target resource dari ResourceSet.
	  Target         : jumlah yang harus dikumpulkan.
	  ResourceSet    : id set di ResourceConfig.Sets.
	  NpcId          : id NPC di DialogueConfig.Npcs yang memberi dan menerima quest.
	  VariablePrefix : membuat variabel teks dialog {<Prefix>Count} dan {<Prefix>Target}.
	  Actions        : nama Action dialog yang ditangani QuestService (Accept, TurnIn).
	  Entry          : node dialog awal NPC per state quest (state None memakai node Start biasa).

	State quest per pemain: None -> Active -> ReadyToTurnIn -> Completed.
	Reward belum diimplementasi (menunggu Backpack/Tool); sistem lain memakai QuestService.Subscribe.
]]

export type QuestDef = {
	Title: string,
	Type: string,
	Target: number,
	ResourceSet: string,
	NpcId: string,
	VariablePrefix: string,
	Actions: {
		Accept: string,
		TurnIn: string,
	},
	Entry: {
		Active: string,
		ReadyToTurnIn: string,
		Completed: string,
	},
}

export type Config = {
	Debug: boolean,
	Quests: { [string]: QuestDef },
}

local Config: Config = {
	Debug = true,

	Quests = {
		CP1_Ranting = {
			Title = "Kumpulkan Ranting",
			Type = "Collect",
			Target = 10,
			ResourceSet = "RantingCP1",
			NpcId = "Warung",
			VariablePrefix = "Ranting",
			Actions = {
				Accept = "CP1.AcceptQuest",
				TurnIn = "CP1.TurnIn",
			},
			Entry = {
				Active = "QuestActive",
				ReadyToTurnIn = "QuestReady",
				Completed = "QuestAfter",
			},
		},
	},
}

return Config
