<#
.SYNOPSIS
  Menjalankan aplikasi di HP dengan backend lokal (bukan mock).
  IP laptop dideteksi otomatis, token dibaca dari ..\..\.env, jadi tidak
  ada rahasia yang perlu diketik atau di-commit.

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

if (-not $Token) {
  $envFile = Join-Path $PSScriptRoot '..\..\.env'
  if (-not (Test-Path $envFile)) { throw '.env tidak ditemukan. Isi manual: -Token <API_OWNER_TOKEN>' }
  $line = Get-Content $envFile | Where-Object { $_ -match '^API_OWNER_TOKEN=' } | Select-Object -First 1
  $Token = ($line -replace '^API_OWNER_TOKEN=', '').Trim()
  if (-not $Token) { throw 'API_OWNER_TOKEN di .env kosong.' }
}

Write-Host "==> Backend: http://${Ip}:8000"
Set-Location $PSScriptRoot
flutter run `
  --dart-define=USE_MOCK=false `
  --dart-define=API_BASE_URL=http://${Ip}:8000 `
  --dart-define=API_TOKEN=$Token
