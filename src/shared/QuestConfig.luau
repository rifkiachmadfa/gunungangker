--!strict
--[[
	QuestConfig — definisi quest. Logika ada di QuestService; file ini hanya data.

	Debug : true = QuestService mencetak log progres ke Output (matikan setelah Notification System teruji di Studio).

	Quests[questId]:
	  Title          : nama quest (untuk UI/notifikasi nanti).
	  Type           : "Collect" (satu-satunya tipe saat ini): kumpulkan Target resource dari ResourceSet.
	  Target         : jumlah yang harus dikumpulkan.
	  ResourceSet    : id set di ResourceConfig.Sets.
	  NpcId          : id NPC di DialogueConfig.Npcs yang memberi dan menerima quest.
	  VariablePrefix : membuat variabel teks dialog {<Prefix>Count} dan {<Prefix>Target}.
	  Actions        : nama Action dialog yang ditangani QuestService (Accept, TurnIn).
	  Entry          : node dialog awal NPC per state quest (state None memakai node Start biasa).
	  Notify         : teks notifikasi client (NotificationController). Placeholder: {Count} {Target} {Npc}.
	      PickupText    : toast tiap progres bertambah (mis. ranting terambil).
	      ActiveText    : teks tujuan selama state Active.
	      ReadyText     : teks tujuan saat state ReadyToTurnIn (kembali ke NPC dan serahkan).
	  Tujuan (objective) tampil saat Active dan ReadyToTurnIn, hilang saat Completed atau None.
	  Rewards        : (opsional) { { ItemId, Amount } } item yang masuk ke inventory saat TurnIn berhasil.
	                   ItemId harus ada di ItemConfig.Items.

	State quest per pemain: None -> Active -> ReadyToTurnIn -> Completed.
	Reward item lewat Rewards (InventoryService). Efek lain (mis. membuka gate) memakai QuestService.Subscribe.
]]

export type RewardDef = {
	ItemId: string,
	Amount: number,
}

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
	Notify: {
		PickupText: string,
		ActiveText: string,
		ReadyText: string,
	},
	Rewards: { RewardDef }?,
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
			Notify = {
				PickupText = "Mendapatkan Ranting",
				ActiveText = "Kumpulkan ranting {Count}/{Target}",
				ReadyText = "Ranting sudah cukup {Count}/{Target}. Kembali ke {Npc} dan serahkan ranting",
			},
			-- Ibu Warung memberi Air (+5% Thirst) dan Ciki (+5% Hunger); lihat SurvivalConfig.Consumables.Items.
			Rewards = {
				{ ItemId = "Air", Amount = 1 },
				{ ItemId = "Ciki", Amount = 1 },
			},
		},
	},
}

return Config
