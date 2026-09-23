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

$tag = "v1.0.20"
$apkName = "streetlore-v1.0.20-arm64.apk"

$lines = @(
    '## What is new in v1.0.20',
    '',
    '### 1. Launcher icon - adaptive, properly sized',
    '- Added `mipmap-anydpi-v26/ic_launcher.xml` adaptive icon definition.',
    '- Background drawable is a brand-matched gradient (amber -> red -> indigo).',
    '- Foreground is the 1024x1024 logo - no excessive empty margins.',
    '- Legacy mipmap PNGs kept for pre-O launchers.',
    '',
    '### 2. Offline Download - real fix for 0 Places',
    '- Root cause: `OfflineProvider.pullAllPlacesFromSupabase()` was parsing rows with `PlaceModel.fromJson` (camelCase) but Supabase returns snake_case. Every row threw and the list came back empty.',
    '- Extracted a top-level `placeModelFromSupabaseRow()` helper that accepts both snake_case and camelCase and uses safe defaults. `PlaceProvider._placeFromSupabase` and `OfflineProvider.pullAllPlacesFromSupabase` both delegate to it.',
    '- Added detailed error logging so a future regression is visible in `adb logcat`.',
    '',
    '### 3. Authentication - Google only',
    '- Removed the "Continue as Guest" link and its helper `_continueAsGuest` / `_askGuestName` from `login_screen.dart`.',
    '- Login is now strictly via Google (Gmail).',
    '',
    '### 4. Home FAB - General AI Tour Guide',
    '- New `FloatingActionButton.extended` "AI Tour Guide" pinned to the bottom-right of the Home screen.',
    '- Opens `GeneralAITourGuideScreen`: a free-form Alexandria-only chat with a tight system prompt that politely declines any non-tourism topic (coding / math / general chat) to save tokens.',
    '- Uses the same 4-key Gemini 3.6 Flash rotation as the rest of the app.',
    '',
    '### 5. Map - opt-in ATM layer',
    '- New `ATMs` filter chip (green). OFF by default to keep the map uncluttered.',
    '- 12 hand-curated ATMs across CIB / NBE / Banque Misr / QNB / Alex Bank / HSBC / Cairo Bank / Faisal / Arab Bank / AAIB.',
    '- Each marker uses its bank brand color + the ATM icon.',
    '',
    '### 6. Map - Hotels as POI',
    '- New `Hotels` filter chip (purple). OFF by default.',
    '- 12 well-known Alexandria hotels (Four Seasons, Sofitel Cecil, Steigenberger, Tolip, Paradise Inn, Romance, Cherry Maryski, Plaza, King Mariout, San Stefano, Downtown, Borg El Arab).',
    '- 4/5 star icons for the upscale entries, plain hotel icon for the 3-star properties.',
    '',
    '### 7. Profile - counters fixed + banner rewritten',
    '- `GamificationProvider.bootstrapForUser` now MERGES instead of REPLACING: counters and points take MAX(local, remote), badges are unioned. A local increment made before Supabase sync no longer gets wiped on next sign-in.',
    '- Level is recomputed from merged points via `GamificationStats.levelForPoints`.',
    '- The "Everything is free" banner was moved from the top (right under counters) down below the streak and achievements sections, and its copy changed to "A non-profit passion project" / "Built out of love for Alexandria" so the screen tells the real story.',
    '',
    '### 8. Help Center - new support email',
    '- `help_contact` now reads `mohamedsabe50@gmail.com` in both EN and AR. Verified in `app_strings.dart`, `app_en.arb`, `app_ar.arb`, and the generated `app_localizations*.dart` files.',
    '',
    '## Build',
    '- Target: arm64 only.',
    '- Release-signed with existing `release.keystore`.',
    '- SHA-1 (release): 7FFC06A1A3D5006B5B471BF977F8507923498790',
    '- SHA-256 (release): 816344E917F358A8684A59172A0B70925D3E6326BBE680D228707229AC4A93BB',
    '- `flutter analyze`: 0 issues.'
)
$releaseBody = $lines -join "`n"

$payload = @{
    tag_name = $tag
    name = 'v1.0.20 - offline real fix, AI FAB, ATMs/Hotels map, profile counters + new banner'
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
