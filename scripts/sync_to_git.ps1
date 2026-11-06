$termMqh = "C:\Users\vaibh\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\06_MULTI_PAIR_SCANNERS\HR_UNIFIED_MASTER_OS_V4_FINAL\HR_Dashboard_Premium.mqh"
$repoMqh = "C:\Users\vaibh\.gemini\antigravity-ide\scratch\HemanthRanam-MT5-EAs\06_MULTI_PAIR_SCANNERS\HR_UNIFIED_MASTER_OS_V4_FINAL\HR_Dashboard_Premium.mqh"

Copy-Item $termMqh $repoMqh -Force

Set-Location "C:\Users\vaibh\.gemini\antigravity-ide\scratch\HemanthRanam-MT5-EAs"
git add 06_MULTI_PAIR_SCANNERS/HR_UNIFIED_MASTER_OS_V4_FINAL/HR_Dashboard_Premium.mqh
git commit -m "Refine Bloomberg flicker to gentle soft pastel gradient tints and calm duration"
git push origin main
Write-Host "Git push complete."
