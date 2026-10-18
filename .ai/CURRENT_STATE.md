# CURRENT STATE

Last updated: 2026-10-18
Current phase: PHASE 2 (CP1 — bagian Hunger/Thirst dimulai)
Branch: main (base commit e41f25c "starter fix"), perubahan Hunger/Thirst belum di-commit

## Working systems
- Hunger/Thirst + HUD: TERIMPLEMENTASI, BELUM TERUJI di Studio (lihat CHANGELOG untuk tes yang sudah dilakukan).
- Konsumsi makanan/minuman (tag Food/Drink): TERIMPLEMENTASI, BELUM TERUJI di Studio. Butuh objek ber-tag di Studio.

## Incomplete systems
- Efek hunger/thirst = 0 (knock/slow) belum ada, menunggu Q1.
- Makan/minum (+40) menunggu Shop CP1; API server `SurvivalService.Add` sudah siap.
- Sistem gameplay lain belum dimulai.

## Known bugs
- lihat BUGS.md (belum ada)

## Hasil audit Phase 0
- Repo di-clone dan di-pull (fast-forward ke e41f25c). `default.project.json` kini ada; `rojo build` berhasil.
- Mapping: `src/shared`→ReplicatedStorage.Shared, `src/server`→ServerScriptService.Server (Script), `src/client`→StarterPlayerScripts.Client (LocalScript).
- Dokumentasi (`CLAUDE.md`, `.ai/`) kini diisi dari GDD v1.0 dan instruksi pengguna.
- Roblox Studio MCP tidak tersedia pada audit ini; Workspace belum diinspeksi. Nama objek di GDD belum terverifikasi.

## Current task
- Phase 2: verifikasi Hunger/Thirst + konsumsi di Studio (1 pemain, mobile emulator, 2+ pemain). Pengguna perlu memasang tag Food/Drink pada objek.

## Next task
- Setelah verifikasi: lanjut Phase 1/2 sesuai prioritas pengguna (interaksi + inventory, lalu Shop CP1).

## Dependencies / blockers
1. (Teratasi) `default.project.json` dan `src/` sudah ada.
2. Dump hierarchy Workspace dari Studio (folder, Part, NPC, spawn point, Tag, Attribute) atau akses Studio MCP.
3. Persetujuan DEC-003 (mekanisme gate per pemain).
4. Jawaban Q1 (knock/pemulihan), Q2 (shop), Q3 (angka damage) di GAME_CONTEXT bagian 16.
