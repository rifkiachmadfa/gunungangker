# DECISIONS

## DEC-001 — Jimat mengurangi damage hantu, bukan WalkSpeed
- Tanggal: 2026-10-18
- Konteks: GDD §5.4 mendefinisikan Jimat sebagai WalkSpeed +4 (16→20). Instruksi terbaru pengguna: jimat membuat hantu CP5 memberi damage lebih kecil dan lebih sulit knock.
- Keputusan: ikuti instruksi terbaru. Jimat = pengurangan damage/knock dari hantu. WalkSpeed +4 tidak diimplementasikan.
- Alternatif ditolak: menggabungkan keduanya (belum diminta).
- Dampak: GhostSystem membaca flag jimat dari state personal server. Angka damage menunggu Q3. TalismanEquip/SpeedEffect di GDD §12 perlu diverifikasi perannya di Studio.

## DEC-002 — CP4 opsional dan tidak memblokir progres
- Tanggal: 2026-10-18
- Konteks: GDD memperlakukan CP4 sebagai langkah berurutan. Instruksi terbaru: quest CP4 opsional.
- Keputusan: tidak ada gate yang mengunci setelah CP4. Selesai = Jimat; dilewati = tanpa jimat. `CP4_COMPLETE` tidak menjadi syarat CP5.
- Dampak: state machine, HUD, dan validasi gate CP5 tidak boleh menganggap CP4_COMPLETE wajib. Jalur CP3→CP4 tetap butuh torch ON.

## DEC-003 — Gate per-pemain di model progres personal (USULAN, menunggu persetujuan)
- Tanggal: 2026-10-18
- Konteks: Instruksi: invisible wall `CanCollide=false` saat quest selesai, `true` jika belum. Tetapi progres bersifat personal, sedangkan `CanCollide` di server berlaku untuk semua pemain. Jika server mengubahnya, satu pemain yang menyelesaikan quest akan membuka gate untuk semua.
- Usulan: server menyimpan progres per pemain dan menaruhnya di Attribute pada Player; client men-set `CanCollide` lokal pada wall berdasarkan Attribute itu; server menambah pengecekan posisi dan mengembalikan pemain ke checkpoint jika melewati gate yang belum terbuka (anti-skip).
- Alternatif: (a) shared gate, terbuka untuk semua jika satu pemain selesai (mengubah model progres, tidak disarankan); (b) collision group per pemain (tidak didukung per-pemain di server).
- Dampak: multiplayer, anti-exploit. Perlu persetujuan sebelum Phase 1.

## DEC-004 — Resource personal, spawn dikontrol server
- Tanggal: 2026-10-18
- Konteks: GDD §4 menyarankan personal resource state.
- Keputusan: server memilih posisi spawn; ketersediaan dan penghapusan dilacak per pemain; client hanya menampilkan resource yang aktif untuk dirinya.
- Dampak: ResourceSystem menyimpan state per pemain, bukan menghancurkan objek global.

## DEC-005 — Lobby, teleport, dan cutscene ditunda
- Tanggal: 2026-10-18
- Keputusan: dikerjakan setelah main place stabil (cutscene Moon Animator 2, lobby, pilih 1–5 pemain, cooldown 10 detik, teleport).
- Dampak: sistem lain tidak boleh bergantung padanya; spawn awal memakai basecamp langsung.

## DEC-006 — Parameter Hunger/Thirst mengikuti instruksi terbaru, lewat config
- Tanggal: 2026-10-18
- Konteks: GDD: mulai 100, Hunger −1/30 dtk, Thirst −1/20 dtk. Instruksi terbaru: mulai 50, turun 1 per 5 detik, dan harus mudah diatur.
- Keputusan: semua angka berada di `src/shared/SurvivalConfig.luau` per stat (Max, Start, DecayAmount, DecayInterval). Nilai awal 50; interval awal 5 dtk lalu diubah pengguna menjadi 10 dtk (commit 347ef28), untuk keduanya. `DecayInterval <= 0` mematikan decay stat itu.
- Dampak: GDD §Survival diberi anotasi. Efek di 0 (knock/slow) TIDAK diimplementasikan; menunggu Q1. Decay dijeda saat pemain tidak punya karakter hidup (asumsi; belum ada player state formal). Nilai tidak di-reset saat respawn karena disimpan di Player, bukan karakter (asumsi, perlu konfirmasi).

## DEC-007 — State survival sebagai Attribute di Player, HUD dibuat lewat kode
- Tanggal: 2026-10-18
- Konteks: butuh sinkronisasi server→client tanpa Remote baru; StarterGui tidak dipetakan Rojo dan Studio belum bisa diinspeksi.
- Keputusan: server menulis Attribute `Hunger` dan `Thirst` pada Player (selaras arah DEC-003). Client hanya membaca dan menggambar HUD dari kode (`src/client/UI/SurvivalHud.luau`). Tidak ada RemoteEvent/RemoteFunction baru. Pemilik tunggal state: `SurvivalService`.
- HUD: pojok kiri bawah. Pada perangkat touch dinaikkan 150 px karena thumbstick bawaan Roblox berada di kiri bawah.
- Dampak: tidak ada perubahan mapping Rojo. HUD survival lain (HP, checkpoint, dll.) nanti dapat memakai pola yang sama.

## DEC-008 — Makanan/minuman di dunia: tag + ProximityPrompt, +1% dengan cooldown 5 dtk (config)
- Tanggal: 2026-10-18
- Konteks: instruksi terbaru: berinteraksi dengan makanan/minuman menambah 1% lapar/haus, cooldown sekitar 5 detik, bisa diatur. Nama objek di Workspace belum terverifikasi (Studio tidak bisa diinspeksi), dan GDD §12 belum punya tag. Ini terpisah dari Shop CP1 (+40, lewat Ibu Warung) yang tetap pada rencana awal.
- Keputusan: `ConsumableService` mengikat semua objek ber-CollectionService tag `Food`/`Drink`. Memakai ProximityPrompt yang sudah ada di objek; bila tidak ada, server membuatnya (tanpa membuat Part/aset). Amount=1 dan Cooldown=5 per jenis di `SurvivalConfig.Consumables`; override per objek via Attribute `ConsumeAmount`/`ConsumeCooldown`.
- Cooldown: per pemain. `CooldownScope = "Object"` (default, per objek) atau `"Player"` (per jenis Food/Drink). Default "Object" mengikuti pembacaan literal; risikonya satu pemain bisa berpindah antar objek untuk menambah lebih cepat. Ubah ke "Player" bila tidak diinginkan.
- Aturan: stat sudah penuh = tidak ada efek dan cooldown tidak terpakai. Objek tidak dihapus setelah dipakai.
- Validasi server: karakter hidup, tag masih terpasang, jarak (MaxActivationDistance prompt + `DistanceTolerance`), cooldown, stat belum penuh, nilai Attribute divalidasi (tidak valid = pakai default).
- Dampak: tidak ada Remote baru, tidak ada perubahan mapping Rojo. Pemasangan tag di Studio dilakukan manual oleh pengguna.

## DEC-009 — Dialogue System: sesi server-authoritative, data di config, logika quest lewat hook
- Tanggal: 2026-10-18
- Konteks: Phase 1/CP1 butuh dialog NPC sebelum Notification dan Quest System. Urutan dari pengguna: Dialogue → Notification → Quest → Backpack/Tool.
- Keputusan: `DialogueService` (server) pemilik tunggal sesi dialog per pemain (satu sesi aktif per pemain). Client hanya presentasi dan mengirim intent (`Advance`/`Choose index`/`Cancel`); node berikutnya ditentukan server. Data dialog (graf node) di `src/shared/DialogueConfig.luau`, divalidasi saat start. Dialog TIDAK berisi logika quest: efek dipanggil lewat nama Action → `DialogueService.RegisterAction(name, handler)`; node awal dinamis lewat `RegisterEntryResolver(npcId, fn)`. Action tanpa handler dilewati dengan warning sekali.
- NPC diikat lewat `ModelName` (dicari rekursif di Workspace, bukan tag), memakai ProximityPrompt yang sudah ada di NPC; server hanya membuat prompt bila tidak ada (pola sama dengan DEC-008), tidak membuat Part/aset. Alasan: pengguna sudah menyebut nama `NPC_Warung`; tidak perlu pemasangan tag manual. Risiko: nama harus unik di Workspace; bila ada beberapa ProximityPrompt di dalam NPC, yang dipakai yang pertama ditemukan.
- Validasi server: karakter hidup, jarak (prompt + toleransi), cooldown mulai, rate limit Advance/Choose, tipe/indeks argumen, sesuai tipe node, dan pemeriksaan berkala (mati/menjauh/NPC hilang/idle). Klik prompt saat sesi aktif = sesi diganti dan dimulai ulang dari node awal.
- Karakter tidak dibekukan selama dialog (tidak ada interaksi dengan WalkSpeed milik Survival). Dialog ditutup server bila pemain menjauh.
- Dampak: Remote baru (lihat GAME_CONTEXT §13), modul baru `Remotes` (shared) dan `Interaction` (server util). `ConsumableService` TIDAK diubah; helper jarak/prompt-nya masih duplikat kecil dengan `Interaction` (kandidat refactor setelah ConsumableService teruji).

## DEC-010 — Remote dibuat runtime lewat modul `Remotes`
- Tanggal: 2026-10-18
- Keputusan: `src/shared/Remotes.luau`; server membuat `ReplicatedStorage.Remotes/<Nama>` (idempoten), client `WaitForChild`. Tidak ada perubahan `default.project.json`. Setiap Remote baru wajib dicatat di GAME_CONTEXT §13.
- Alternatif ditolak: folder Remote statis di Rojo (menambah mapping; belum perlu).

## DEC-011 — Reward CP1 = Tool makanan/minuman di Backpack (menggantikan "shop") — CATATAN INSTRUKSI, belum diimplementasi
- Tanggal: 2026-10-18
- Konteks: GDD/Q2 menyebut shop. Instruksi terbaru pengguna: setelah ranting terkumpul, quest memberi makanan dan minuman ke Backpack sebagai Tool; di-equip menambah lapar/haus.
- Keputusan: ikuti instruksi terbaru. Detail (jumlah tambah, sekali pakai atau tidak, jumlah Tool) = Q6, menunggu jawaban pengguna. Dikerjakan di fase Quest/Backpack, bukan di Dialogue.
- Dampak: Q2 praktis terjawab (tanpa currency/harga). Tool memakai `SurvivalService.Add`.

## DEC-012 — Quest/Resource dipisah; pengambilan dideteksi server; resource personal digambar client
- Tanggal: 2026-10-18
- Konteks: instruksi: pemain mendekati ranting → terambil, progres quest +1, ranting hilang dan muncul di tempat berbeda; 10 ranting → notifikasi; reward saat kembali ke dialog. DEC-004 mensyaratkan resource personal.
- Keputusan:
  - `ResourceService` (generik, siap dipakai CP2/CP5) memilih titik aktif PER PEMAIN dan mendeteksi pengambilan di server (jarak horizontal ≤ `PickupRadius` dan selisih tinggi ≤ `VerticalTolerance`, cek tiap `CheckInterval`). Tidak ada Remote dari client → tidak bisa dipalsukan.
  - `QuestService` pemilik tunggal progres (None → Active → ReadyToTurnIn → Completed). Resource tidak tahu quest; quest mendengar `ResourceService.OnCollected`. UI/Notifikasi mendengar `QuestService.Subscribe` dan/atau Player attribute.
  - Resource personal: server menulis titik aktif ke Player attribute; client (`ResourceRenderer`) membuat klon lokal di `Workspace.LocalResources`. Pemain lain tidak melihat atau menghabiskan resource Anda. Template disalin server dari `ServerStorage.QuestModels.Ranting` ke `ReplicatedStorage.QuestAssets` (asli tidak diubah). Klon: anchored, non-collide, Script/Prompt/ClickDetector dihapus.
  - Titik spawn BERBEDA: titik pengganti dipilih acak dari titik yang tidak aktif dan bukan titik yang baru diambil. `RespawnDelay` = 3 dtk mengikuti GDD (config; 0 = langsung). Selama jeda, jumlah aktif sementara kurang dari 10 (GDD: "tunggu 3 detik → spawn"); jumlah tidak pernah melebihi `ActiveCount`.
  - Mencapai Target: sisa ranting dihapus dan respawn tertunda dibatalkan.
  - Dialog mengikuti state quest lewat `RegisterEntryResolver` + variabel teks `{RantingCount}`/`{RantingTarget}` (`RegisterTextVariable`); Action `CP1.AcceptQuest`/`CP1.TurnIn` ditangani `QuestService`.
- Dampak: tidak ada Remote baru dan tidak ada perubahan mapping Rojo. Bergantung pada nama Workspace/ServerStorage dari pengguna (belum terverifikasi): `Workspace.QuestObject.RantingBC_Spawner.RantingSpawner_N` (BasePart) dan `ServerStorage.QuestModels.Ranting` (Model atau BasePart). Jika salah satu tidak ditemukan, quest TIDAK dimulai dan warning dicetak. Quest belum persisten (hilang saat pemain keluar). Satu quest per NPC (resolver belum menggabung banyak quest).
- Catatan: notifikasi sistem BELUM ada UI-nya; event "Progress"/"ReadyToTurnIn" sudah dipancarkan. `QuestConfig.Debug = true` mencetak log progres ke Output untuk pengujian.

## DEC-013 — Inventory stackable: satu Tool per item, jumlah di server
- Tanggal: 2026-10-18
- Konteks: instruksi pengguna: ranting dipegang sebagai Tool di Backpack, tidak boleh memenuhi slot, harus bisa di-stack; template Tool ada di `QuestModels/Ranting(Tool)`. Sebelumnya ranting hanya progres quest (DEC-012), bukan item.
- Keputusan: `InventoryService` menyimpan jumlah per pemain di server; Backpack hanya berisi SATU Tool per item (nama `<DisplayName> xN`, Attribute Tool `ItemId`/`Count`). Jumlah juga ditulis ke Attribute Player `Item_<id>` (pola DEC-007) untuk HUD/UI. Definisi item di `src/shared/ItemConfig.luau` (`TemplatePath` dari ServerStorage, `MaxStack`). Tool `CanBeDropped=false` agar stack tidak terduplikasi (tombol Drop GDD menunggu desain UI Backpack kustom). Template Tool BEDA dari `QuestModels.Ranting` (model dunia untuk ResourceRenderer); keduanya tidak diubah.
- Inventory TIDAK hilang saat mati; Tool dibangun ulang dari data server setelah respawn (asumsi, Q8). `MaxStack` ranting 20 (Q7).
- Alternatif ditolak: satu Tool per ranting (memenuhi hotbar, bertentangan dengan permintaan); jumlah dihitung dari jumlah Tool (client bisa memanipulasi, tidak server-authoritative).
- Dampak: quest/NPC wajib memakai `InventoryService.GetCount/RemoveItem`, bukan menghitung Tool. Item lain (batu maks 1, sesajen, ikan, obor) cukup ditambah ke `ItemConfig.Items`.

## DEC-014 — Resource masuk inventory lewat `ResourceConfig...ItemId`; serah-terima quest mengonsumsi item
- Tanggal: 2026-10-18
- Keputusan: set resource boleh punya `ItemId` (opsional). Saat terambil, `ResourceService` memanggil `InventoryService.AddItem` SEBELUM `OnCollected` (QuestService selalu melihat inventory yang sudah konsisten). Bila stack penuh atau template Tool hilang, resource TIDAK terambil: tetap di dunia dan progres quest tidak maju (dicoba lagi pada pemeriksaan berikutnya). `Activate` gagal lebih awal (quest tidak dimulai, warning) bila `ItemId` tidak ada di `ItemConfig` atau template Tool tidak ditemukan. `QuestService.TurnIn` mengonsumsi `Target` item dari inventory secara atomik; jika kurang, TurnIn ditolak dan state tidak berubah. Tanpa `ItemId`, perilaku lama tetap (kompatibel).
- Alasan: DEC-004/012 sudah menyediakan resource personal; yang kurang hanya penghubung ke inventory. Tidak ada Remote baru, tidak ada sistem pickup paralel.
- Risiko: dialog node "serah" tetap tampil walau `TurnIn` menolak (kasus tak normal: item kurang). Tidak ada notifikasi "stack penuh" sampai Notification System ada. Quest tetap menghitung progres sendiri (`Quest_<id>_Progress`); inventory dan progres bisa berbeda hanya jika pemain memakai/menyerahkan item lewat jalur lain (belum ada).

## DEC-015 — Ranting diambil lewat ProximityPrompt tahan 12 dtk; durasi divalidasi server
- Tanggal: 2026-10-18
- Konteks: instruksi pengguna: ranting dipencet dengan ProximityPrompt dan harus ditahan 12 detik sebelum masuk Backpack. Sebelumnya (DEC-012) pengambilan otomatis saat mendekat.
- Keputusan: `ResourceConfig.Sets[x].PickupMode` = `"Prompt"` (ranting CP1) atau `"Proximity"` (default, perilaku lama). Mode Prompt: server membuat `ProximityPrompt` bernama `ResourcePrompt` (config: `Prompt.HoldDuration=12`, jarak 8, teks "Ambil"/"Ranting") sebagai child tiap Part titik spawn; tidak ada Remote baru dan tidak ada Part/aset baru. Resource tetap personal (DEC-004): prompt menyala di server untuk semua, tetapi client menyembunyikan secara lokal prompt titik yang tidak aktif untuk dirinya (`ResourceRenderer`), dan server MENOLAK titik yang tidak aktif untuk pemain tersebut.
- Validasi server (engine tidak dipercaya untuk durasi; exploit `fireproximityprompt` memicu Triggered tanpa HoldBegan): hold harus dimulai (`PromptButtonHoldBegan`, waktu dicatat server), dilepas sebelum selesai = batal, `Triggered` harus datang setelah ≥ `HoldDuration - HoldTolerance` (1.5 dtk) dan ≤ `HoldDuration + 10` dtk, prompt sama dengan yang di-hold, titik aktif untuk pemain itu, karakter hidup, jarak ≤ `MaxActivationDistance + DistanceTolerance`. Satu hold = satu percobaan (dikonsumsi walau ditolak). Urutan `HoldEnded`/`Triggered` saat hold selesai tidak diasumsikan (keduanya urutan diterima). Penolakan dicetak bila `ResourceConfig.Debug = true`.
- Stack penuh = hold sah tetap ditolak, ranting tetap di dunia (DEC-014); belum ada notifikasi.
- Tambahan defensif: bila template resource berupa Tool (kasus `ItemConfig` dan `ResourceConfig` menunjuk `QuestModels.Ranting` yang sama), `ResourceService` mengubah salinan untuk client menjadi Model (Handle = PrimaryPart, Script dibuang) karena `ResourceRenderer` hanya menggambar Model/BasePart. Template asli tidak diubah.
- Risiko/utang: prompt dibuat saat quest pertama kali diterima (belum saat server start); prompt dan hide-lokal bergantung pada perilaku engine yang belum diuji di Studio; mobile menampilkan tombol tahan bawaan Roblox.
- Alternatif ditolak: prompt di klon lokal client + Remote (menambah kontrak Remote dan rate-limit); durasi tahan dipercayakan ke `HoldDuration` engine saja (bisa dibypass exploit).

## DEC-016 — Template resource disalin saat server start; client tidak berhenti bila template belum tiba
- Tanggal: 2026-10-20
- Konteks: BUG-001. Template dibuat lazy saat `Activate` pertama, sedangkan client berhenti menunggu setelah `ASSET_WAIT_TIMEOUT`.
- Keputusan: (1) `ResourceService.Start()` memanggil `ensureAsset` untuk semua set (idempoten; `Activate` tetap memanggilnya). (2) `ResourceRenderer.bindSet` tidak `return` saat template belum ada: listener attribute dan sinkron prompt selalu terpasang; template dicari lewat `resolveTemplate()` setiap kali menggambar, dan ditunggu di latar belakang lalu `apply()` ulang begitu tiba.
- Alasan: kegagalan menunggu template tidak boleh mematikan seluruh renderer pemain. Dua lapis supaya salah satu saja yang gagal tidak mengulang bug.
- Dampak: tidak ada Remote baru, tidak ada perubahan kontrak. Pembuatan prompt di spawner (`ensurePrompts`) tetap saat `Activate` pertama (utang DEC-015 tidak diubah).


## DEC-017 — Notifikasi quest murni client, digerakkan Player attribute server
- Tanggal: 2026-10-20
- Konteks: instruksi pengguna: toast saat dapat ranting; tujuan "0/10" muncul setelah bicara dengan NPC dan bertambah tiap ranting; di 10/10 muncul pemberitahuan kembali ke NPC dan serahkan; setelah berdialog (serah) notifikasi hilang.
- Keputusan: `NotificationController` (client) membaca `Quest_<id>_State`/`Quest_<id>_Progress` yang sudah ditulis `QuestService` (server) dan menggambar lewat `NotificationView`. Logika murni (format teks, kapan toast/tujuan) di `src/shared/QuestNotify.luau`; teks di `QuestConfig.Quests[id].Notify`. Tidak ada Remote baru, tidak ada perubahan server, tidak ada perubahan mapping Rojo.
- Aturan tampil: tujuan terlihat saat Active dan ReadyToTurnIn; hilang saat Completed (atau None). Toast hanya saat progres NAIK (mulai quest 0, reset, dan nilai awal saat join tidak memicu toast). Render digabung per frame (`task.defer`) karena State dan Progress diset berurutan oleh server.
- Interpretasi "setelah berdialog": tujuan hilang saat quest Completed (serah-terima sukses lewat pilihan "Ini, Bu."), BUKAN saat dialog sekadar dibuka. Membuka lalu menutup dialog di state ReadyToTurnIn tidak menghapus tujuan karena quest belum selesai.
- Alasan: state personal sudah server-authoritative dan terreplikasi; client tidak bisa memalsukan progres karena hanya menampilkan. Menghindari Remote/listener paralel (`QuestService.Subscribe` tetap untuk sistem server).
- Risiko: bergantung urutan replikasi attribute (diatasi coalesce); `QuestConfig.Debug` log server masih aktif; belum ada notifikasi stack penuh, reward, atau quest selesai.
