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

## 2026-10-18 (3) — Makanan & minuman menambah Hunger/Thirst
- Perubahan: `ConsumableService` (tag Food/Drink, ProximityPrompt, +1% per interaksi, cooldown 5 dtk), config konsumsi di `SurvivalConfig`.
- Sistem terdampak: Survival (ditambah), bootstrap server.
- File/skrip: `src/server/Services/ConsumableService.luau`, `src/shared/SurvivalConfig.luau`, `src/server/init.server.luau`, `.ai/*`.
- Hasil test: sintaks Luau OK, `rojo build` OK, 28 kasus uji simulasi (stub) lolos. Belum diuji di Studio, dengan objek asli, maupun multiplayer.

## 2026-10-18 (4) — Dialogue System (NPC_Warung)
- Perubahan: sesi dialog server-authoritative (DialogueService), UI dialog responsif (typewriter, pilihan, input keyboard/touch/gamepad), data dialog Ibu Warung di config, modul `Remotes` dan util `Interaction`. Hook `RegisterAction`/`RegisterEntryResolver` untuk Quest System.
- Sistem terdampak: bootstrap server dan client; Remote baru `DialogueShow`/`DialogueEnd`/`DialogueRespond`. `ConsumableService`/`SurvivalService` tidak diubah.
- File/skrip: `src/shared/Remotes.luau`, `src/shared/DialogueConfig.luau`, `src/server/Util/Interaction.luau`, `src/server/Services/DialogueService.luau`, `src/client/UI/DialogueView.luau`, `src/client/Controllers/DialogueController.luau`, `src/server/init.server.luau`, `src/client/init.client.luau`, `.ai/*`.
- Hasil test: pemeriksaan keseimbangan blok/kurung (dengan kontrol negatif), konsistensi key config, nama Remote, dan graf dialog lolos; `git apply --check` patch pada clone bersih (lihat respons). TIDAK dilakukan: type-check Luau, `rojo build`, simulasi logika, dan uji Studio/mobile/multiplayer (tooling tidak tersedia di sandbox). Belum teruji sama sekali di runtime.

## 2026-10-18 (5) — Quest System CP1 (ranting)
- Perubahan: `ResourceService` (10 ranting aktif personal dari 20 titik, pengambilan otomatis dideteksi server, respawn di titik berbeda), `ResourceRenderer` (klon lokal dari Player attribute), `QuestService` (state None→Active→ReadyToTurnIn→Completed, event untuk notifikasi), wiring Dialogue (Action Accept/TurnIn, EntryResolver per state, variabel teks `{RantingCount}`/`{RantingTarget}`), node dialog quest.
- Sistem terdampak: Dialogue (tambah `RegisterTextVariable`; kontrak Remote tidak berubah), bootstrap server/client. Tidak ada Remote baru.
- File/skrip: `src/shared/ResourceConfig.luau`, `src/shared/QuestConfig.luau`, `src/server/Services/ResourceService.luau`, `src/server/Services/QuestService.luau`, `src/client/Controllers/ResourceRenderer.luau`, `src/server/Services/DialogueService.luau`, `src/shared/DialogueConfig.luau`, `src/server/init.server.luau`, `src/client/init.client.luau`, `.ai/*`.
- Hasil test: keseimbangan blok/kurung 18 file lolos; konsistensi key config, node/variabel/action dialog, dan nama modul lolos. TIDAK dilakukan: type-check Luau, `rojo build`, simulasi logika, uji Studio/multiplayer (tooling tidak tersedia di sandbox). Belum teruji di runtime.

## 2026-10-18 (6) — Ranting sebagai Tool stackable di Backpack
- Perubahan: `InventoryService` + `ItemConfig` (satu Tool per item, jumlah di server, dibangun ulang saat respawn). `ResourceService` memberi item ke inventory saat resource terambil (opsi `ItemId`); stack penuh = resource tetap di dunia. `QuestService.TurnIn` mengonsumsi item. Bootstrap server memulai `InventoryService` lebih dulu.
- Sistem terdampak: Resource, Quest, bootstrap server. Tidak ada Remote baru, tidak ada perubahan mapping Rojo, tidak ada perubahan client.
- File/skrip: `src/shared/ItemConfig.luau` (baru), `src/server/Services/InventoryService.luau` (baru), `src/shared/ResourceConfig.luau`, `src/server/Services/ResourceService.luau`, `src/server/Services/QuestService.luau`, `src/server/init.server.luau`, `.ai/*`.
- Hasil test: sintaks Luau OK, `rojo build` 7.7.1 OK, 50 kasus uji mock (modul asli Resource/Quest/Interaction/config; hanya DialogueService di-stub) lulus 40 kali berturut-turut, dan 15 mutasi sengaja semuanya tertangkap. Mock bukan Roblox sungguhan. TIDAK dilakukan: type-check strict Luau; uji Studio dengan Tool asli, respawn nyata, multiplayer.

## 2026-10-18 (7) — Ranting diambil lewat ProximityPrompt tahan 12 detik
- Perubahan: `ResourceService` mode `Prompt` (prompt `ResourcePrompt` di tiap titik spawn, validasi durasi tahan di server, jarak, titik aktif, hidup), `ResourceRenderer` menyembunyikan lokal prompt titik tidak aktif, konfigurasi `PickupMode`/`Prompt`/`Debug`/`PromptName` di `ResourceConfig`, konversi template Tool menjadi Model untuk tampilan client.
- Sistem terdampak: Resource, client renderer. Tidak ada Remote baru, tidak ada perubahan mapping Rojo, `InventoryService`/`QuestService` tidak diubah.
- File/skrip: `src/shared/ResourceConfig.luau`, `src/server/Services/ResourceService.luau`, `src/client/Controllers/ResourceRenderer.luau`, `.ai/*`.
- Hasil test: sintaks Luau OK, `luau-analyze` tanpa error non-API, `rojo build` OK; 104 (Tool = objek dunia) dan 101 (Tool terpisah) uji mock lulus, stabil 40 kali, dan 23 mutasi sengaja (validasi durasi/jarak/titik/hidup, konsumsi hold, sinkronisasi client, dll.): 22 tertangkap, 1 tidak teramati (pembersihan memori saat pemain keluar; tidak ada efek perilaku). Mock bukan Roblox sungguhan: perilaku asli ProximityPrompt (urutan event, UI tahan, mobile), replikasi prompt, dan multiplayer BELUM diuji di Studio.

## 2026-10-20 — Perbaikan BUG-001: renderer ranting mati untuk pemain yang menunggu lama
- Perubahan: `ResourceService.Start()` menyalin template resource sejak server start; `ResourceRenderer` tidak lagi berhenti bila template belum tiba (listener attribute + sinkron prompt tetap terpasang, template dicari ulang dan digambar saat tiba).
- Sistem terdampak: Resource (server dan client). Tidak ada Remote baru, tidak ada perubahan config, tidak ada perubahan logika validasi prompt.
- File/skrip: `src/server/Services/ResourceService.luau`, `src/client/Controllers/ResourceRenderer.luau`, `.ai/*`.
- Hasil test: `luau-compile` OK. Uji mock renderer (Roblox di-mock, source asli): versi lama gagal 7 dari 8 skenario (client yang menyala sebelum template ada), versi baru lulus 8 dari 8. Uji mock server: template ada sebelum `Activate` pertama (lama: tidak). Mock bukan Roblox sungguhan. TIDAK dilakukan: uji Studio, uji multiplayer nyata, `rojo build`.


## 2026-10-20 (b) — Notification System quest CP1 (toast + tujuan n/10)
- Perubahan: toast "Mendapatkan Ranting" tiap progres naik; kartu tujuan "Kumpulkan ranting n/10" (kanan-atas) setelah quest diterima; di 10/10 berubah menjadi pesan kembali ke Ibu Warung dan serahkan ranting; hilang saat quest Completed. Murni client, membaca Player attribute quest.
- Sistem terdampak: bootstrap client, `QuestConfig` (tambah `Notify`). Server, Remote, dan mapping Rojo tidak berubah.
- File/skrip: `src/shared/QuestNotify.luau` (baru), `src/shared/QuestConfig.luau`, `src/client/UI/NotificationView.luau` (baru), `src/client/Controllers/NotificationController.luau` (baru), `src/client/init.client.luau`, `.ai/*`.
- Hasil test: simulasi logika (port JS dari `QuestNotify` + alur render controller, bukan Luau asli) 15/15 lulus: 0/10 tanpa toast, +1 toast per ranting, 10/10 pesan kembali ke NPC, hilang saat Completed, tanpa toast ganda saat refresh/reset, urutan State-lalu-Progress. Keseimbangan blok/kurung lolos. TIDAK dilakukan: `luau-analyze`/type-check, `rojo build` (tooling tidak ada di sandbox ini), uji Studio, uji multiplayer, uji mobile.
