$compiler = "C:\Program Files\MetaTrader 5\metaeditor64.exe"
$source   = "C:\Users\vaibh\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\06_MULTI_PAIR_SCANNERS\HR_UNIFIED_MASTER_OS_V4_FINAL\HR_UNIFIED_MASTER_OS.mq5"
$log      = "C:\Users\vaibh\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\06_MULTI_PAIR_SCANNERS\HR_UNIFIED_MASTER_OS_V4_FINAL\compile_out.log"

$arg1 = "/compile:" + $source
$arg2 = "/log:" + $log

Write-Host "Running: $compiler $arg1 $arg2"
$proc = Start-Process -FilePath $compiler -ArgumentList @($arg1, $arg2) -Wait -PassThru
Write-Host "Exit code: $($proc.ExitCode)"

Start-Sleep -Seconds 2
if (Test-Path $log) {
    Get-Content $log -Tail 15
} else {
    Write-Host "No log file found."
}

$ex5 = [System.IO.Path]::ChangeExtension($source, ".ex5")
Write-Host "Checking EX5: $ex5"
Write-Host "EX5 Exists: $(Test-Path $ex5)"
