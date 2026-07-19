

param([string]$Path = "lib")

function Remove-Comments {
    param([string]$text)
    $sb = [System.Text.StringBuilder]::new()
    $i = 0
    $len = $text.Length
    while ($i -lt $len) {
        $c = $text[$i]
        if ($c -eq '/' -and ($i + 1) -lt $len -and $text[$i + 1] -eq '*') {
            $end = $text.IndexOf('*/', $i + 2)
            if ($end -lt 0) {
                break
            }
            $i = $end + 2
            
            if (($i -lt $len) -and $text[$i] -eq "`n") {
                $i++
            }
            continue
        }
        if ($c -eq '/' -and ($i + 1) -lt $len -and $text[$i + 1] -eq '/') {
            $end = $i
            while ($end -lt $len -and $text[$end] -ne "`n") { $end++ }
            $i = $end
            continue
        }
        if (($c -eq '"' -or $c -eq "'") -and ($i + 2) -lt $len -and $text[$i + 1] -eq $c -and $text[$i + 2] -eq $c) {
            $q = $c
            [void]$sb.Append($c)
            [void]$sb.Append($c)
            [void]$sb.Append($c)
            $i += 3
            while ($i -lt $len) {
                if ($text[$i] -eq '\' -and ($i + 1) -lt $len) {
                    [void]$sb.Append($text[$i])
                    [void]$sb.Append($text[$i + 1])
                    $i += 2
                    continue
                }
                [void]$sb.Append($text[$i])
                if ($text[$i] -eq $q -and $text[$i + 1] -eq $q -and $text[$i + 2] -eq $q) {
                    $i += 3
                    break
                }
                $i++
            }
            continue
        }
        if ($c -eq '"' -or $c -eq "'") {
            $q = $c
            [void]$sb.Append($c)
            $i++
            while ($i -lt $len) {
                if ($text[$i] -eq '\' -and ($i + 1) -lt $len) {
                    [void]$sb.Append($text[$i])
                    [void]$sb.Append($text[$i + 1])
                    $i += 2
                    continue
                }
                [void]$sb.Append($text[$i])
                if ($text[$i] -eq $q) { $i++; break }
                if ($text[$i] -eq "`n") { $i++; break }
                $i++
            }
            continue
        }
        [void]$sb.Append($c)
        $i++
    }
    return $sb.ToString()
}

function Collapse-Blank-Lines {
    param([string]$text)
    $text = [regex]::Replace($text, "`r`n", "`n")
    $text = [regex]::Replace($text, "`n{3,}", "`n`n")
    return $text
}

$files = Get-ChildItem -Path $Path -Recurse -Filter "*.dart" -File
foreach ($f in $files) {
    $content = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
    $stripped = Remove-Comments $content
    $clean = Collapse-Blank-Lines $stripped
    if ($clean -ne $content) {
        [System.IO.File]::WriteAllText($f.FullName, $clean, [System.Text.Encoding]::UTF8)
        Write-Host "Cleaned: $($f.FullName)"
    }
}
Write-Host "Done."
