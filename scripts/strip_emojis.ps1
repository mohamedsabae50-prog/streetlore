# Strip emoji characters from Dart files using System.Text.Rune for correct
# Unicode handling. The script removes code points in the supplementary
# emoji ranges as well as the common dingbats/misc-symbols range.
param(
    [string]$Path = "lib"
)
$files = Get-ChildItem -Path $Path -Recurse -Filter "*.dart" -File
foreach ($f in $files) {
    $content = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
    $sb = [System.Text.StringBuilder]::new()
    $en = [System.Globalization.StringInfo]::GetTextElementEnumerator($content)
    while ($en.MoveNext()) {
        $element = $en.Current
        # Get the first code point of this grapheme cluster
        $first = [int][char]$element[0]
        $cp = $first
        # If first char is a high surrogate, combine with the following low surrogate
        if ($first -ge 0xD800 -and $first -le 0xDBFF -and $element.Length -gt 1) {
            $second = [int][char]$element[1]
            $cp = 0x10000 + (($first - 0xD800) * 0x400) + ($second - 0xDC00)
        }
        $isEmoji = $false
        if ($cp -ge 0x1F300 -and $cp -le 0x1FAFF) { $isEmoji = $true }
        elseif ($cp -ge 0x1F1E6 -and $cp -le 0x1F1FF) { $isEmoji = $true }
        elseif ($cp -ge 0x1F000 -and $cp -le 0x1F02F) { $isEmoji = $true }
        elseif ($cp -ge 0x2600  -and $cp -le 0x27BF)  { $isEmoji = $true }
        # Always skip the U+FE0F variation selector too
        if ($cp -eq 0xFE0F -or $cp -eq 0xFE0E) { $isEmoji = $true }
        if (-not $isEmoji) { [void]$sb.Append($element) }
    }
    $new = $sb.ToString()
    if ($new -ne $content) {
        [System.IO.File]::WriteAllText($f.FullName, $new, [System.Text.Encoding]::UTF8)
        Write-Host "Cleaned: $($f.FullName)"
    }
}
Write-Host "Done."
