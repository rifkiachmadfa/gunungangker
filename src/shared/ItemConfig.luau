--!strict
--[[
	ItemConfig — definisi item yang bisa ditumpuk (stack) di Backpack (dibaca server DAN client).

	Satu item = SATU Tool di Backpack, berapa pun jumlahnya. Jumlah asli disimpan server
	(InventoryService); Tool hanya presentasi.

	Items[itemId]:
	  DisplayName  : nama di hotbar/Backpack (ditambah " xN").
	  TemplatePath : path dari ServerStorage ke Tool template (di-Clone untuk pemain). Template asli
	                 tidak diubah. Konvensi sama dengan ResourceConfig.TemplatePath.
	  MaxStack     : jumlah maksimum per pemain. Penuh = resource tidak terambil (tetap di dunia).
	  ShowCount    : (opsional, default true) false = nama Tool tanpa " xN" (untuk item tunggal yang
	                 dipakai berulang, mis. Air dan Ciki).

	Resource yang memberi item: isi ResourceConfig.Sets[setId].ItemId dengan itemId di sini.
	Quest yang memberi item sebagai reward: isi QuestConfig.Quests[id].Rewards.
	Item yang bisa dipakai (menambah Hunger/Thirst): isi SurvivalConfig.Consumables.Items[itemId].
]]

export type ItemDef = {
	DisplayName: string,
	TemplatePath: { string },
	MaxStack: number,
	ShowCount: boolean?,
}

export type Config = {
	Items: { [string]: ItemDef },
}

local Config: Config = {
	Items = {
		Ranting = {
			DisplayName = "Ranting",
			-- Tool ranting (BEDA dari ServerStorage.QuestModels.Ranting yang dipakai ResourceRenderer).
			-- Path dari pengguna, BELUM diverifikasi di Studio.
			TemplatePath = { "QuestModels", "Ranting" },
			MaxStack = 20, -- GDD: CP1 butuh 10. Perlu konfirmasi (Q7).
		},

		-- Reward CP1 (QuestConfig.Quests.CP1_Ranting.Rewards). Tool bernama "Air" dan "Ciki" dengan Part "Handle".
		-- TemplatePath mengikuti konvensi folder QuestModels, BELUM diverifikasi di Studio: ubah bila Tool
		-- ada di folder lain di ServerStorage. Satu Tool per item, tidak habis dipakai (lihat DEC-018).
		Air = {
			DisplayName = "Air",
			TemplatePath = { "QuestModels", "Air" },
			MaxStack = 1,
			ShowCount = false,
		},
		Ciki = {
			DisplayName = "Ciki",
			TemplatePath = { "QuestModels", "Ciki" },
			MaxStack = 1,
			ShowCount = false,
		},
	},
}

return Config
