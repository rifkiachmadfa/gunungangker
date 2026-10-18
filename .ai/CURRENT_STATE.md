# CURRENT STATE

Last updated: 2026-10-18
Current phase: PHASE 1/2 (Core + CP1) — Dialogue System selesai ditulis, menunggu tes Studio
Branch: main (HEAD a0f7a22 "fix"); Inventory stackable (ranting sebagai Tool) belum di-commit (diserahkan sebagai patch)

## Working systems
- Hunger/Thirst + HUD: TERIMPLEMENTASI, BELUM TERUJI di Studio (lihat CHANGELOG untuk tes yang sudah dilakukan).
- Konsumsi makanan/minuman (tag Food/Drink): TERIMPLEMENTASI, BELUM TERUJI di Studio. Butuh objek ber-tag di Studio.
- Dialogue System (NPC_Warung): TERIMPLEMENTASI, BELUM TERUJI di Studio. Butuh NPC_Warung + ProximityPrompt di Workspace.
- Quest System CP1 (ranting): TERIMPLEMENTASI, BELUM TERUJI di Studio. `ResourceService` + `QuestService` + `ResourceRenderer`. Butuh `Workspace.QuestObject.RantingBC_Spawner.RantingSpawner_N` dan `ServerStorage.QuestModels.Ranting`. Reward belum ada.
- Inventory stackable (`InventoryService` + `ItemConfig`): TERIMPLEMENTASI, BELUM TERUJI di Studio. Ranting yang terambil (`ResourceConfig...ItemId`) masuk sebagai SATU Tool `Ranting xN` di Backpack; `QuestService.TurnIn` mengonsumsi `Target` item. Butuh `ServerStorage.QuestModels["Ranting(Tool)"]` (Tool, dengan `Handle`). Lulus 50 uji mock di luar Roblox (lihat CHANGELOG).

## Incomplete systems
- Notification System (UI) dan UI Backpack kustom: belum dimulai (Tool memakai Backpack bawaan Roblox). Belum ada notifikasi "Ranting penuh". Event quest sudah dipancarkan, UI-nya belum ada.
- Efek hunger/thirst = 0 (knock/slow) belum ada, menunggu Q1.
- Makan/minum lewat Tool di Backpack (reward quest CP1, DEC-011) menunggu Quest/Backpack; API server `SurvivalService.Add` sudah siap.
- Sistem gameplay lain belum dimulai.

## Known bugs
- lihat BUGS.md (belum ada)

## Hasil audit Phase 0
- Repo di-clone dan di-pull (fast-forward ke e41f25c). `default.project.json` kini ada; `rojo build` berhasil.
- Mapping: `src/shared`→ReplicatedStorage.Shared, `src/server`→ServerScriptService.Server (Script), `src/client`→StarterPlayerScripts.Client (LocalScript).
- Dokumentasi (`CLAUDE.md`, `.ai/`) kini diisi dari GDD v1.0 dan instruksi pengguna.
- Roblox Studio MCP tidak tersedia pada audit ini; Workspace belum diinspeksi. Nama objek di GDD belum terverifikasi.

## Current task
- Dialogue + Quest CP1: tes di Studio (lihat langkah di respons sesi 2026-10-18), 1 pemain lalu 2+ pemain.
- Inventory ranting: tes di Studio (Tool terbentuk, satu slot, respawn, serah-terima mengonsumsi), 1 lalu 2+ pemain.
- Phase 2: verifikasi Hunger/Thirst + konsumsi di Studio (1 pemain, mobile emulator, 2+ pemain). Pengguna perlu memasang tag Food/Drink pada objek.

## Next task
- Notification System (toast UI; memakai `QuestService.Subscribe`), lalu reward: Backpack/Tool makanan-minuman saat quest Completed (jawab Q6 dulu), lalu gate CP1.
- Setelah verifikasi: lanjut Phase 1/2 sesuai prioritas pengguna (interaksi + inventory, lalu Shop CP1).

## Dependencies / blockers
0. Verifikasi di Studio: `ServerStorage.QuestModels["Ranting(Tool)"]` (Tool + Handle; nama pasti), `NPC_Warung` (nama unik, punya ProximityPrompt), `Workspace.QuestObject.RantingBC_Spawner` berisi 20 BasePart `RantingSpawner_N`, `ServerStorage.QuestModels.Ranting`; jawab Q6 dan Q7.
1. (Teratasi) `default.project.json` dan `src/` sudah ada.
2. Dump hierarchy Workspace dari Studio (folder, Part, NPC, spawn point, Tag, Attribute) atau akses Studio MCP.
3. Persetujuan DEC-003 (mekanisme gate per pemain).
4. Jawaban Q1 (knock/pemulihan), Q2 (shop), Q3 (angka damage) di GAME_CONTEXT bagian 16.
