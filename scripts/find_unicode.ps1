# Find all non-ASCII, non-Arabic characters in Dart files. Useful to
# spot glyphs that may be missing from the bundled Cairo font.
param([string]$Path = "lib")
$files = Get-ChildItem -Path $Path -Recurse -Filter "*.dart" -File
foreach ($f in $files) {
    $content = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
    $found = @{}
    $en = [System.Globalization.StringInfo]::GetTextElementEnumerator($content)
    while ($en.MoveNext()) {
        $element = $en.Current
        $first = [int][char]$element[0]
        $cp = $first
        if ($first -ge 0xD800 -and $first -le 0xDBFF -and $element.Length -gt 1) {
            $second = [int][char]$element[1]
            $cp = 0x10000 + (($first - 0xD800) * 0x400) + ($second - 0xDC00)
        }
        # Arabic block: 0600-06FF. Skip those.
        if ($cp -ge 0x0600 -and $cp -le 0x06FF) { continue }
        # Basic Latin: skip
        if ($cp -lt 0x0080) { continue }
        # Latin-1 supplement: skip
        if ($cp -ge 0x00A0 -and $cp -lt 0x0100) { continue }
        # Skip the variation selectors we already strip
        if ($cp -eq 0xFE0F -or $cp -eq 0xFE0E) { continue }
        # Skip already-removed emoji ranges
        if (($cp -ge 0x1F300 -and $cp -le 0x1FAFF) -or
            ($cp -ge 0x1F1E6 -and $cp -le 0x1F1FF) -or
            ($cp -ge 0x1F000 -and $cp -le 0x1F02F) -or
            ($cp -ge 0x2600  -and $cp -le 0x27BF)) { continue }
        # Skip ZWJ / variation selectors
        if ($cp -eq 0x200D -or $cp -eq 0xFEFF) { continue }
        $key = "U+{0:X4}" -f $cp
        if (-not $found.ContainsKey($key)) {
            $found[$key] = @($f.Name, $element)
        }
    }
    if ($found.Count -gt 0) {
        Write-Host "--- $($f.Name) ---"
        foreach ($k in $found.Keys) {
            Write-Host "  $k -> '$($found[$k][1])'"
        }
    }
}
