# CURRENT STATE

Last updated: 2026-10-20
Current phase: PHASE 1/2 (Core + CP1) — Dialogue System selesai ditulis, menunggu tes Studio
Branch: main (HEAD a0f7a22 "fix"); Inventory stackable (ranting sebagai Tool) belum di-commit (diserahkan sebagai patch)

## Working systems
- Hunger/Thirst + HUD: TERIMPLEMENTASI, BELUM TERUJI di Studio (lihat CHANGELOG untuk tes yang sudah dilakukan).
- Konsumsi makanan/minuman (tag Food/Drink): TERIMPLEMENTASI, BELUM TERUJI di Studio. Butuh objek ber-tag di Studio.
- Dialogue System (NPC_Warung): TERIMPLEMENTASI, BELUM TERUJI di Studio. Butuh NPC_Warung + ProximityPrompt di Workspace.
- Quest System CP1 (ranting): TERIMPLEMENTASI, BELUM TERUJI di Studio. `ResourceService` + `QuestService` + `ResourceRenderer`. Butuh `Workspace.QuestObject.RantingBC_Spawner.RantingSpawner_N` dan `ServerStorage.QuestModels.Ranting`. Reward belum ada.
- Pengambilan ranting via ProximityPrompt TAHAN 12 dtk (`ResourceService` mode `Prompt` + `ResourceRenderer`): TERIMPLEMENTASI, BELUM TERUJI di Studio. Prompt `ResourcePrompt` dibuat server di tiap Part titik spawn; durasi tahan diukur server (HoldBegan→Triggered). Lulus 104/101 uji mock (dua skenario template). Prompt hanya dibuat saat quest pertama kali diterima.
- Reward CP1 (Tool Air + Ciki, DEC-018): TERIMPLEMENTASI, BELUM TERUJI di Studio. `QuestService.TurnIn` memberi 1 Air + 1 Ciki; equip + tekan = +5% Thirst/Hunger, cooldown 5 dtk per item, divalidasi server (`ConsumableService`). Butuh Tool template ber-`Handle` di `ServerStorage.QuestModels.Air` dan `.Ciki` (path belum diverifikasi). Lulus 51 uji mock + 13 mutasi (lihat CHANGELOG).
- Inventory stackable (`InventoryService` + `ItemConfig`): TERIMPLEMENTASI, BELUM TERUJI di Studio. Ranting yang terambil (`ResourceConfig...ItemId`) masuk sebagai SATU Tool `Ranting xN` di Backpack; `QuestService.TurnIn` mengonsumsi `Target` item. Butuh Tool template di `ServerStorage.QuestModels` (path di `ItemConfig`, Tool dengan `Handle`). Lulus 50 uji mock di luar Roblox (lihat CHANGELOG).

- Notification System quest CP1 (toast + kartu tujuan n/10, `NotificationView`/`NotificationController`/`QuestNotify`): TERIMPLEMENTASI (2026-10-20), BELUM TERUJI di Studio. Client-only, membaca Attribute `Quest_<id>_State/Progress`; tanpa Remote baru.

## Incomplete systems
- UI Backpack kustom: belum dimulai (Tool memakai Backpack bawaan Roblox). Belum ada notifikasi "Ranting penuh" (stack penuh) dan notifikasi reward/quest selesai.
- Efek hunger/thirst = 0 (knock/slow) belum ada, menunggu Q1.
- Indikator cooldown Tool Air/Ciki di HUD dan notifikasi "dapat reward": belum ada (menunggu Notification System).
- Sistem gameplay lain belum dimulai.

## Known bugs
- lihat BUGS.md (belum ada)

## Hasil audit Phase 0
- Repo di-clone dan di-pull (fast-forward ke e41f25c). `default.project.json` kini ada; `rojo build` berhasil.
- Mapping: `src/shared`→ReplicatedStorage.Shared, `src/server`→ServerScriptService.Server (Script), `src/client`→StarterPlayerScripts.Client (LocalScript).
- Dokumentasi (`CLAUDE.md`, `.ai/`) kini diisi dari GDD v1.0 dan instruksi pengguna.
- Roblox Studio MCP tidak tersedia pada audit ini; Workspace belum diinspeksi. Nama objek di GDD belum terverifikasi.

## Current task
- Notifikasi quest: tes di Studio (terima quest -> 0/10 muncul; ambil ranting -> toast + n/10; 10/10 -> pesan kembali ke Ibu Warung; serahkan -> kartu hilang; 2 pemain terpisah).
- Dialogue + Quest CP1: tes di Studio (lihat langkah di respons sesi 2026-10-18), 1 pemain lalu 2+ pemain.
- Inventory ranting: tes di Studio (Tool terbentuk, satu slot, respawn, serah-terima mengonsumsi), 1 lalu 2+ pemain.
- Prompt ranting: tes di Studio (prompt muncul hanya di titik aktif, tahan 12 dtk, lepas dini = batal, 2 pemain). Bila prompt tidak pernah selesai, cek Output (`ResourceConfig.Debug` mencetak alasan penolakan).
- Reward Air/Ciki: tes di Studio (selesaikan quest CP1 -> Tool "Air" dan "Ciki" muncul di Backpack tanpa "xN"; equip + tekan = +5, tekan lagi <5 dtk tidak menambah; mati/respawn = Tool kembali; 2 pemain terpisah). Cek Output bila Tool tidak muncul (`InventoryService` mencetak Tool yang ada di folder template).
- Phase 2: verifikasi Hunger/Thirst + konsumsi di Studio (1 pemain, mobile emulator, 2+ pemain). Pengguna perlu memasang tag Food/Drink pada objek.

## Next task
- Tes Studio notifikasi (lihat CHANGELOG 2026-10-20 b) dan reward Air/Ciki (lihat CHANGELOG 2026-10-20 c), lalu gate CP1. Konfirmasi Q6 (Tool Air/Ciki memang tak habis dipakai?). Indikator cooldown Tool dan toast reward bisa menyusul di Notification System.
- Setelah verifikasi: lanjut Phase 1/2 sesuai prioritas pengguna (interaksi + inventory, lalu Shop CP1).

## Dependencies / blockers
0a. Tool `Air` dan `Ciki` (ber-`Handle`) di `ServerStorage.QuestModels` (atau ubah `ItemConfig.Items.Air/Ciki.TemplatePath`). Tanpa itu quest CP1 TIDAK dimulai (warning di Output).
0. Verifikasi di Studio: kondisi `ServerStorage.QuestModels`: `ItemConfig...TemplatePath` kini `{QuestModels, Ranting}` = path yang sama dengan `ResourceConfig...TemplatePath`; berarti `QuestModels.Ranting` harus Tool (dengan Handle) yang dipakai untuk inventory sekaligus (diubah jadi Model untuk tampilan dunia), ATAU kembalikan ItemConfig ke `Ranting(Tool)` bila Tool dan model dunia adalah dua objek berbeda, `NPC_Warung` (nama unik, punya ProximityPrompt), `Workspace.QuestObject.RantingBC_Spawner` berisi 20 BasePart `RantingSpawner_N`, `ServerStorage.QuestModels.Ranting`; jawab Q6 dan Q7.
1. (Teratasi) `default.project.json` dan `src/` sudah ada.
2. Dump hierarchy Workspace dari Studio (folder, Part, NPC, spawn point, Tag, Attribute) atau akses Studio MCP.
3. Persetujuan DEC-003 (mekanisme gate per pemain).
4. Jawaban Q1 (knock/pemulihan), Q2 (shop), Q3 (angka damage) di GAME_CONTEXT bagian 16.
