--!strict
--[[
	DialogueConfig — pengaturan dan data dialog NPC.

	Dibaca server (sumber kebenaran) dan client (hanya bagian UI). Teks dialog dikirim server ke
	client per node; client tidak memakai data Npcs.

	=== Pengaturan ===
	MaxChoices      : maksimum pilihan per node (UI + validasi server). Keyboard 1..4.
	MaxTextLength   : maksimum karakter teks per node (divalidasi saat start).
	StartTolerance  : toleransi jarak (stud) di atas MaxActivationDistance prompt saat MEMULAI dialog.
	LeaveTolerance  : dialog berakhir otomatis bila pemain lebih jauh dari MaxActivationDistance + nilai ini.
	StartCooldown   : detik minimum antar pembukaan dialog per pemain (anti-spam prompt).
	RespondInterval : detik minimum antar Advance/Choose per pemain (anti-spam Remote). Cancel tidak dibatasi.
	IdleTimeout     : dialog ditutup server bila tidak ada respons selama detik ini.
	CheckInterval   : detik antar pemeriksaan sesi aktif (jarak, hidup, idle).
	Prompt          : dipakai HANYA bila NPC tidak punya ProximityPrompt dan server harus membuatnya.
	UI.CharsPerSecond : kecepatan typewriter; 0 = teks langsung tampil.

	=== Data NPC ===
	Npcs[npcId] = {
		DisplayName : nama pembicara default.
		ModelName   : nama Model/Part NPC di Workspace (dicari rekursif; harus unik).
		Start       : id node awal (bisa ditimpa via DialogueService.RegisterEntryResolver).
		Nodes       : { [nodeId] = Node }
	}
	Node = {
		Speaker? : nama pembicara khusus node ini (default DisplayName).
		Text     : teks dialog.
		Choices? : { { Text, Next?, Action? } }  -- bila ada, pemain wajib memilih.
		Next?    : node berikutnya bila tanpa Choices; nil = dialog selesai.
		Action?  : nama aksi dijalankan server saat node DITAMPILKAN.
	}
	Choice.Action dijalankan server saat pilihan DIPILIH. Choice.Next nil = dialog selesai.

	Action hanyalah nama; logikanya didaftarkan sistem lain lewat DialogueService.RegisterAction.
	Aksi tanpa handler dilewati (warning sekali) sehingga dialog tetap jalan sebelum Quest System ada.
]]

export type Choice = {
	Text: string,
	Next: string?,
	Action: string?,
}

export type Node = {
	Speaker: string?,
	Text: string,
	Choices: { Choice }?,
	Next: string?,
	Action: string?,
}

export type Npc = {
	DisplayName: string,
	ModelName: string,
	Start: string,
	Nodes: { [string]: Node },
}

export type Config = {
	MaxChoices: number,
	MaxTextLength: number,
	StartTolerance: number,
	LeaveTolerance: number,
	StartCooldown: number,
	RespondInterval: number,
	IdleTimeout: number,
	CheckInterval: number,
	Prompt: {
		ActionText: string,
		Distance: number,
	},
	UI: {
		CharsPerSecond: number,
	},
	Npcs: { [string]: Npc },
}

local Config: Config = {
	MaxChoices = 4,
	MaxTextLength = 400,
	StartTolerance = 6,
	LeaveTolerance = 10,
	StartCooldown = 0.75,
	RespondInterval = 0.1,
	IdleTimeout = 90,
	CheckInterval = 0.5,

	Prompt = {
		ActionText = "Bicara",
		Distance = 8,
	},

	UI = {
		CharsPerSecond = 45,
	},

	Npcs = {
		-- CP1 — Ibu Warung. Teks acuan: GDD "Kalau mau minum dan makan, bantu ibu kumpulkan ranting dulu."
		-- {RantingCount} / {RantingTarget} diisi QuestService (variabel teks). Node Quest* dipilih
		-- QuestService lewat EntryResolver sesuai state quest (QuestConfig.Quests.CP1_Ranting.Entry).
		Warung = {
			DisplayName = "Ibu Warung",
			ModelName = "NPC_Warung",
			Start = "Greeting",
			Nodes = {
				Greeting = {
					Text = "Eh, ada pendaki baru. Mau naik ke atas, Nak? Jalannya masih jauh.",
					Choices = {
						{ Text = "Iya, Bu. Saya lapar dan haus.", Next = "AskBranches" },
						{ Text = "Cuma lewat saja, Bu.", Next = "Farewell" },
					},
				},
				AskBranches = {
					Text = "Kalau mau minum dan makan, bantu ibu kumpulkan ranting dulu. Ibu butuh {RantingTarget} ranting untuk tungku. Cari di sekitar hutan sini ya.",
					Choices = {
						-- "CP1.AcceptQuest" ditangani QuestService.
						{ Text = "Baik, Bu. Saya cari dulu.", Next = "Accepted", Action = "CP1.AcceptQuest" },
						{ Text = "Nanti saja, Bu.", Next = "Later" },
					},
				},
				Accepted = {
					Text = "Terima kasih, Nak. Hati-hati, hutan ini suka bikin orang bingung.",
				},
				Later = {
					Text = "Ya sudah. Kalau berubah pikiran, ibu ada di sini.",
				},
				QuestActive = {
					Text = "Baru {RantingCount} dari {RantingTarget} ranting, Nak. Terus cari di sekitar hutan ya.",
				},
				QuestReady = {
					Text = "Wah, rantingnya sudah cukup {RantingTarget}! Sini, serahkan ke ibu.",
					Choices = {
						-- "CP1.TurnIn" ditangani QuestService (juga memberi reward Air dan Ciki ke Backpack).
						{ Text = "Ini, Bu.", Next = "QuestDone", Action = "CP1.TurnIn" },
					},
				},
				QuestDone = {
					Text = "Terima kasih, Nak. Tungku ibu sudah bisa menyala. Ini ada air dan ciki buat bekal. Pegang, lalu tekan kalau haus atau lapar ya.",
				},
				QuestAfter = {
					Text = "Tungku ibu sudah menyala berkat kamu. Hati-hati di atas sana, Nak.",
				},
				Farewell = {
					Text = "Hati-hati di jalan. Gunung ini nggak seramah kelihatannya.",
				},
			},
		},

		-- CP2 — Taufik, penjaga jalan di Hutan Bambu. Butuh KAYU dan TALI untuk memperbaiki palang jalan,
		-- lalu membuka jalan ke atas. Tidak ada angka/variabel jumlah di teks (jumlah belum ditentukan).
		-- Dialog BELUM terhubung ke Quest System: Action di bawah dilewati (warning sekali) sampai ada
		-- handler. Node Quest* tidak tercapai dari Start; dipilih QuestService nanti lewat EntryResolver
		-- (nama node mengikuti pola CP1: QuestActive / QuestReady / QuestAfter).
		Taufik = {
			DisplayName = "Taufik",
			ModelName = "NPC_Taufik",
			Start = "Greeting",
			Nodes = {
				Greeting = {
					Text = "Berhenti dulu, Dik. Jalan ke atas lewat sini, dan saya yang jaga. Hutan bambu ini bukan tempat buat jalan sembarangan.",
					Choices = {
						{ Text = "Saya mau naik ke atas, Mas.", Next = "AskMaterials" },
						{ Text = "Memangnya ada apa di atas?", Next = "Warning" },
						{ Text = "Cuma lihat-lihat, Mas.", Next = "Farewell" },
					},
				},
				Warning = {
					Text = "Namanya juga gunung, Dik. Makin ke atas makin sepi dan makin gelap. Kalau ada yang bisik-bisik di rumpun bambu, itu bukan angin. Jangan dijawab kalau ada yang manggil nama kamu.",
					Choices = {
						{ Text = "Saya tetap mau naik.", Next = "AskMaterials" },
						{ Text = "Saya pikir-pikir dulu, Mas.", Next = "Later" },
					},
				},
				AskMaterials = {
					Text = "Boleh, tapi palang jalan di pos ini rusak. Saya tidak bisa jaga jalan dengan palang begitu. Bantu saya cari kayu dan tali buat memperbaikinya. Setelah itu jalannya saya buka.",
					Choices = {
						-- "CP2.AcceptQuest" belum punya handler (menunggu Quest System CP2).
						{ Text = "Baik, Mas. Saya carikan.", Next = "Accepted", Action = "CP2.AcceptQuest" },
						{ Text = "Kayu dan tali? Cari di mana, Mas?", Next = "Hint" },
						{ Text = "Nanti saja, Mas.", Next = "Later" },
					},
				},
				Hint = {
					Text = "Cari di sekitar hutan bambu ini saja. Pelan-pelan, Dik, dan jangan jauh-jauh dari jalan setapak. Hutan ini cepat gelap.",
					Choices = {
						{ Text = "Baik, Mas. Saya carikan.", Next = "Accepted", Action = "CP2.AcceptQuest" },
						{ Text = "Nanti saja, Mas.", Next = "Later" },
					},
				},
				Accepted = {
					Text = "Terima kasih, Dik. Saya tunggu di sini. Jangan lama-lama ya.",
				},
				Later = {
					Text = "Ya sudah. Palangnya masih rusak, jadi jalan belum bisa saya buka. Kalau sudah siap, balik lagi ke saya.",
				},
				QuestActive = {
					Text = "Kayu dan talinya belum cukup, Dik. Cari lagi di sekitar hutan bambu ini. Saya tunggu di sini.",
				},
				QuestReady = {
					Text = "Nah, kayu dan talinya sudah cukup! Sini, serahkan ke saya, biar palangnya saya betulkan.",
					Choices = {
						-- "CP2.TurnIn" belum punya handler (menunggu Quest System CP2).
						{ Text = "Ini, Mas.", Next = "QuestDone", Action = "CP2.TurnIn" },
					},
				},
				QuestDone = {
					Text = "Terima kasih, Dik. Palangnya sudah kuat lagi, jalan ke atas saya buka. Hati-hati, di atas sana lebih gelap dari di sini.",
				},
				QuestAfter = {
					Text = "Jalannya sudah terbuka, Dik. Terus naik, dan jangan menoleh kalau ada yang manggil dari belakang.",
				},
				Farewell = {
					Text = "Ya sudah. Hati-hati, Dik. Jangan keluar dari jalan setapak.",
				},
			},
		},
	},
}

return Config
