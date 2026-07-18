$path = "D:\codes\streetlore\tools\seed.dart"
$content = Get-Content $path -Raw

$lines = $content -split "`n"
$newLines = @()
$i = 0

while ($i -lt $lines.Count) {
    $line = $lines[$i]
    if ($line -match "^(\s+)'is_hidden_gem':\s*$" -and ($i + 3) -lt $lines.Count) {
        $nextLine = $lines[$i + 1]
        $nextLine2 = $lines[$i + 2]
        $nextLine3 = $lines[$i + 3]

        if ($nextLine -match "^(\s+)'price_local_egp':\s*(\d+),\s*$" -and
            $nextLine2 -match "^(\s+)'price_foreigner_egp':\s*(\d+),\s*$" -and
            $nextLine3 -match "^(\s+)(false|true),\s*$") {

            $indent1 = $matches[1]
            $local = $matches[2]
            $indent2 = $Matches[1]
            $foreign = $Matches[2]
            $indent3 = $Matches[1]
            $boolVal = $Matches[2]

            $re = [regex]"^(\s+)'price_local_egp':\s*(\d+),\s*$"
            $m1 = $re.Match($nextLine)
            $local = $m1.Groups[2].Value
            $indentL = $m1.Groups[1].Value

            $re2 = [regex]"^(\s+)'price_foreigner_egp':\s*(\d+),\s*$"
            $m2 = $re2.Match($nextLine2)
            $foreign = $m2.Groups[2].Value
            $indentF = $m2.Groups[1].Value

            $re3 = [regex]"^(\s+)(false|true),\s*$"
            $m3 = $re3.Match($nextLine3)
            $boolVal = $m3.Groups[2].Value
            $indentB = $m3.Groups[1].Value

            $newLines += "$indent1'is_hidden_gem': $boolVal,"
            $newLines += "$indentL'price_local_egp': $local,"
            $newLines += "$indentF'price_foreigner_egp': $foreign,"
            $i += 4
            continue
        }
    }
    $newLines += $line
    $i++
}

Set-Content -Path $path -Value ($newLines -join "`n") -NoNewline
Write-Host "Done! Lines: $($newLines.Count)"
