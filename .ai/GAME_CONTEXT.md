# GAME CONTEXT — Gunung Angker

Sumber: GDD *Ekspedisi Pendakian Horor* v1.0 + instruksi terbaru pengguna (2026-10-18).
Penyimpangan dari GDD dicatat di `DECISIONS.md`. Item bertanda **[OPEN]** belum diputuskan, lihat bagian 16.

## 1. Ringkasan
- Judul: Gunung Angker
- Genre: Horror Expedition / Survival / Adventure / Obby
- Pemain: 1–5 (multiplayer)
- Tema: gunung mistis Indonesia, 5 checkpoint
- Pengalaman inti: ketegangan, survival, "terus naik tapi gunung semakin tidak masuk akal"
- Game ini BUKAN: sekadar "cari item → NPC → lanjut"

## 2. Core Loop
Lobby (pilih 1–5 pemain, cooldown 10 detik, teleport) → Main place, spawn basecamp → Cutscene → CP1 → CP2 → CP3 → CP4 (opsional) → CP5 → Summit Gate → Summit +1 → run selesai.

## 3. Pillars
1. Survival: hunger dan thirst harus dijaga.
2. Quest per checkpoint dengan gate yang mengunci progres.
3. Horor tak terprediksi: halusinasi, jumpscare, ghost chase.
4. Server authoritative, multiplayer aman dari exploit.

## 4. State Global (Run)
Tidak ada state global tunggal. Progres adalah **per pemain** (lihat bagian 6). Shared: environment, NPC, cuaca, ghost event tertentu.
Alur tingkat tinggi: LOBBY → CUTSCENE → PLAYING → SUMMIT_COMPLETE. Owner: ProgressionService (server). Lobby dan cutscene dikerjakan terakhir.

## 5. Player State
| State | Arti | Interaksi | Bergerak |
|---|---|---|---|
| NORMAL | Bermain | Ya | Ya |
| KNOCKED | HP/hunger habis, jatuh | Tidak | Tidak |
| MINIGAME | Minigame obor | Terbatas | Tidak |
| DIVING | Di bawah air (oksigen turun) | Ya (ikan) | Ya |
| CUTSCENE | Cutscene berjalan | Tidak | Tidak |

Knock dan pemulihan: **[OPEN]** (Q1).

## 6. Progression Model
- **Personal:** hunger, thirst, inventory, quest progress, torch, ikan, resource collection, jumpscare, CurrentCheckpoint.
- **Shared:** environment, NPC, main checkpoint, cuaca, ghost event tertentu.
- Resource: posisi spawn dikontrol server, state ambil/hilang **personal** (satu pemain tidak menghabiskan resource pemain lain).
- Server menyimpan `CurrentCheckpoint` per pemain. Mati di CP3 → respawn di CP3.
- Persisten: `SummitCount` (profil, leaderboard, title). Save system dikerjakan di fase stabilisasi.

## 7. Items
| Item | Asal | Dipakai untuk | Scope | Duplikasi |
|---|---|---|---|---|
| Ranting | Spawn CP1/CP2 | Quest CP1/CP2/CP3 | Personal | Tidak |
| Batu | Spawn CP2 | Quest CP2/CP3 (maks 1) | Personal | Tidak |
| Makanan (Nasi Bungkus) | Ibu Warung | +40 Hunger | Personal | Tidak |
| Air (Water Bottle) | Ibu Warung | +40 Thirst | Personal | Tidak |
| Obor | Crafting CP3 | Menembus gelap CP3→CP4, fuel 120 detik | Personal | Tidak |
| Ikan | Diving CP4 | Quest opsional CP4 (semua jenis = "Fish") | Personal | Tidak |
| Jimat | Penjaga Danau | Damage hantu lebih kecil, lebih sulit knock | Personal | Tidak |
| Sesajen | Spawn CP5 | Summit Gate (butuh 5) | Personal | Tidak |

Backpack: slot, ikon, jumlah, tombol Equip/Use/Drop. Obor bisa di-equip lalu dinyalakan.

## 8. Spesifikasi Checkpoint

### Resource (SpawnPoint Pool + Active Limit + Respawn)
| Resource | Spawn Point | Aktif | Respawn | Catatan |
|---|---|---|---|---|
| Ranting CP1 | 20 | 10 | 3 dtk | Requirement 10 |
| Ranting CP2 | 10 | 5 | 3 dtk | Requirement 1 |
| Batu CP2 | StoneSpawnPoint | — | — | Maks 1 di backpack |
| Ikan CP4 | 15 | 5–8 | — | Bergerak acak |
| Sesajen CP5 | 10 | 5 | 3 dtk | Requirement 5 |

Alur: shuffle spawn point → pilih N → spawn. Resource diambil → hilang → tunggu 3 detik → pilih spawn point yang belum terpakai → spawn. Jumlah aktif selalu tetap.

### Survival
- **Hunger:** mulai **50**, −1 per **5 detik** (instruksi terbaru, lihat DEC-006; angka diatur di `SurvivalConfig`; GDD awal: 100 dan −1/30 dtk). >50 normal; 25–50 efek ringan; 1–24 halusinasi naik; 0 → **knock** (instruksi terbaru; GDD hanya menurunkan speed).
- **Thirst:** mulai **50**, −1 per **5 detik** (instruksi terbaru, lihat DEC-006; GDD awal: 100 dan −1/20 dtk). 0 → **jalan lambat**, kamera goyang, napas, blur, halusinasi.
- Halusinasi level 1–4: bayangan/suara → NPC/player palsu → hantu/fake item/fake checkpoint → jumpscare/distorsi.

### CP1 — Warung
`CP1_SEARCH_BRANCH → CP1_COMPLETE`
- Ibu Warung: "Kalau mau minum dan makan, bantu ibu kumpulkan ranting dulu."
- Serahkan 10 ranting → shop terbuka (Water Bottle +40 Thirst, Nasi Bungkus +40 Hunger). Sebelum selesai, shop terkunci. Harga/currency: **[OPEN]** (Q2).
- Selesai: "Jalan ke atas sudah terbuka", gate CP1 terbuka.

### CP2 — Hutan Bambu
`CP2_SEARCH_BRANCH → CP2_SEARCH_STONE → CP2_COMPLETE`
- Penjaga Hutan minta 1 ranting + 1 batu. Interaksi batu kedua nonaktif jika Stone = 1.
- Selesai → gate CP2 terbuka (akses CP3).

### CP3 — Hutan Gelap
`CP3_CRAFT_TORCH → CP3_COMPLETE`
- Penjaga Api minta 1 batu + 1 ranting; pemain berinteraksi dengan Crafting Station.
- **Minigame:** tekan tombol saat indikator di zona PERFECT, target 3× Perfect. Sukses: Ranting −1, Batu −1, Torch +1. Miss 1–2 tidak menghilangkan item; gagal total → ulangi.
- **Torch:** fuel 120 detik, timer jalan saat Torch ON.
- **Jalur CP3→CP4:** torch harus ON. OFF >3 detik → jumpscare. Fuel 0 → torch mati, jumpscare, pemain kembali ke CP3, torch dihapus, requirement 1 ranting + 1 batu kembali; craft ulang.

### CP4 — Danau (OPSIONAL)
`CP4_OPTIONAL → CP4_CATCH_FISH → CP4_COMPLETE` (boleh dilewati)
- **Diving:** Oxygen 100, −5 per detik. Oxygen 0 → damage atau dipaksa naik ke permukaan.
- **Fishing:** dive → cari ikan → interact → masuk backpack (biasa, merah, hitam, bercahaya, semua = "Fish").
- Penjaga Danau minta 3 ikan → beri **Jimat**.
- **Jimat (instruksi terbaru):** damage hantu CP5 lebih kecil dan lebih sulit knock. Tanpa jimat damage lebih besar dan lebih mudah knock. Angka damage: **[OPEN]** (Q3). Efek WalkSpeed +4 dari GDD **tidak dipakai** (DEC-001).
- Tidak mengerjakan quest ini tidak menghalangi progres. Gate CP4 tidak mengunci.

### CP5 — Tebing & Jurang
`CP5_COLLECT_OFFERING → CP5_COMPLETE → SUMMIT_COMPLETE`
- **Obby:** Wind Force, Slippery Ground, jalan sempit/balancing. Jatuh → respawn di checkpoint terakhir.
- **Ghost chase:** masuk area tertentu memulai chase; pilih acak 1–2 tipe (Pocong, Kuntilanak, Bayangan hitam, Hantu pendaki). Terlalu lama berhenti → hantu mendekat. Hantu memberi damage; knock dan respawn: **[OPEN]** (Q1).
- **Sesajen:** kumpulkan 5 sambil berlari.
- **Summit Gate:** serahkan 5 sesajen → Ghost AI berhenti → gerbang terbuka → **SummitCount +1**.

### Gate / Invisible Wall
Satu wall per checkpoint: `CanCollide = true` sampai quest checkpoint itu selesai, lalu `false`. CP4 tidak punya blocking. Mekanisme per-pemain di multiplayer: lihat DEC-003 (usulan, menunggu persetujuan).

### Kegagalan: Failure → Jumpscare → Respawn → Penalty (bukan game over)
| Kegagalan | Konsekuensi |
|---|---|
| Jatuh dari jurang | Respawn di CP5 |
| Oksigen habis | Kembali ke permukaan |
| Torch habis | Kembali ke CP3, torch dihapus |
| Ditangkap/damage hantu | Lihat Q1 |

## 9. Interaksi
Pola: dekati objek → prompt → tekan E → server validasi jarak, ketersediaan, requirement, cooldown → reward/aksi.
| Prompt | Objek | Validasi server |
|---|---|---|
| Ambil | Ranting/Batu/Sesajen | Jarak, resource aktif untuk pemain itu, batas (batu ≤1), cooldown |
| Serahkan | NPC quest | Jarak, state quest, item cukup |
| Beli/Ambil | Ibu Warung | CP1_COMPLETE, harga (Q2) |
| Craft | Crafting Station | CP3 state, 1 ranting + 1 batu, hasil minigame dari server |
| Tangkap | Ikan | Jarak, status DIVING, ikan masih ada |
| Serahkan sesajen | Summit Gate | ≥5 sesajen, CP5 state |

## 10. UI
- HUD: HP, Hunger, Thirst, Checkpoint, tombol Backpack, quest objective, interaction prompt, notifikasi.
- Kontekstual: torch timer (CP3), Oxygen % (CP4), "Chase Active" + Sesajen n/5 (CP5), ghost warning.
- Efek horor: vignette, blur, distorsi, jumpscare overlay, static, red flash, black screen.
- Sumber data: state dari server.

## 11. Workspace Structure
**Acuan GDD §12.3 (BELUM terverifikasi di Studio):**
```
Workspace
├── Checkpoints (CP1–CP5)
├── ResourceSpawns (CP1_Branches, CP2_Branches, CP2_Stones, CP4_Fish, CP5_Offerings)
├── NPC (WarungMother, ForestGuard, FireKeeper, LakeKeeper, SummitKeeper)
├── Horror (GhostSpawns, JumpscareTriggers, HallucinationTriggers)
└── Summit (SummitGate, OfferingDeposit, SummitTrigger)
```
Nama Part/trigger acuan GDD §12.2 (contoh: CP1_Spawn, CP1_NPC, CP1_Gate, BranchSpawnPoint, CraftingStation, TorchRequiredZone, TorchFailZone, TorchTimerZone, DiveZone, FishSpawnPoint, WindZone, SlipperyZone, FallZone, OfferingSpawnPoint, SummitGate). Wajib diaudit di Studio sebelum dipakai script.

## 12. Tags & Attributes
Belum ada. Diisi dari audit Studio (Phase 0, bagian Workspace).

## 13. Remotes
Belum ada. Didefinisikan di Phase 1 dan wajib dicatat di sini. Prinsip: client mengirim intent, server memvalidasi dan membalas state. Tiap Remote wajib rate-limit.

## 14. Ending
- Menang: serahkan 5 sesajen di Summit Gate → Summit +1 (SummitCount di profil).
- Kalah: tidak ada game over; pola failure → respawn → penalty.
- Meta: leaderboard, badge, title (1 Summit = Pendaki Pemula, 5 = Penjelajah Gunung, 10 = Pendaki Mistis).

## 15. Di luar scope (JANGAN dibangun)
- Membangun ulang Workspace, environment, model, NPC, animasi.
- Lobby, pilih jumlah pemain, cooldown, teleport (ditunda sampai akhir).
- Cutscene Moon Animator 2 (ditunda).
- Kosmetik tambahan (skin, trail, emote) sebelum core selesai.
- Fitur di luar GDD tanpa persetujuan.

## 16. Open Questions
- **Q1 Knock:** hunger 0 → knock. Bagaimana pemulihannya (revive teman, makan, timer, auto respawn)? Solo player tidak punya teman. Apakah HP 0 oleh hantu juga knock lalu respawn di checkpoint?
- **Q2 Shop CP1:** gratis setelah quest, atau pakai currency/harga? GDD hanya bilang "membeli".
- **Q3 Damage hantu:** berapa damage dengan jimat vs tanpa jimat, dan ambang knock? Belum ada angka di GDD.
- **Q4 Konteks "HP bar bertambah":** instruksi menyebut makanan menambah "hp bar dan thirsty bar". Diasumsikan hunger bar dan thirst bar (GDD: Nasi +40 Hunger, Air +40 Thirst). Konfirmasi.
- **Q5 Solo/multiplayer:** apakah jumlah pemain terpilih memengaruhi gameplay (jumlah resource, kesulitan hantu)? GDD tidak menyebut.
