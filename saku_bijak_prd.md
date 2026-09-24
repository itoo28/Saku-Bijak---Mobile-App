# Saku Bijak - Product Requirements Document (PRD)

### Metadata Dokumen
* **Versi Dokumentasi:** 2.0 (Offline-First, No-Account Edition)
* **Perubahan dari v1.0:** Aplikasi diubah menjadi sepenuhnya offline tanpa kebutuhan akun/login — seluruh dependensi Firebase (Auth, Cloud Sync, Analytics, Cloud Messaging, Storage) dihapus dan digantikan mekanisme lokal (local notification, local backup/restore manual). Ditambahkan skema relasi entitas eksplisit, keamanan lokal (app lock), kebijakan mata uang, soft delete, serta penanganan edge case finansial.
* **Target Engine:** AI Agent Engine (code generation)

---

## 1. Product Overview

### Product Name
Saku Bijak

### Product Vision
Saku Bijak adalah aplikasi mobile *personal finance* modern yang **sepenuhnya berjalan secara offline di perangkat pengguna**, tanpa memerlukan pembuatan akun atau koneksi internet apa pun. Aplikasi membantu pengguna mengelola seluruh aset keuangan mereka dalam satu tempat, melacak pemasukan dan pengeluaran, mengatur anggaran, serta mencapai tujuan finansial melalui sistem tabungan berbasis target (*Goal Saving*) dengan mekanisme dana terkunci (*Locked Saving*) — seluruhnya tersimpan secara privat di perangkat pengguna.

Filosofi produk: **data finansial pengguna adalah milik pengguna sepenuhnya**, tidak ada server eksternal yang menyimpan atau memproses data tersebut, sehingga privasi terjamin secara desain (*privacy by design*).

---

## 2. Objectives

### Business Goals
* Membantu pengguna memahami kondisi keuangan secara real-time tanpa mengorbankan privasi.
* Membantu pengguna mengontrol pengeluaran.
* Membantu pengguna mencapai target finansial.
* Menjadi aplikasi keuangan yang sederhana, cepat dibuka (tanpa proses login), namun *powerful*.
* Memberikan pengalaman layaknya aplikasi fintech premium tanpa risiko kebocoran data ke pihak ketiga.

### User Goals
* Langsung menggunakan aplikasi tanpa proses pendaftaran/login.
* Mengetahui total aset yang dimiliki.
* Melihat uang yang tersimpan di berbagai rekening dan e-wallet (dicatat manual, bukan terhubung langsung ke bank).
* Mencatat pemasukan dan pengeluaran dengan mudah.
* Menyusun anggaran bulanan.
* Menabung untuk barang atau tujuan tertentu.
* Mendapatkan *insight* keuangan secara otomatis, dihitung sepenuhnya di perangkat.
* Memastikan data tidak hilang melalui mekanisme backup manual milik sendiri.

---

## 3. Target Users

### Primary Users
* Mahasiswa
* Fresh Graduate
* Karyawan
* Freelancer
* UMKM skala kecil

### User Persona
* **Mahasiswa**: Ingin mengatur uang saku dan menabung untuk kebutuhan kuliah atau gadget, tanpa perlu daftar akun.
* **Karyawan**: Ingin melacak pengeluaran bulanan dan menabung untuk target besar, dengan data privat di HP sendiri.
* **Freelancer**: Memiliki banyak sumber pemasukan dan ingin mengelolanya dalam satu aplikasi tanpa khawatir data tersinkron ke cloud pihak ketiga.

---

## 4. Prinsip Arsitektur: Offline-First & No-Account

> **Aturan Mutlak:** Aplikasi tidak boleh memiliki dependensi jaringan untuk fungsi inti apa pun (mencatat transaksi, melihat dashboard, mengelola goal, dsb). Tidak ada layar login/registrasi. Saat pertama kali dibuka, pengguna langsung diarahkan ke *onboarding* singkat (opsional, dapat dilewati) lalu langsung ke Dashboard dengan data kosong.

* **Tidak ada akun, tidak ada server.** Seluruh data tersimpan di database lokal perangkat.
* **Multi-device tidak didukung secara otomatis.** Karena tidak ada akun/cloud sync, data pengguna terikat pada satu perangkat. Perpindahan data antar perangkat dilakukan melalui fitur **Backup & Restore manual** (lihat Bagian 13).
* **Tidak ada Firebase.** Seluruh fitur yang sebelumnya bergantung pada Firebase (Auth, Firestore sync, Cloud Messaging, Analytics, Storage) dihapus dari scope dan digantikan alternatif lokal.
* **Uninstall = kehilangan data**, kecuali pengguna melakukan backup manual. Hal ini wajib dikomunikasikan secara jelas di UI (misalnya banner pengingat backup berkala).

---

## 5. Core Features

### 1. Multi Account Management
* **Description**: Pengguna dapat mencatat seluruh sumber dana yang dimiliki secara manual (bukan terhubung langsung ke API bank).
* **Supported Account Types**: Cash, Bank Account, E-Wallet.
* **Examples**:
  * *Cash*: Tunai
  * *Bank Account*: BCA, BRI, Mandiri, SeaBank
  * *E-Wallet*: DANA, OVO, GoPay, ShopeePay
* **Account Fields**: `id`, `name`, `accountType`, `balance` (saldo total = available + locked), `currency` (default `IDR`, fixed untuk v1), `icon`, `colorTag`, `isArchived`, `createdAt`, `updatedAt`, `deletedAt`
* **Functional Requirements**:
  * Create account
  * Edit account
  * Archive/soft-delete account (tidak hapus permanen jika masih punya riwayat transaksi)
  * Transfer balance
  * View account history (daftar transaksi per akun)
* **Validasi**: Saldo awal akun tidak boleh negatif saat pembuatan; akun dengan riwayat transaksi tidak dapat dihapus permanen, hanya diarsipkan.

### 2. Income Tracking
* **Description**: Mencatat seluruh pemasukan.
* **Fields**: `id`, `amount` (integer, dalam Rupiah penuh — lihat Bagian 11), `categoryId`, `accountId`, `date`, `note`, `createdAt`, `updatedAt`, `deletedAt`
* **Default Categories**: Salary, Bonus, Freelance, Gift, Other
* **Custom Categories**: User dapat membuat kategori sendiri dengan `name`, `icon`, `color`, `type` (income/expense — kategori income dan expense terpisah dan tidak bisa saling dipakai silang).

### 3. Expense Tracking
* **Description**: Mencatat seluruh pengeluaran.
* **Fields**: `id`, `amount`, `categoryId`, `accountId`, `date`, `note`, `createdAt`, `updatedAt`, `deletedAt`
* **Rules**:
  * Pengeluaran hanya boleh menggunakan saldo yang tersedia (*available balance* = `balance - lockedBalance`).
  * Tidak boleh menggunakan saldo yang sudah dialokasikan ke *goal saving*.
  * Jika nominal pengeluaran melebihi *available balance*, sistem **menolak transaksi secara default** dan menampilkan dialog konfirmasi eksplisit "Saldo tidak mencukupi — tetap catat dan buat saldo negatif?" agar pengguna sadar sepenuhnya (opsional diizinkan, tapi default tertutup).
* **Split Transaction (opsional, v1 sederhana)**: Satu transaksi expense hanya boleh memiliki satu kategori di v1. Dukungan split multi-kategori dalam satu transaksi dipindahkan ke roadmap Phase 2 agar model data v1 tetap sederhana dan stabil.

### 4. Transfer Between Accounts
* **Description**: Transfer saldo antar akun.
* **Example**: BCA → DANA (Rp500.000)
* **Fields**: `id`, `fromAccountId`, `toAccountId`, `amount`, `date`, `note`, `createdAt`
* **Rules**: Bukan pemasukan, bukan pengeluaran, hanya perpindahan saldo. Dicatat sebagai satu entitas `Transfer` (bukan dua entry terpisah) agar mudah ditampilkan sebagai satu baris riwayat dan mudah dibatalkan/diedit sebagai satu kesatuan.
* **Validasi**: `fromAccountId` ≠ `toAccountId`; saldo *available* di akun sumber harus mencukupi.

### 5. Goal Saving System
* **Description**: Pengguna dapat membuat target tabungan.
* **Goal Fields**: `id`, `goalName`, `targetAmount`, `currentAmount` (kolom agregat, dihitung ulang dari `GoalTransaction` — lihat Bagian 6), `deadline` (nullable), `description`, `priority`, `image`, `status` (`active`, `completed`, `overdue`, `archived`), `createdAt`, `deletedAt`
* **Example**: Laptop ASUS TUF (Target: Rp12.000.000, Progress: 25%)
* **Status Otomatis**:
  * `completed` saat `currentAmount` ≥ `targetAmount`.
  * `overdue` saat `deadline` terlewati dan goal belum `completed` (goal tetap aktif dan bisa terus menerima deposit, status ini murni informatif untuk insight, bukan penghalang).
* **Penghapusan Goal**: Goal dengan `currentAmount` > 0 tidak dapat dihapus langsung. Pengguna wajib melakukan **Goal Withdrawal penuh** terlebih dahulu (dana dikembalikan ke akun pilihan) sebelum goal dapat diarsipkan/dihapus.

### 6. Locked Saving System
* **Description**: Dana yang dimasukkan ke dalam *goal saving* akan dikunci di tingkat akun.
* **Entitas Pendukung — `GoalTransaction`**: Setiap deposit/withdrawal goal dicatat sebagai baris tersendiri (`id`, `goalId`, `accountId`, `type` [`deposit`/`withdrawal`], `amount`, `date`, `createdAt`), bukan hanya mengubah angka `currentAmount` secara langsung. Ini memastikan riwayat goal dapat diaudit dan `currentAmount` selalu dapat dihitung ulang (*derived*) dari penjumlahan `GoalTransaction`, mencegah data tidak konsisten.
* **Example**:
  * Saldo BCA: Rp5.000.000
  * Dana Goal: Rp2.000.000
  * Saldo Tersedia: Rp3.000.000
  * Saldo Terkunci: Rp2.000.000
* **Rules**:
  * Dana terkunci tidak dapat digunakan untuk transaksi expense atau transfer biasa.
  * Dana terkunci hanya dapat dipindahkan melalui fitur *Goal Saving* (deposit/withdrawal).
  * `lockedBalance` suatu akun = jumlah seluruh `currentAmount` goal aktif yang sumber dananya berasal dari akun tersebut.

### 7. Goal Deposit
* **Description**: Menambahkan dana ke goal.
* **Flow**: Pilih Goal → Pilih Account → Input Nominal → Konfirmasi
* **System Action**: Buat `GoalTransaction` tipe `deposit` → kurangi *available balance* akun sumber, tambah *locked balance* akun sumber, `currentAmount` goal bertambah (hasil agregasi).
* **Validasi**: Nominal tidak boleh melebihi *available balance* akun sumber.

### 8. Goal Withdrawal
* **Description**: Menarik dana dari goal.
* **Flow**: Pilih Goal → Input Nominal → Pilih Tujuan Account → Konfirmasi
* **System Action**: Buat `GoalTransaction` tipe `withdrawal` → kurangi *locked balance*, tambah *available balance* akun tujuan.
* **Validasi**: Nominal tidak boleh melebihi `currentAmount` goal saat ini.

### 9. Budget Management
* **Description**: Membuat batas pengeluaran bulanan.
* **Fields**: `id`, `categoryId`, `amountLimit`, `period` (bulanan, mengikuti kalender bulan berjalan), `createdAt`
* **Example**: Makanan: Rp500.000, Transportasi: Rp300.000, Hiburan: Rp250.000
* **Features**: Budget Progress, Remaining Budget, Overspending Warning.
* **Catatan**: Satu kategori expense hanya boleh memiliki satu budget aktif per periode bulan berjalan untuk menghindari ambiguitas perhitungan.

### 10. Financial Insights
* **Description**: Insight otomatis berdasarkan perilaku pengguna, dihitung sepenuhnya secara lokal dari data di perangkat (tidak ada pemrosesan di server).
* **Examples**:
  * Pengeluaran naik 15% dibanding bulan lalu.
  * Kategori terbesar bulan ini adalah Makanan.
  * Tabungan meningkat 10%.

### 11. Financial Health Score
* **Description**: Menampilkan skor kesehatan finansial.
* **Scale**: 0 - 100
* **Calculation Factors**: Konsistensi menabung, pengeluaran bulanan, kepatuhan budget, *goal completion rate*. Seluruh perhitungan dilakukan on-device.

### 12. Goal Achievement Prediction
* **Description**: Prediksi waktu target tercapai, dihitung dari rata-rata kecepatan deposit historis (`GoalTransaction` tipe `deposit`) goal terkait.
* **Example**: Target Rp10.000.000, Saat ini Rp4.000.000, Rata-rata menabung Rp500.000/bulan. Prediksi: 12 bulan lagi.

### 13. Backup & Restore (menggantikan Cloud Sync)
* **Description**: Karena aplikasi sepenuhnya offline tanpa akun, pengguna bertanggung jawab penuh atas keamanan datanya sendiri melalui mekanisme backup manual.
* **Fitur**:
  * **Export Backup**: Mengekspor seluruh database lokal (akun, transaksi, goal, budget, kategori) menjadi satu file terenkripsi (`.sbjk` atau JSON terenkripsi dengan passphrase milik pengguna) yang dapat disimpan pengguna ke penyimpanan perangkat atau dibagikan ke layanan penyimpanan pilihan mereka sendiri (Google Drive, email, dsb) melalui share sheet sistem operasi — aplikasi tidak mengunggah apa pun secara otomatis.
  * **Import Restore**: Memuat kembali file backup ke perangkat (perangkat yang sama setelah reinstall, atau perangkat baru).
  * **Reminder Backup**: Notifikasi lokal periodik (misal setiap 30 hari atau setelah N transaksi) mengingatkan pengguna untuk melakukan backup, dapat dimatikan di pengaturan.

### 14. Savings Challenge
* **Examples**: Save Rp10.000/day, Save Rp100.000/week, No Coffee Challenge, Monthly Saving Challenge.

### 15. Achievement System
* **Examples**: First Goal Created, First Goal Completed, Saved Rp1.000.000, Saved Rp10.000.000, Consistent Saver.

---

## 6. Skema Relasi Entitas (Ringkasan)

```
Account (1) ───< Income
Account (1) ───< Expense
Account (1) ───< Transfer (sebagai fromAccount)
Account (1) ───< Transfer (sebagai toAccount)
Account (1) ───< GoalTransaction

Category (1) ───< Income
Category (1) ───< Expense
Category (1) ───< Budget

Goal (1) ───< GoalTransaction   // currentAmount = SUM(deposit) - SUM(withdrawal)
```

* Seluruh foreign key (`accountId`, `categoryId`, `goalId`) wajib divalidasi ada dan tidak dalam keadaan `deletedAt` terisi sebelum transaksi baru dibuat.
* Entitas finansial inti (`Income`, `Expense`, `Transfer`, `GoalTransaction`) **tidak boleh dihapus secara hard delete**. Penghapusan dilakukan melalui `deletedAt` (soft delete) agar riwayat dan perhitungan agregat (saldo, insight, health score) tetap konsisten dan dapat diaudit/di-undo.

---

## 7. Dashboard

### Summary Cards
* Total Assets
* Available Balance
* Locked Savings
* Monthly Income
* Monthly Expense
* Financial Score

### Quick Actions
* Add Income
* Add Expense
* Transfer
* Add Goal
* Add Budget

### Active Goals Section
Menampilkan data berikut:
* Goal Image
* Goal Name
* Progress
* Remaining Amount
* Estimated Completion

### Recent Transactions
* Menampilkan 10 transaksi terakhir (gabungan Income, Expense, Transfer, diurutkan berdasarkan `date` terbaru).

### Backup Reminder Banner
* Banner non-intrusif yang muncul jika belum ada backup dalam X hari terakhir, dengan tombol pintas ke fitur Export Backup.

---

## 8. Reports & Analytics

### Charts
* Income vs Expense
* Monthly Trend
* Category Breakdown
* Goal Progress
* Budget Utilization

### Notifications (Local Notification, bukan Push/FCM)
* Budget hampir habis.
* Pengingat menabung.
* Target hampir tercapai.
* Ringkasan bulanan.
* Goal berhasil dicapai.
* Pengingat backup data.
* **Catatan Teknis**: Seluruh notifikasi dijadwalkan dan dihitung secara lokal menggunakan local notification scheduler (misalnya `flutter_local_notifications`) berdasarkan data di Isar, dijalankan via background task periodik di perangkat — tidak ada server yang mengirim push notification.

---

## 9. UI/UX Requirements

### Design Style
Modern Fintech, Minimalist, Premium, Clean, Professional, Friendly, Interactive.

### UI Principles
* Large whitespace
* Rounded corners
* Soft shadows
* Smooth animations
* Micro interactions
* Glassmorphism accents
* Gradient highlights
* Modern typography
* Responsive layout

### User Experience Priorities
* Fast interaction — aplikasi terbuka langsung ke Dashboard tanpa layar login.
* Minimal taps
* Intuitive navigation
* Clear financial overview
* Delightful animations

### Animation Guidelines
* 60 FPS target
* Smooth page transition
* Animated charts
* Animated progress indicators
* Interactive cards

### Theme Support
* **Light Mode**: Default modern fintech theme.
* **Dark Mode**: Premium dark appearance.
* *Note: Kedua tema harus didukung sejak awal, tersimpan sebagai preferensi lokal (tidak perlu akun untuk sinkronisasi preferensi).*

### Navigation Structure
Home | Accounts | Transactions | Goals | Profile
*(Menggunakan Material 3 Bottom Navigation Bar)*
*Catatan: Tab "Profile" tidak berisi info akun/login, melainkan Pengaturan Aplikasi (tema, keamanan, backup/restore, mata uang, tentang aplikasi).*

### Onboarding (Pengganti Layar Login)
* 2-3 layar onboarding singkat yang menjelaskan value proposition aplikasi (privasi & offline-first sebagai diferensiator utama), dapat dilewati (*skip*), muncul hanya sekali saat instalasi pertama.

---

## 10. Keamanan & Privasi Lokal

* **App Lock**: Pengguna dapat mengaktifkan kunci aplikasi menggunakan PIN 6 digit dan/atau biometrik (fingerprint/Face ID) melalui `local_auth`. Ini adalah fitur inti (bukan opsional di roadmap) mengingat aplikasi menyimpan data finansial sensitif tanpa lapisan akun.
* **Enkripsi Database Lokal**: Database Isar wajib menggunakan enkripsi (Isar mendukung *encrypted instance*) dengan kunci yang disimpan secara aman menggunakan secure storage perangkat (Keychain di iOS, Keystore di Android via `flutter_secure_storage`).
* **Enkripsi File Backup**: File backup hasil export (Bagian 5.13) wajib dienkripsi dengan passphrase yang ditentukan pengguna saat proses export, agar aman jika file tersebut tersimpan di layanan cloud pihak ketiga pilihan pengguna sendiri.
* **Tidak Ada Pengumpulan Data Pihak Ketiga**: Tidak ada Firebase Analytics atau SDK analitik/iklan pihak ketiga apa pun yang mengirim data pengguna keluar perangkat. Jika di masa depan dibutuhkan analitik produk, wajib bersifat *opt-in* eksplisit dan anonim.
* **Auto-Lock**: Aplikasi otomatis terkunci kembali setelah berada di background selama durasi tertentu (dapat dikonfigurasi pengguna, default 1 menit).

---

## 11. Kebijakan Mata Uang & Format Angka

* Aplikasi v1 **single-currency: Rupiah (IDR)** saja. Field `currency` tetap disertakan di skema (default `"IDR"`) untuk antisipasi multi-currency di roadmap mendatang, namun UI tidak menampilkan pemilihan mata uang di v1.
* Seluruh nominal disimpan sebagai **integer (dalam satuan Rupiah penuh, bukan sen)** untuk menghindari masalah pembulatan floating-point yang umum terjadi pada aplikasi finansial.
* Format tampilan angka menggunakan separator ribuan ala Indonesia (`Rp1.000.000`), dikonfigurasi melalui `intl` package locale `id_ID`.

---

## 12. Technical Requirements

### Framework
Flutter Latest Stable Version

### UI Framework
Material 3

### Architecture
Clean Architecture, Feature First Architecture, Repository Pattern, MVVM

### State Management
Riverpod

### Local Database
Isar Database (encrypted instance — lihat Bagian 10)

### Backend & Cloud Sync
**Tidak ada.** Aplikasi tidak memiliki backend, tidak memerlukan koneksi internet untuk fungsi apa pun, dan tidak terhubung ke layanan cloud pihak ketiga manapun secara default.

### Authentication
**Tidak ada akun/login.** Keamanan akses aplikasi ditangani melalui App Lock lokal (PIN/biometrik) sebagaimana dijelaskan di Bagian 10, bukan melalui sistem otentikasi akun.

### Local Notification
`flutter_local_notifications` untuk seluruh notifikasi (pengingat menabung, peringatan budget, pengingat backup, dsb), dijadwalkan murni di perangkat.

### File Export/Import
`file_picker` dan/atau `share_plus` untuk fitur Backup & Restore manual (Bagian 5.13), tanpa ketergantungan pada Firebase Storage.

### Permissions yang Dibutuhkan
* Notifikasi lokal (Android 13+/iOS memerlukan izin eksplisit).
* Akses penyimpanan/file (untuk export/import backup) — sebatas yang diizinkan scoped storage modern (Android Storage Access Framework / iOS Files app), tanpa permission penyimpanan luas yang tidak perlu.
* Biometrik (opsional, hanya jika pengguna mengaktifkan App Lock biometrik).

---

## 13. Development Guidelines For AI Agent

### Mandatory Requirements
1. Gunakan Flutter terbaru dan Material 3.
2. Terapkan Clean Architecture dengan pendekatan Feature First.
3. Gunakan Riverpod untuk *state management* dan Isar (encrypted) untuk *local database* — **jangan tambahkan dependensi Firebase apa pun** kecuali secara eksplisit diminta di iterasi mendatang.
4. Aplikasi wajib dapat berfungsi penuh tanpa izin internet aktif sama sekali; jangan membuat permintaan jaringan apa pun di kode fitur inti.
5. Tidak ada layar login/registrasi/akun. Alur pertama kali buka aplikasi: Onboarding (skip-able) → Dashboard kosong.
6. Implementasikan App Lock (PIN + biometrik opsional) sebagai bagian dari setup awal yang dapat dilewati namun direkomendasikan.
7. Seluruh nominal uang disimpan sebagai integer (Rupiah penuh), bukan double/float, untuk presisi.
8. `currentAmount` pada Goal **wajib dihitung sebagai derived value** dari agregasi `GoalTransaction`, tidak ditulis langsung sebagai field yang dimutasi manual.
9. Implementasikan soft delete (`deletedAt`) untuk seluruh entitas finansial (Account, Income, Expense, Transfer, Goal, GoalTransaction) — tidak ada hard delete pada data yang punya riwayat transaksi terkait.
10. Fokus pada UX modern seperti aplikasi fintech premium.
11. Prioritaskan performa, animasi halus (60 FPS), dan *responsive design*.
12. Gunakan komponen yang *reusable* dan *scalable*.
13. Terapkan *dark mode* dan *light mode* sejak awal.

### Code Quality
* SOLID Principles
* Modular Architecture
* Reusable Widgets
* Feature-based Folder Structure
* Strong Typing
* Unit Test Ready
* Clean Code Standards

### Testing Requirements
AI Agent wajib menyertakan unit test untuk seluruh use case yang memengaruhi perhitungan saldo, karena ini area paling rawan bug pada aplikasi finansial:
* Expense melebihi available balance (kasus ditolak & kasus diizinkan dengan konfirmasi).
* Goal Deposit & Withdrawal (memastikan `lockedBalance` dan `availableBalance` akun konsisten setelahnya).
* Transfer antar akun (memastikan total saldo gabungan kedua akun tidak berubah, hanya berpindah).
* Penghitungan ulang `currentAmount` Goal dari `GoalTransaction` (agregasi konsisten meski ada transaksi yang di-soft-delete).
* Export → Import backup (round-trip test: data sebelum export harus identik dengan data setelah import).

---

## 14. Future Roadmap

### Phase 2
* Recurring Transactions
* Debt Tracking
* Family Wallet (catatan: ini akan memerlukan desain ulang arsitektur no-account/no-sync, karena kolaborasi multi-user secara inheren butuh server — perlu evaluasi ulang prinsip offline-first di Bagian 4)
* Split Transaction (multi-kategori dalam satu transaksi)
* Multi-currency support

### Phase 3
* OCR Receipt Scanner (tetap dapat berjalan on-device menggunakan ML Kit on-device model, agar prinsip offline-first tetap terjaga)
* AI Financial Advisor (jika menggunakan model cloud, wajib opt-in eksplisit dan didokumentasikan sebagai pengecualian terhadap prinsip offline-first)
* Investment Tracking
* Bank API Integration (akan memerlukan koneksi internet dan kemungkinan otentikasi pihak ketiga — pengecualian terhadap prinsip offline-first yang wajib dikomunikasikan jelas ke pengguna sebagai fitur opsional)

### Phase 4
* Web Application
* Desktop Application
* Multi-user Collaboration (memerlukan arsitektur backend baru, di luar prinsip no-account v1-v3)
* Financial Planning AI

---

## 15. Catatan untuk AI Agent
Dokumen ini final untuk implementasi v2.0. Prinsip non-negotiable dari dokumen ini adalah **offline-first dan no-account** (Bagian 4) — setiap keputusan implementasi yang ambigu wajib diselesaikan dengan memilih opsi yang paling konsisten dengan prinsip tersebut, bukan opsi yang paling mudah diimplementasikan menggunakan pola cloud-native konvensional. Fitur di Phase 3 dan Phase 4 yang berpotensi melanggar prinsip ini (Bank API Integration, AI Financial Advisor berbasis cloud, Multi-user Collaboration) wajib diperlakukan sebagai keputusan arsitektur terpisah yang memerlukan persetujuan eksplisit sebelum implementasi, bukan asumsi default.
