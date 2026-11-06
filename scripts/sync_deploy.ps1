$srcDir = 'C:\Users\vaibh\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\06_MULTI_PAIR_SCANNERS\HR_UNIFIED_MASTER_OS_V4_FINAL'
$repoDir = 'C:\Users\vaibh\.gemini\antigravity-ide\scratch\HemanthRanam-MT5-EAs\06_MULTI_PAIR_SCANNERS\HR_UNIFIED_MASTER_OS_V4_FINAL'
$scanDir = 'C:\Users\vaibh\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\06_MULTI_PAIR_SCAN\HR_UNIFIED_MASTER_OS_V4_FINAL'
$backupDir = 'C:\Users\vaibh\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Files\Backup\' + (Get-Date -Format 'yyyyMMdd_HHmmss')

New-Item -ItemType Directory -Path $scanDir -Force | Out-Null
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

Copy-Item -Path "$srcDir\*" -Destination $repoDir -Recurse -Force
Copy-Item -Path "$srcDir\*" -Destination $scanDir -Recurse -Force
Copy-Item -Path "$srcDir\*" -Destination $backupDir -Recurse -Force

Write-Host "Copied to Repo, 06_MULTI_PAIR_SCAN, and Backup: $backupDir"
Get-ChildItem $repoDir | Select-Object Name, Length
