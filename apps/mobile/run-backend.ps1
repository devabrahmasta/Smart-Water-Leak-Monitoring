<#
.SYNOPSIS
  Menjalankan aplikasi di HP dengan backend lokal (bukan mock).
  IP laptop dideteksi otomatis, token dibaca dari ..\..\.env, jadi tidak
  ada rahasia yang perlu diketik atau di-commit.
  Kalau .env berisi FIREBASE_API_KEY, FIREBASE_APP_ID, FIREBASE_SENDER_ID,
  dan FIREBASE_PROJECT_ID, push FCM ikut diaktifkan.

.EXAMPLE
  .\run-backend.ps1                    # IP Wi-Fi laptop ini
  .\run-backend.ps1 -Ip 192.168.0.50   # backend di laptop lain (teman)
  .\run-backend.ps1 -Token xxx         # token dari laptop teman
#>
param(
  [string]$Ip,
  [string]$Token,
  [string]$Device
)

$ErrorActionPreference = 'Stop'

if (-not $Ip) {
  $Ip = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias 'Wi-Fi*' -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -notlike '169.254.*' } |
    Select-Object -First 1).IPAddress
  if (-not $Ip) { throw 'IP Wi-Fi tidak ditemukan. Isi manual: .\run-backend.ps1 -Ip <IP-laptop>' }
}

$envFile = Join-Path $PSScriptRoot '..\..\.env'
function Read-Env([string]$key) {
  if (-not (Test-Path $envFile)) { return '' }
  $line = Get-Content $envFile | Where-Object { $_ -match "^$key=" } | Select-Object -First 1
  if (-not $line) { return '' }
  return ([string]$line -replace "^$key=", '').Trim()
}

if (-not $Token) {
  if (-not (Test-Path $envFile)) { throw '.env tidak ditemukan. Isi manual: -Token <API_OWNER_TOKEN>' }
  $Token = Read-Env 'API_OWNER_TOKEN'
  if (-not $Token) { throw 'API_OWNER_TOKEN di .env kosong.' }
}

$firebase = @()
foreach ($key in 'FIREBASE_API_KEY', 'FIREBASE_APP_ID', 'FIREBASE_SENDER_ID', 'FIREBASE_PROJECT_ID') {
  $value = Read-Env $key
  if ($value) { $firebase += "--dart-define=$key=$value" }
}
if ($firebase.Count -eq 4) { Write-Host '==> Push FCM aktif' }
else { Write-Host '==> Push FCM nonaktif (FIREBASE_* belum lengkap di .env)'; $firebase = @() }

# Beberapa perangkat terhubung: pilih Android pertama supaya flutter tidak bertanya.
Set-Location $PSScriptRoot
if (-not $Device) {
  # Disimpan dulu: di PowerShell 5.1 ConvertFrom-Json mengirim array sebagai satu objek.
  $devices = flutter devices --machine 2>$null | Out-String | ConvertFrom-Json
  $Device = ($devices | Where-Object { $_.targetPlatform -like 'android*' } | Select-Object -First 1).id
  if (-not $Device) { throw 'HP Android tidak terdeteksi. Cek kabel USB dan USB debugging.' }
}

# Dipakai juga oleh tombol Run di VS Code. File ini di-ignore git.
$defines = @{ API_BASE_URL = "http://${Ip}:8000"; API_TOKEN = $Token }
foreach ($key in 'FIREBASE_API_KEY', 'FIREBASE_APP_ID', 'FIREBASE_SENDER_ID', 'FIREBASE_PROJECT_ID') {
  $value = Read-Env $key
  if ($firebase.Count -eq 4) { $defines[$key] = $value }
}
[System.IO.File]::WriteAllText((Join-Path $PSScriptRoot '.env.defines.json'), ($defines | ConvertTo-Json))

Write-Host "==> Perangkat: $Device"
Write-Host "==> Backend: http://${Ip}:8000"
# Baris stderr dari flutter (mis. log GC) bukan berarti gagal, jangan hentikan skrip.
$ErrorActionPreference = 'Continue'
flutter run -d $Device `
  --dart-define=API_BASE_URL=http://${Ip}:8000 `
  --dart-define=API_TOKEN=$Token `
  @firebase
