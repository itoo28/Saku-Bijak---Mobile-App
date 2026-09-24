---
name: github-push-id
description: >-
  Gunakan skill ini saat pengguna meminta untuk melakukan commit dan push perubahan kode ke GitHub dengan pesan commit berbahasa Indonesia yang rapi, informatif, dan mengikuti standar Conventional Commits.
---

# Skill: Push ke GitHub dengan Commit Bahasa Indonesia

Skill ini menyediakan panduan operasional langkah-demi-langkah bagi agen untuk memeriksa perubahan kode, menjalankan validasi, menyusun pesan commit dalam Bahasa Indonesia yang baku dan deskriptif, serta melakukan push ke repositori GitHub.

---

## 1. Aturan Format Commit Bahasa Indonesia

Gunakan format terstruktur berbasis **Conventional Commits** dengan deskripsi dalam Bahasa Indonesia:

`<tipe>(<cakupan>): <deskripsi singkat imperative>`

### Tipe Commit yang Didukung:
* **`fitur`** (atau `feat`): Penambahan fitur atau fungsi baru pada aplikasi.
  * *Contoh:* `fitur(transaksi): tambah opsi edit riwayat transaksi`
* **`perbaikan`** (atau `fix`): Perbaikan bug atau penanganan galat (*error*).
  * *Contoh:* `perbaikan(saldo): atasi inkonsistensi saldo saat edit transfer`
* **`refaktor`** (atau `refactor`): Restrukturisasi kode tanpa mengubah fungsionalitas eksternal.
  * *Contoh:* `refaktor(provider): pisahkan total locked balance ke top-level provider`
* **`uji`** (atau `test`): Penambahan atau modifikasi unit test dan integration test.
  * *Contoh:* `uji(repo): tambah skenario validasi penarikan tabungan impian`
* **`dokumen`** (atau `docs`): Pembaruan dokumentasi, PRD, atau README.
  * *Contoh:* `dokumen(prd): perbarui spesifikasi isolasi saldo terkunci`
* **`gaya`** (atau `style`): Format kode, spasi, koma, perbaikan linter tanpa perubahan logika.
  * *Contoh:* `gaya(tema): sesuaikan kontras warna kartu dashboard`
* **`koreksi`** (atau `chore`): Pembaruan dependensi, konfigurasi build, atau skrip.
  * *Contoh:* `koreksi(deps): sinkronisasi paket flutter pubspec`

### Prinsip Pesan Commit:
1. Gunakan kalimat aktif dan ringkas (maksimal 72 karakter pada baris pertama).
2. Tuliskan deskripsi yang menjelaskan **apa** dan **mengapa**, bukan hanya mengulang nama file.
3. Jika ada perubahan signifikan, tambahkan rincian poin di bawah baris judul menggunakan `- `.

---

## 2. Prosedur Operasional Eksekusi (Langkah-demi-Langkah)

Saat skill ini diaktifkan, jalankan langkah-langkah berikut secara berurutan:

### Langkah 1: Periksa Status dan Perubahan Git
Jalankan perintah untuk melihat berkas yang dimodifikasi, ditambah, atau dihapus:
```powershell
git status
```
Periksa detail perubahan:
```powershell
git diff --stat
```

### Langkah 2: Jalankan Pengujian (Quality Gate)
Sebelum melakukan staging atau commit, pastikan kode tidak memecahkan fungsi yang ada:
```powershell
flutter test
```
*Jika ada test yang gagal, perbaiki terlebih dahulu sebelum melanjutkan ke langkah commit.*

### Langkah 3: Tambahkan Perubahan ke Staging (Staging Area)
Tambahkan file yang relevan ke git staging:
```powershell
git add .
```
Atau tambahkan file secara spesifik jika tidak semua file ingin di-commit bersamaan.

### Langkah 4: Susun dan Lakukan Commit
Buat pesan commit dalam Bahasa Indonesia sesuai kaidah bagian 1.
Contoh commit satu baris:
```powershell
git commit -m "perbaikan(saldo): perbaiki kalkulasi saldo saat edit transaksi dan transfer"
```

Contoh commit dengan rincian penjelasan (multi-line):
```powershell
git commit -m "fitur(transaksi): implementasi edit transaksi dan perbaikan integritas saldo" -m "- Sinkronisasi saldo saat pembaruan nominal transaksi dan transfer`n- Tambah validasi penarikan saldo terkunci pada goal`n- Perbarui dashboard dan recent transaction list"
```

*(Opsional: Anda juga dapat menggunakan skrip otomatis siap pakai di [push_indo.ps1](./scripts/push_indo.ps1) yang menggabungkan verifikasi `flutter test`, `git add`, `git commit`, dan `git push` dalam satu perintah).*
```powershell
.\.agents\skills\github-push-id\scripts\push_indo.ps1 -Pesan "perbaiki alur saldo dan edit transaksi" -Tipe "perbaikan" -Cakupan "keuangan"
```

### Langkah 5: Identifikasi Branch dan Remote
Pastikan nama branch aktif dan remote target sudah benar:
```powershell
git branch --show-current
git remote -v
```

### Langkah 6: Push ke Repositori GitHub
Kirim commit ke repositori remote:
```powershell
git push origin <nama-branch>
```
*Catatan: Jika branch belum memiliki upstream tracker, gunakan:*
```powershell
git push -u origin <nama-branch>
```

### Langkah 7: Konfirmasi Akhir
Verifikasi bahwa branch lokal sudah sinkron dengan remote dan working tree bersih:
```powershell
git status
```
Tampilkan ringkasan commit yang baru saja di-push kepada pengguna.

---

## 3. Penanganan Masalah (Troubleshooting)

1. **Remote Rejected / Non-fast-forward:**
   * Lakukan `git pull --rebase origin <branch>` sebelum push jika ada perubahan baru di remote.
2. **Untracked Secret / Sensitive Files:**
   * Pastikan berkas sensitif (seperti `.env`, keystore, file credential pribadi) sudah ada di `.gitignore` sebelum `git add .`.
3. **Detached HEAD State:**
   * Jika berada di detached HEAD, buat branch terlebih dahulu: `git checkout -b <nama-branch>`.
