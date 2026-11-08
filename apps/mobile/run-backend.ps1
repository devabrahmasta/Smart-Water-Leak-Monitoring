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
  [string]$Token
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
  return ($line -replace "^$key=", '').Trim()
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

Write-Host "==> Backend: http://${Ip}:8000"
Set-Location $PSScriptRoot
flutter run `
  --dart-define=USE_MOCK=false `
  --dart-define=API_BASE_URL=http://${Ip}:8000 `
  --dart-define=API_TOKEN=$Token `
  @firebase
