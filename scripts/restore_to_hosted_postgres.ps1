param(
    [Parameter(Mandatory=$true)][string]$HostName,
    [Parameter(Mandatory=$true)][string]$Database,
    [Parameter(Mandatory=$true)][string]$Username,
    [int]$Port = 5432
)
$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$backupDir = Join-Path $projectRoot "backups"
$dumpPath = Join-Path $backupDir "smart_vendor_backup.dump"
if (!(Test-Path $dumpPath)) { throw "Backup not found. Run scripts/backup_local_db.ps1 first." }

Write-Warning "Restore is intended for a NEW, EMPTY hosted database. This script does not drop or clean any tables."
$confirm = Read-Host "Type RESTORE to import the backup into $Database@$HostName"
if ($confirm -ne "RESTORE") { Write-Host "Cancelled."; exit 1 }
$securePassword = Read-Host "Hosted PostgreSQL password" -AsSecureString
$ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
try { $env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }

$volume = "${backupDir}:/backup:ro"
docker run --rm -e PGPASSWORD -v $volume postgres:16 pg_restore `
  --no-owner --no-acl --exit-on-error `
  -h $HostName -p $Port -U $Username -d $Database `
  /backup/smart_vendor_backup.dump
if ($LASTEXITCODE -ne 0) { throw "Restore failed. Review the error; the local database remains unchanged." }
Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
Write-Host "Restore completed. Run the backend database initializer to verify the schema."
