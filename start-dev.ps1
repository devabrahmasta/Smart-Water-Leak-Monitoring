<#
.SYNOPSIS
  Menyalakan seluruh backend lokal Smart Water dalam satu perintah:
  Postgres + Mosquitto (Docker), REST API, worker MQTT, dan simulator Kamar 3
  (diatur dari Mode demo aplikasi). Kamar 1 dan Kamar 2 memakai ESP32 asli.

.EXAMPLE
  .\start-dev.ps1                       # Kamar 3 mulai normal
  .\start-dev.ps1 -Scenario leak-stable # Kamar 3 mulai dengan skenario lain
  .\start-dev.ps1 -Scenario leak-continuous -Accel  # Kamar 3 bocor dalam ±30 detik

  Skenario Kamar 3 juga bisa diganti dari Mode demo.

  Prasyarat sekali saja: Docker Desktop menyala, .env terisi,
  infra\setup-certs.ps1 sudah dijalankan, services\api\.venv sudah dibuat,
  dan migrasi + seed sudah dijalankan (lihat services\api\README.md).
#>
param(
  [ValidateSet('normal', 'leak-continuous', 'leak-stable', 'quiet-hours', 'offline', 'no-ack')]
  [string]$Scenario = 'normal',
  # Percepat pemicu kebocoran jadi 3 tick (±30 detik), untuk demo.
  [switch]$Accel
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$api = Join-Path $root 'services\api'
$activate = Join-Path $api '.venv\Scripts\Activate.ps1'

if (-not (Test-Path (Join-Path $root '.env'))) { throw '.env belum ada. Salin dari .env.example lalu isi.' }
if (-not (Test-Path $activate)) { throw 'services\api\.venv belum ada. Lihat services\api\README.md langkah 1.' }

Write-Host '==> Postgres + Mosquitto (Docker)...'
docker compose -f (Join-Path $root 'infra\docker-compose.yml') --env-file (Join-Path $root '.env') up -d
if ($LASTEXITCODE -ne 0) { throw 'Docker gagal. Pastikan Docker Desktop sudah menyala.' }

function Start-Window([string]$title, [string]$dir, [string]$command) {
  $script = "`$Host.UI.RawUI.WindowTitle = '$title'; Set-Location '$dir'; & '$activate'; $command"
  Start-Process powershell -ArgumentList '-NoExit', '-ExecutionPolicy', 'Bypass', '-Command', $script
}

Write-Host '==> Membuka 3 jendela: API, worker MQTT, simulator Kamar 3...'
Start-Window 'SmartWater API' $api 'uvicorn app.main:app --host 0.0.0.0 --port 8000'
Start-Sleep -Seconds 2
Start-Window 'SmartWater Worker' $api 'python -m app.mqtt.worker'
Start-Sleep -Seconds 2
$accelArg = if ($Accel) { ' --accel' } else { '' }
Start-Window "SmartWater Simulator Kamar 3 ($Scenario$accelArg)" $root "python -m services.simulator.main --device-id 3 --scenario $Scenario$accelArg"

Write-Host ''
Write-Host 'Selesai. API: http://localhost:8000/docs'
Write-Host 'Matikan: tutup 3 jendela tadi, lalu  docker compose -f infra\docker-compose.yml down'
