# CHANGELOG

## 2026-10-18
- Perubahan: mengisi project instruction dan project memory dari GDD v1.0 dan instruksi pengguna; mengganti README starter kit.
- Sistem terdampak: dokumentasi saja.
- File/skrip: `CLAUDE.md`, `README.md`, `.ai/GAME_CONTEXT.md`, `.ai/CURRENT_STATE.md`, `.ai/TASKS.md`, `.ai/DECISIONS.md`.
- Hasil test: tidak ada kode; tidak berlaku.

## 2026-10-18 (2) — Hunger & Thirst + HUD
- Perubahan: sistem Hunger/Thirst (decay server, config), HUD kiri bawah responsif (mobile-aware), bootstrap server/client.
- Sistem terdampak: Survival (baru), bootstrap server/client (placeholder "Hello world" diganti).
- File/skrip: `src/shared/SurvivalConfig.luau`, `src/server/Services/SurvivalService.luau`, `src/server/init.server.luau`, `src/client/UI/SurvivalHud.luau`, `src/client/init.client.luau`, `.ai/*`.
- Hasil test: sintaks Luau OK, `rojo build` OK (mapping sesuai), logika decay lolos 15 uji simulasi (stub, di luar Roblox). Belum diuji di Studio, mobile, maupun multiplayer.

