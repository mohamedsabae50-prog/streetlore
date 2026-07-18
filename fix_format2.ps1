$path = "D:\codes\streetlore\tools\seed.dart"
$content = Get-Content $path -Raw

$pattern = [regex]"'is_hidden_gem':\s*\n(\s+)'price_local_egp':\s*(\d+),\s*\n(\s+)'price_foreigner_egp':\s*(\d+),\s*(false|true),"

$replacement = "'is_hidden_gem': `$5,`n`$1'price_local_egp': `$2,`n`$3'price_foreigner_egp': `$4,"

$newContent = [regex]::Replace($content, $pattern, $replacement)

Set-Content -Path $path -Value $newContent -NoNewline
Write-Host "Done! Replacements: $([regex]::Matches($content, $pattern).Count)"
