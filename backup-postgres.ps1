# Backs up the self-hosted TagNav Postgres database to OneDrive.
# Runs nightly via the "TagNav Postgres Backup" Windows Scheduled Task.
# Restore with: docker exec -i supabase-db pg_restore -U postgres -d postgres --clean < <dump-file>

$ErrorActionPreference = 'Stop'

$BackupDir = "$env:USERPROFILE\OneDrive\Backups\TagNav-Postgres"
$RetentionCount = 14
$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$BackupFile = Join-Path $BackupDir "tagnav-$Timestamp.dump"

New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null

docker exec supabase-db pg_dump -U postgres -Fc postgres > $BackupFile

if ($LASTEXITCODE -ne 0 -or -not (Test-Path $BackupFile) -or (Get-Item $BackupFile).Length -eq 0) {
    Remove-Item $BackupFile -ErrorAction SilentlyContinue
    Write-Error "pg_dump failed (exit code $LASTEXITCODE) - is the supabase-db container running?"
    exit 1
}

Write-Host "Backup written: $BackupFile ($((Get-Item $BackupFile).Length) bytes)"

# Retention: keep only the most recent $RetentionCount dumps.
$old = Get-ChildItem $BackupDir -Filter 'tagnav-*.dump' | Sort-Object LastWriteTime -Descending | Select-Object -Skip $RetentionCount
foreach ($f in $old) {
    Remove-Item $f.FullName -Force
    Write-Host "Pruned old backup: $($f.Name)"
}
