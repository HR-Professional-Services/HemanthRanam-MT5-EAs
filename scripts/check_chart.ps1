$chartFiles = Get-ChildItem -Path "$env:APPDATA\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\profiles\charts" -Recurse -Filter "*.chr"
foreach($f in $chartFiles) {
   $content = Get-Content $f.FullName -Raw
   if($content -match 'expert') {
      Write-Host "Chart: $($f.FullName)"
      $lines = $content -split "`r?`n" | Where-Object { $_ -match 'expert|name=' } | Select-Object -First 10
      Write-Host ($lines -join ' | ')
   }
}
