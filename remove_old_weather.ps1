$path = "D:\codes\streetlore\lib\presentation\screens\home_screen.dart"
$content = Get-Content $path -Raw
$lineCount = ([regex]::Matches($content, "`n")).Count + 1
Write-Host "Original line count: $lineCount"

$startMarker = 'class _WeatherWidget extends StatelessWidget'
$endMarker = 'class _CategoryItem'

$startIdx = $content.IndexOf($startMarker)
$endIdx = $content.IndexOf($endMarker)
Write-Host "Start idx: $startIdx"
Write-Host "End idx: $endIdx"

if ($startIdx -lt 0 -or $endIdx -lt 0) {
    Write-Host "Markers not found"
    exit 1
}

$newContent = $content.Substring(0, $startIdx) + $content.Substring($endIdx)
Set-Content -Path $path -Value $newContent -NoNewline

$newLineCount = ([regex]::Matches($newContent, "`n")).Count + 1
Write-Host "New line count: $newLineCount"
Write-Host "Removed $($lineCount - $newLineCount) lines"
