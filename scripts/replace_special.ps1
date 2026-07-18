# Replace typographic / box-drawing / math / arrow characters that the
# bundled Cairo font may not contain with ASCII or simple alternatives.
param([string]$Path = "lib")

$replacements = [ordered]@{
    [char]0x2014 = "-"
    [char]0x2013 = "-"
    [char]0x2018 = "'"
    [char]0x2019 = "'"
    [char]0x201C = '"'
    [char]0x201D = '"'
    [char]0x2026 = "..."
    [char]0x2192 = "->"
    [char]0x2190 = "<-"
    [char]0x2191 = "^"
    [char]0x2193 = "v"
    [char]0x2264 = "<="
    [char]0x2265 = ">="
    [char]0x00B1 = "+/-"
    [char]0x00D7 = "x"
    [char]0x00F7 = "/"
    [char]0x2500 = "-"
    [char]0x2501 = "-"
    [char]0x2502 = "|"
    [char]0x251C = "+"
    [char]0x2524 = "+"
    [char]0x2534 = "+"
    [char]0x252C = "+"
    [char]0x256D = "("
    [char]0x256E = ")"
    [char]0x256F = ")"
    [char]0x2570 = "("
    [char]0x2B50 = ""
    [char]0x2605 = ""
    [char]0x2606 = ""
    [char]0x2728 = ""
}

$files = Get-ChildItem -Path $Path -Recurse -Filter "*.dart" -File
foreach ($f in $files) {
    $content = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
    $new = $content
    foreach ($k in $replacements.Keys) {
        $new = $new.Replace([string]$k, [string]$replacements[$k])
    }
    if ($new -ne $content) {
        [System.IO.File]::WriteAllText($f.FullName, $new, [System.Text.Encoding]::UTF8)
        Write-Host "Cleaned: $($f.FullName)"
    }
}
Write-Host "Done."
