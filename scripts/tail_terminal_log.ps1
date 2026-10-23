$logFile = "C:\Users\vaibh\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\logs\20261023.log"
$lines = Get-Content $logFile -Tail 40
foreach ($l in $lines) {
    Write-Host $l
}
