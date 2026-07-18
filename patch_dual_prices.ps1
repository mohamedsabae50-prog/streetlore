$dualPrices = @{
    '1'  = @{ local = 60;   foreign = 200;  note = 'Egyptian EGP 60, Foreigner EGP 200' }
    '2'  = @{ local = 20;   foreign = 150;  note = 'Egyptian EGP 20, Foreigner EGP 150' }
    '3'  = @{ local = 10;   foreign = 60;   note = 'Gardens: EG 10/EG 60, Palace: EG 25/EG 100' }
    '4'  = @{ local = 25;   foreign = 150;  note = 'Egyptian EGP 25, Foreigner EGP 150' }
    '5'  = @{ local = 5;    foreign = 30;   note = 'Egyptian EGP 5, Foreigner EGP 30' }
    '7'  = @{ local = 30;   foreign = 150;  note = 'Egyptian EGP 30, Foreigner EGP 150' }
    '9'  = @{ local = 25;   foreign = 100;  note = 'Egyptian EGP 25, Foreigner EGP 100' }
    '11' = @{ local = 50;   foreign = 200;  note = 'Egyptian EGP 50, Foreigner EGP 200' }
    '17' = @{ local = 30;   foreign = 100;  note = 'Egyptian EGP 30, Foreigner EGP 100' }
    '21' = @{ local = 250;  foreign = 600;  note = 'Avg per person: EG 250/EG 600' }
    '22' = @{ local = 200;  foreign = 450;  note = 'Avg per person: EG 200/EG 450' }
    '23' = @{ local = 100;  foreign = 250;  note = 'Avg per person: EG 100/EG 250' }
    '27' = @{ local = 25;   foreign = 150;  note = 'Egyptian EGP 25, Foreigner EGP 150' }
    '30' = @{ local = 200;  foreign = 500;  note = 'Avg per person: EG 200/EG 500' }
    '32' = @{ local = 0;    foreign = 0;    note = 'No entry fee (mall)' }
}

$path = "D:\codes\streetlore\tools\seed.dart"
$content = Get-Content $path -Raw

$dualPrices.GetEnumerator() | Sort-Object {$_.Key} | ForEach-Object {
    $id = $_.Key
    $local = $_.Value.local
    $foreign = $_.Value.foreign
    $note = $_.Value.note

    $pattern = "(\s+'id': '$id',[\s\S]+?'price_note':\s*')([^']*)(',[\s\S]+?'is_hidden_gem':\s*)(false|true,)"

    if ($content -match $pattern) {
        $replacement = "`$1$note`$2`$3`$4`n    'price_local_egp': $local,`n    'price_foreigner_egp': $foreign,"
        $content = $content -replace $pattern, $replacement
        Write-Host "Updated place ID $id"
    } else {
        Write-Host "Place ID ${id}: pattern not matched" -ForegroundColor Yellow
    }
}

Set-Content -Path $path -Value $content -NoNewline
Write-Host "`nDone!"
