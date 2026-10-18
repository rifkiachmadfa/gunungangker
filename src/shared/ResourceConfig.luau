--!strict
--[[
	ResourceConfig — definisi resource yang tersebar di dunia (ranting, nanti batu/sesajen).

	Resource bersifat PERSONAL (DEC-004): tiap pemain punya set titik aktif sendiri. Server memilih titik
	dan mendeteksi pengambilan; client hanya menggambar model lokal dari Player attribute.

	=== Per set (Sets[setId]) ===
	SpawnerFolder     : path Instance dari Workspace ke folder berisi Part titik spawn.
	SpawnerPrefix     : titik spawn = anak BasePart dari folder dengan nama berawalan ini (mis. RantingSpawner_1).
	                    Nama titik tidak boleh mengandung koma.
	TemplatePath      : path dari ServerStorage ke model template. Server menyalinnya (klon) ke
	                    ReplicatedStorage.<AssetsFolder>.<AssetName> agar client bisa menggambarnya.
	                    Template asli tidak diubah.
	AssetName         : nama salinan di ReplicatedStorage.
	Attribute         : nama Player attribute berisi daftar titik aktif (nama dipisah koma).
	ActiveCount       : jumlah resource aktif per pemain pada satu waktu.
	RespawnDelay      : detik dari resource diambil sampai muncul lagi di titik BERBEDA (GDD: 3). 0 = langsung.
	PickupRadius      : jarak horizontal (stud) pemain ke titik agar resource terambil otomatis.
	VerticalTolerance : selisih tinggi maksimum (stud) pemain terhadap titik.
	PlacementOffset   : offset lokal model terhadap Part titik spawn (hanya untuk tampilan client).

	CheckInterval : detik antar pemeriksaan pengambilan di server.
	AssetsFolder  : nama folder runtime di ReplicatedStorage.
]]

export type SetDef = {
	SpawnerFolder: { string },
	SpawnerPrefix: string,
	TemplatePath: { string },
	AssetName: string,
	Attribute: string,
	ActiveCount: number,
	RespawnDelay: number,
	PickupRadius: number,
	VerticalTolerance: number,
	PlacementOffset: Vector3,
}

export type Config = {
	CheckInterval: number,
	AssetsFolder: string,
	Sets: { [string]: SetDef },
}

local Config: Config = {
	CheckInterval = 0.1,
	AssetsFolder = "QuestAssets",

	Sets = {
		-- CP1: 10 ranting aktif dari 20 titik. Nama path dari pengguna, BELUM diverifikasi di Studio.
		RantingCP1 = {
			SpawnerFolder = { "QuestObject", "RantingBC_Spawner" },
			SpawnerPrefix = "RantingSpawner_",
			TemplatePath = { "QuestModels", "Ranting" },
			AssetName = "Ranting",
			Attribute = "ActiveResources_RantingCP1",
			ActiveCount = 10,
			RespawnDelay = 3,
			PickupRadius = 6,
			VerticalTolerance = 8,
			PlacementOffset = Vector3.new(0, 0, 0),
		},
	},
}

return Config
