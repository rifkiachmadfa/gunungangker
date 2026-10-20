# BUGS

## Open
### BUG-001 — Ranting tidak terlihat dan tombol tidak tersembunyi untuk pemain yang sudah lama menunggu
- Severity: Tinggi (progres CP1 pemain multiplayer terblokir)
- Sistem terdampak: Resource (server `ensureAsset`, client `ResourceRenderer.bindSet`)
- Reproduksi: 2+ pemain bergabung; tunggu > ~60 dtk tanpa ada yang menerima quest; salah satu pemain bicara ke NPC dan menerima quest; pemain lain lalu menerima quest.
- Expected: tiap pemain melihat 10 ranting miliknya dan tombol hanya di titik miliknya.
- Actual (diduga dari kode, BELUM direproduksi di Studio): pemain yang menunggu lebih lama dari waktu tunggu tidak melihat ranting dan semua tombol di 20 titik tetap terlihat (server tetap menolak titik tidak aktif).
- Root cause: template (`ReplicatedStorage.QuestAssets.<AssetName>`) baru dibuat server saat `Activate` pertama; client menunggu template maksimal `ASSET_WAIT_TIMEOUT` (30 dtk untuk folder + 30 dtk untuk template) lalu `bindSet` `return`, sehingga listener attribute dan sinkron prompt tidak pernah terpasang untuk sisa sesi.
- Perbaikan: server menyalin template di `ResourceService.Start()`; client tidak lagi `return` bila template belum ada (listener dan sinkron prompt tetap terpasang, template dicari ulang dan digambar begitu tiba).
- Status: perbaikan ditulis; lulus uji mock (client lama gagal 7 dari 8 skenario, baru lulus 8 dari 8); BELUM diverifikasi di Studio dan multiplayer nyata.

## Resolved
(none)

Format entri: BUG-001 — judul; Severity; Sistem terdampak; Reproduksi; Expected; Actual; Root cause; Status.
