$logFile = "C:\Users\vaibh\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\Tester\logs\20261023.log"
$lines = Get-Content $logFile -Tail 150
foreach ($l in $lines) {
    if ($l -match "report" -or $l -match "Report" -or $l -match "html" -or $l -match "htm" -or $l -match "log file") {
        Write-Host $l
    }
}
