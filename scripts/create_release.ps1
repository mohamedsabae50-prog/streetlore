$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class CredMan {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct CREDENTIAL {
        public UInt32 Flags; public UInt32 Type;
        public IntPtr TargetName; public IntPtr Comment;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
        public UInt32 CredentialBlobSize; public IntPtr CredentialBlob;
        public UInt32 Persist; public UInt32 AttributeCount;
        public IntPtr Attributes; public IntPtr TargetAlias; public IntPtr UserName;
    }
    [DllImport("advapi32.dll", EntryPoint="CredReadW", CharSet=CharSet.Unicode, SetLastError=true)]
    public static extern bool CredRead(string target, UInt32 type, UInt32 reservedFlag, out IntPtr credentialPtr);
    [DllImport("advapi32.dll", EntryPoint="CredFree", SetLastError=true)]
    public static extern void CredFree(IntPtr buffer);
}
'@

$credPtr = [IntPtr]::Zero
[CredMan]::CredRead("git:https://github.com", 1, 0, [ref]$credPtr) | Out-Null
$cred = [System.Runtime.InteropServices.Marshal]::PtrToStructure($credPtr, [type][CredMan+CREDENTIAL])
$passwordBytes = New-Object byte[] $cred.CredentialBlobSize
[System.Runtime.InteropServices.Marshal]::Copy($cred.CredentialBlob, $passwordBytes, 0, $cred.CredentialBlobSize)
$TOKEN = [System.Text.Encoding]::Unicode.GetString($passwordBytes)
[CredMan]::CredFree($credPtr)

Write-Host "Token retrieved: $($TOKEN.Length) chars"

$headers = @{
    "Authorization" = "Bearer $TOKEN"
    "Accept" = "application/vnd.github+json"
    "X-GitHub-Api-Version" = "2022-11-28"
    "User-Agent" = "streetlore-release-script"
}

$tag = "v1.0.21"
$apkName = "streetlore-v1.0.21-arm64.apk"

$lines = @(
    '## What is new in v1.0.21',
    '',
    '### 1. Profile counters - never zero again',
    '- `profile_screen.dart` Explored counter now uses `MAX(gamification.stats.placesVisited, placeP.savedPlaces.length)` as a fallback so the value is never 0 when the user has at least one saved place, even if gamification stats failed to sync.',
    '',
    '### 2. AI Tour Guide - no more mid-sentence cutoffs',
    '- `ai_tour_guide_service.dart askAlexandria()`: `maxOutputTokens 512 -> 800`, temperature 0.6 -> 0.7.',
    '- System prompt now instructs "Be concise but COMPLETE. Never cut a sentence mid-thought." so the model wraps up its paragraph before exhausting the token budget.',
    '',
    '### 3. Launcher icon - safe-zone fixed',
    '- `tools/setup_adaptive_icon.ps1` now generates a 432x432 foreground PNG with the 280x280 logo centered, leaving a 76px transparent padding on every side (= 19dp safe zone at xxxhdpi). Android system masks can crop up to 19dp from each edge without losing the logo detail.',
    '- Background drawable is a brand-matched amber -> red -> indigo gradient (`drawable/ic_launcher_background.xml`).',
    '- Legacy mipmap PNGs regenerated for mdpi / hdpi / xhdpi / xxhdpi / xxxhdpi.',
    '',
    '### 4. Hotels are first-class Places',
    '- 12 hand-curated Alexandria hotels (Four Seasons, Sofitel Cecil, Steigenberger, Tolip, Paradise Inn, Romance, Cherry Maryski, Plaza, King Mariout, San Stefano, Downtown, Borg El Arab) are now promoted to full `PlaceModel` instances.',
    '- They show up in the Home list, can be saved / check-inned, and open the standard Place Details screen - same treatment as Qaitbay Citadel or the Library of Alexandria.',
    '- The "Hotels" filter chip on the map is still opt-in (purple) so the default map stays uncluttered.',
    '',
    '### 5. ATM markers - interactive bottom sheet',
    '- Tapping an ATM marker now opens a polished bottom sheet (new `_atm_sheet.dart`) showing the bank brand (CIB, NBE, Banque Misr, QNB, Alex Bank, HSBC, Cairo Bank, Faisal, Arab Bank, AAIB), the branch name, and the address.',
    '- A prominent **Get Directions** button hands off to Google Maps with `LaunchMode.externalApplication` via `url_launcher`.',
    '',
    '## Build',
    '- Target: arm64 only.',
    '- Release-signed with existing `release.keystore`.',
    '- SHA-1 (release): 7B50DDF11B43552D6954B5AA19DF2AE9D415217E',
    '- SHA-256 (release): 2D310D3DB00CCA001E9898047A9F6B77FD475E6D65379B92DE01B250509DA32D',
    '- `flutter analyze`: 0 issues.'
)
$releaseBody = $lines -join "`n"

$payload = @{
    tag_name = $tag
    name = 'v1.0.21 - profile counters fix, AI no-truncate, icon safe-zone, hotels as places, ATM bottom sheet'
    body = $releaseBody
    draft = $false
    prerelease = $false
} | ConvertTo-Json -Depth 10 -Compress

Write-Host "Checking existing release $tag..."
try {
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/mohamedsabae50-prog/streetlore/releases/tags/$tag" -Headers $headers
    Write-Host "Found existing release id=$($release.id) url=$($release.html_url)"
} catch {
    Write-Host "Creating new release..."
    $payloadPath = Join-Path $env:TEMP 'streetlore_release_payload.json'
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($payloadPath, $payload, $utf8)
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/mohamedsabae50-prog/streetlore/releases" -Method Post -Headers $headers -InFile $payloadPath -ContentType "application/json; charset=utf-8"
    Write-Host "Created release id=$($release.id) url=$($release.html_url)"
}

$uploadUrl = $release.upload_url -replace '\{.*$',''
Write-Host "Upload URL: $uploadUrl"

$apkPath = "D:\codes\streetlore\build\app\outputs\flutter-apk\$apkName"
if (-not (Test-Path $apkPath)) {
    throw "APK not found at $apkPath"
}
Write-Host "Uploading $apkPath..."

$uploadHeaders = @{
    "Authorization" = "Bearer $TOKEN"
    "Accept" = "application/vnd.github+json"
    "X-GitHub-Api-Version" = "2022-11-28"
    "User-Agent" = "streetlore-release-script"
    "Content-Type" = "application/vnd.android.package-archive"
}

$uploadUrlWithName = $uploadUrl + "?name=$apkName"
Write-Host "Final upload URL: $uploadUrlWithName"
Invoke-RestMethod -Uri $uploadUrlWithName -Method Post -Headers $uploadHeaders -InFile $apkPath -ContentType "application/vnd.android.package-archive"
Write-Host "Upload complete!"
Write-Host "Final URL: $($release.html_url)"
