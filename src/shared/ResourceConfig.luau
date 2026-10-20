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
	ItemId            : (opsional) id item di ItemConfig yang masuk inventory saat resource terambil. Stack
	                    penuh = resource TIDAK terambil (tetap di dunia, progres quest tidak maju).
	                    Tanpa ItemId, resource hanya memicu OnCollected (perilaku lama).

	CheckInterval : detik antar pemeriksaan pengambilan di server (mode "Proximity").
	Debug         : true = ResourceService mencetak alasan bila pengambilan via prompt ditolak (matikan setelah stabil).

	=== Cara pengambilan (PickupMode) ===
	"Proximity" (default bila kosong): otomatis saat pemain mendekat (PickupRadius/VerticalTolerance).
	"Prompt": ProximityPrompt TAHAN. Server membuat prompt bernama "ResourcePrompt" di tiap Part titik spawn
	          dan memvalidasi sendiri durasi tahan. PickupRadius/VerticalTolerance tidak dipakai.

	Prompt (wajib bila PickupMode = "Prompt"):
	  ActionText            : teks aksi (mis. "Ambil").
	  ObjectText            : teks objek (mis. "Ranting").
	  HoldDuration          : detik tahan sampai terambil. Harus > 0.
	  MaxActivationDistance : jarak (stud) prompt muncul.
	  DistanceTolerance     : toleransi jarak (stud) saat server memvalidasi.
	  HoldTolerance         : toleransi (detik) selisih jaringan; server menerima bila tahan >= HoldDuration - toleransi.
	  RequiresLineOfSight   : bool.
	AssetsFolder  : nama folder runtime di ReplicatedStorage.
	PromptName    : nama ProximityPrompt yang dibuat server di Part titik spawn (mode "Prompt"); dipakai client untuk menyembunyikan prompt titik tidak aktif.
]]

export type PromptDef = {
	ActionText: string,
	ObjectText: string,
	HoldDuration: number,
	MaxActivationDistance: number,
	DistanceTolerance: number,
	HoldTolerance: number,
	RequiresLineOfSight: boolean,
}

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
	ItemId: string?,
	PickupMode: string?,
	Prompt: PromptDef?,
}

export type Config = {
	CheckInterval: number,
	Debug: boolean,
	PromptName: string,
	AssetsFolder: string,
	Sets: { [string]: SetDef },
}

local Config: Config = {
	PromptName = "ResourcePrompt",
	Debug = true,
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
			ItemId = "Ranting",
			-- Instruksi 2026-10-18: ranting diambil lewat ProximityPrompt, tahan 12 detik (DEC-015).
			PickupMode = "Prompt",
			Prompt = {
				ActionText = "Ambil",
				ObjectText = "Ranting",
				HoldDuration = 1,
				MaxActivationDistance = 8,
				DistanceTolerance = 6,
				HoldTolerance = 0.5,
				RequiresLineOfSight = false,
			},
		},
	},
}

return Config
