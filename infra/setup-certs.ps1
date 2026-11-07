<#
.SYNOPSIS
  Menyiapkan sertifikat TLS Mosquitto dan file passwd/acl untuk pengembangan lokal (R-00).
#>

$certDir = "$PSScriptRoot/mosquitto/certs"
$mosquittoDir = "$PSScriptRoot/mosquitto"

Write-Host "==> Menyiapkan folder dan file ACL..."
if (-not (Test-Path "$mosquittoDir/acl")) {
    Copy-Item "$mosquittoDir/acl.example" "$mosquittoDir/acl"
    Write-Host "    acl dibuat dari acl.example"
}

Write-Host "==> Menghasilkan sertifikat TLS Mosquitto..."
$caCnf = @"
[req]
distinguished_name = req_distinguished_name
prompt = no

[req_distinguished_name]
CN = SmartWater-CA
O = TimunMania
C = ID

[v3_ca]
basicConstraints = critical, CA:TRUE
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
"@

$serverCnf = @"
[req]
distinguished_name = req_distinguished_name
prompt = no

[req_distinguished_name]
CN = localhost
O = TimunMania
C = ID

[server_ext]
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
DNS.2 = host.docker.internal
IP.1 = 127.0.0.1
IP.2 = 0.0.0.0
"@

$caCnf | Out-File -FilePath "$certDir/ca.cnf" -Encoding ascii
$serverCnf | Out-File -FilePath "$certDir/server.cnf" -Encoding ascii

$openssl = (Get-Command openssl -ErrorAction SilentlyContinue).Source
if (-not $openssl) {
    if (Test-Path "D:\Git\usr\bin\openssl.exe") {
        $openssl = "D:\Git\usr\bin\openssl.exe"
    } elseif (Test-Path "C:\Program Files\Git\usr\bin\openssl.exe") {
        $openssl = "C:\Program Files\Git\usr\bin\openssl.exe"
    } else {
        throw "OpenSSL tidak ditemukan. Pastikan Git for Windows atau OpenSSL terpasang di PATH."
    }
}

# CA
& $openssl genrsa -out "$certDir/ca.key" 2048
& $openssl req -new -x509 -days 3650 -key "$certDir/ca.key" -out "$certDir/ca.crt" -config "$certDir/ca.cnf" -extensions v3_ca

# Server
& $openssl genrsa -out "$certDir/server.key" 2048
& $openssl req -new -key "$certDir/server.key" -out "$certDir/server.csr" -config "$certDir/server.cnf"
& $openssl x509 -req -in "$certDir/server.csr" -CA "$certDir/ca.crt" -CAkey "$certDir/ca.key" -CAcreateserial -out "$certDir/server.crt" -days 3650 -extfile "$certDir/server.cnf" -extensions server_ext

Remove-Item "$certDir/ca.cnf", "$certDir/server.cnf", "$certDir/server.csr" -ErrorAction SilentlyContinue

Write-Host "==> Menghasilkan mosquitto passwd file via Docker..."
$mPath = (Resolve-Path $mosquittoDir).Path.Replace("\", "/")
docker run --rm -v "${mPath}:/m" eclipse-mosquitto:2 mosquitto_passwd -c -b /m/passwd backend backend_dev_pass
docker run --rm -v "${mPath}:/m" eclipse-mosquitto:2 mosquitto_passwd -b /m/passwd 1 device1_dev_pass
docker run --rm -v "${mPath}:/m" eclipse-mosquitto:2 mosquitto_passwd -b /m/passwd 2 sim_dev_pass
docker run --rm --entrypoint sh -v "${mPath}:/m" eclipse-mosquitto:2 -c "chmod 644 /m/passwd"

Write-Host "==> Setup selesai! Jalankan 'docker compose -f infra/docker-compose.yml --env-file .env up -d' untuk memulai."

