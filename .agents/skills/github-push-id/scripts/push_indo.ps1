param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Pesan,

    [Parameter(Position = 1)]
    [ValidateSet("fitur", "perbaikan", "refaktor", "uji", "dokumen", "gaya", "koreksi")]
    [string]$Tipe = "perbaikan",

    [Parameter(Position = 2)]
    [string]$Cakupan = "keuangan"
)

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " Menjalankan Git Push (Commit Bahasa Indonesia)" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 1. Jalankan test validasi
Write-Host "[1/4] Menjalankan test validasi (flutter test)..." -ForegroundColor Yellow
flutter test
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Pengujian gagal! Commit dibatalkan untuk menjaga integritas kode." -ForegroundColor Red
    exit $LASTEXITCODE
}
Write-Host "Validasi pengujian sukses (100% lulus)." -ForegroundColor Green

# 2. Stage changes
Write-Host "[2/4] Menambahkan berkas ke staging area..." -ForegroundColor Yellow
git add .

# 3. Commit
$commitMsg = "$($Tipe)($($Cakupan)): $Pesan"
Write-Host "[3/4] Melakukan commit: '$commitMsg'..." -ForegroundColor Yellow
git commit -m "$commitMsg"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Peringatan: Gagal commit atau tidak ada perubahan baru." -ForegroundColor DarkYellow
}

# 4. Push ke GitHub
$branch = (git branch --show-current).Trim()
if (-not $branch) {
    $branch = "main"
}
Write-Host "[4/4] Melakukan push ke origin/$branch..." -ForegroundColor Yellow
git push origin $branch

if ($LASTEXITCODE -eq 0) {
    Write-Host "Berhasil push ke GitHub dengan commit Bahasa Indonesia!" -ForegroundColor Green
} else {
    Write-Host "ERROR: Gagal melakukan push ke remote GitHub." -ForegroundColor Red
}
