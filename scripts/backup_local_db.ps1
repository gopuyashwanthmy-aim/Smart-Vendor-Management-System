$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$backupDir = Join-Path $projectRoot "backups"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
$container = "smart_vendor_db"
$dumpInContainer = "/tmp/smart_vendor_backup.dump"
$dumpOnHost = Join-Path $backupDir "smart_vendor_backup.dump"

Write-Host "Checking Docker database container..."
docker exec $container pg_isready -U smart_vendor -d smart_vendor
if ($LASTEXITCODE -ne 0) { throw "Database container is not ready. Start Docker Compose first." }

Write-Host "Creating a consistent custom-format PostgreSQL backup..."
docker exec $container pg_dump -Fc --no-owner --no-acl -U smart_vendor -d smart_vendor -f $dumpInContainer
if ($LASTEXITCODE -ne 0) { throw "pg_dump failed." }
docker cp "${container}:${dumpInContainer}" $dumpOnHost
if ($LASTEXITCODE -ne 0) { throw "Could not copy database backup from container." }
Write-Host "Backup created: $dumpOnHost"
Write-Host "Your source database was not modified. Keep this backup private."
