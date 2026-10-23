$metaEditor = "C:\Program Files\MetaTrader 5\metaeditor64.exe"
$eas = @("07_EMA_EAS\9_EMA_EA.mq5", "07_EMA_EAS\21_EMA_EA.mq5", "07_EMA_EAS\50_EMA_EA.mq5", "07_EMA_EAS\100_EMA_EA.mq5")
foreach($ea in $eas) {
    $fullPath = (Resolve-Path $ea).Path
    $logPath = [System.IO.Path]::ChangeExtension($fullPath, "log")
    if (Test-Path $logPath) { Remove-Item $logPath -Force }
    $proc = Start-Process -FilePath $metaEditor -ArgumentList "/compile:`"$fullPath`"", "/log:`"$logPath`"" -Wait -PassThru
    Start-Sleep -Milliseconds 600
    if (Test-Path $logPath) {
        $logContent = Get-Content $logPath -Raw
        Write-Host "=== $ea ==="
        Write-Host $logContent.Trim()
    } else {
        Write-Host "[WARN] No log for $ea"
    }
}
