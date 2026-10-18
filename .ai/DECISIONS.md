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
- Keputusan: semua angka berada di `src/shared/SurvivalConfig.luau` per stat (Max, Start, DecayAmount, DecayInterval). Nilai awal 50, interval 5 dtk untuk keduanya. `DecayInterval <= 0` mematikan decay stat itu.
- Dampak: GDD §Survival diberi anotasi. Efek di 0 (knock/slow) TIDAK diimplementasikan; menunggu Q1. Decay dijeda saat pemain tidak punya karakter hidup (asumsi; belum ada player state formal). Nilai tidak di-reset saat respawn karena disimpan di Player, bukan karakter (asumsi, perlu konfirmasi).

## DEC-007 — State survival sebagai Attribute di Player, HUD dibuat lewat kode
- Tanggal: 2026-10-18
- Konteks: butuh sinkronisasi server→client tanpa Remote baru; StarterGui tidak dipetakan Rojo dan Studio belum bisa diinspeksi.
- Keputusan: server menulis Attribute `Hunger` dan `Thirst` pada Player (selaras arah DEC-003). Client hanya membaca dan menggambar HUD dari kode (`src/client/UI/SurvivalHud.luau`). Tidak ada RemoteEvent/RemoteFunction baru. Pemilik tunggal state: `SurvivalService`.
- HUD: pojok kiri bawah. Pada perangkat touch dinaikkan 150 px karena thumbstick bawaan Roblox berada di kiri bawah.
- Dampak: tidak ada perubahan mapping Rojo. HUD survival lain (HP, checkpoint, dll.) nanti dapat memakai pola yang sama.

