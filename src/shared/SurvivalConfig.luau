--!strict
--[[
	SurvivalConfig — konfigurasi Hunger & Thirst (dibaca server DAN client).

	Ubah angka di sini untuk balancing; tidak perlu menyentuh logika.

	Max           : nilai maksimum stat.
	Start         : nilai awal saat pemain join.
	DecayAmount   : berapa poin berkurang setiap tick.
	DecayInterval : detik antar tick. Isi 0 (atau kurang) untuk mematikan decay stat tsb.

	Satuan stat = persen dari Max (Max 100 -> 1 poin = 1%).
	Server adalah satu-satunya yang menulis nilai; client hanya membaca.
]]

export type StatDef = {
	Max: number,
	Start: number,
	DecayAmount: number,
	DecayInterval: number,
}

export type Config = {
	Stats: { [string]: StatDef },
	StatOrder: { string },
	LowThreshold: number,
}

local Config: Config = {
	Stats = {
		Hunger = {
			Max = 100,
			Start = 50,
			DecayAmount = 1,
			DecayInterval = 10,
		},
		Thirst = {
			Max = 100,
			Start = 50,
			DecayAmount = 1,
			DecayInterval = 10,
		},
	},

	-- Urutan tampil di HUD (nama harus sama dengan key di Stats).
	StatOrder = { "Hunger", "Thirst" },

	-- Persentase di bawah nilai ini dianggap "kritis" (bar HUD berubah merah).
	-- Mengacu GDD: halusinasi mulai di 1-24%.
	LowThreshold = 25,
}

return Config
