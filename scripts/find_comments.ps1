param([string]$Path = "lib")
$files = Get-ChildItem -Path $Path -Recurse -Filter "*.dart" -File
foreach ($f in $files) {
    $content = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
    $lines = $content -split "`n"
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*(///|//\s|/\*)') {
            Write-Host "$($f.Name):$($i+1): $($lines[$i].Trim())"
        }
    }
}
