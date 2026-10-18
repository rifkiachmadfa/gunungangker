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

	Resource yang memberi item: isi ResourceConfig.Sets[setId].ItemId dengan itemId di sini.
]]

export type ItemDef = {
	DisplayName: string,
	TemplatePath: { string },
	MaxStack: number,
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
	},
}

return Config
