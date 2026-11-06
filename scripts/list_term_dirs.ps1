$termDir = "$env:APPDATA\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075"
Get-ChildItem -Path $termDir -Directory | Select-Object Name
