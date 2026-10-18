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

	Consumables (makanan/minuman di dunia, dipicu ProximityPrompt):
	Tag           : CollectionService tag yang dipasang pada objek (Model/Part) di Studio.
	Stat          : stat yang bertambah ("Hunger" / "Thirst").
	Amount        : poin yang ditambah per interaksi.
	Cooldown      : detik jeda antar interaksi (per pemain).
	ActionText    : teks prompt (hanya dipakai bila server membuat prompt sendiri).
	CooldownScope : "Object" = cooldown per objek per pemain; "Player" = per jenis (Food/Drink) per pemain.
	DistanceTolerance : toleransi jarak (stud) di atas MaxActivationDistance prompt untuk validasi server.
	PromptDistance    : MaxActivationDistance untuk prompt yang dibuat server.

	Override per objek (opsional, Attribute di objek ber-tag, di Studio):
	ConsumeAmount (number), ConsumeCooldown (number).
]]

export type StatDef = {
	Max: number,
	Start: number,
	DecayAmount: number,
	DecayInterval: number,
}

export type ConsumableDef = {
	Tag: string,
	Stat: string,
	Amount: number,
	Cooldown: number,
	ActionText: string,
}

export type ConsumableSettings = {
	CooldownScope: string,
	DistanceTolerance: number,
	PromptDistance: number,
	Types: { [string]: ConsumableDef },
}

export type Config = {
	Stats: { [string]: StatDef },
	StatOrder: { string },
	LowThreshold: number,
	Consumables: ConsumableSettings,
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

	Consumables = {
		CooldownScope = "Object",
		DistanceTolerance = 6,
		PromptDistance = 8,
		Types = {
			Food = {
				Tag = "Food",
				Stat = "Hunger",
				Amount = 1,
				Cooldown = 5,
				ActionText = "Makan",
			},
			Drink = {
				Tag = "Drink",
				Stat = "Thirst",
				Amount = 1,
				Cooldown = 5,
				ActionText = "Minum",
			},
		},
	},
}

return Config
