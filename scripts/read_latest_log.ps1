$logDir = "$env:APPDATA\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Logs"
$latestLog = Get-ChildItem -Path $logDir -Filter "*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if($latestLog) {
   Write-Host "Latest Log: $($latestLog.FullName)"
   Get-Content $latestLog.FullName -Tail 25
}
