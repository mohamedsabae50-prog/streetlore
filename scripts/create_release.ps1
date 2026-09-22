$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class CredMan {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct CREDENTIAL {
        public UInt32 Flags;
        public UInt32 Type;
        public IntPtr TargetName;
        public IntPtr Comment;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
        public UInt32 CredentialBlobSize;
        public IntPtr CredentialBlob;
        public UInt32 Persist;
        public UInt32 AttributeCount;
        public IntPtr Attributes;
        public IntPtr TargetAlias;
        public IntPtr UserName;
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

$tag = "v1.0.18"
$apkName = "streetlore-v1.0.18-arm64.apk"

$lines = @(
    '## What is new in v1.0.18',
    '',
    '### 1. Offline Download is now real (CRITICAL fix)',
    '- `OfflineProvider.download()` runs two phases: (a) persists',
    '  every place JSON to Hive, then (b) calls',
    '  `DefaultCacheManager().downloadFile()` for each image so the',
    '  `CachedNetworkImage` widget can render offline.',
    '- `PlaceProvider.loadPlaces()` now falls back to',
    '  `OfflineProvider.cachedFallback` (real Hive-cached places) when',
    '  Supabase times out, instead of the mock `fallbackPlaces`.',
    '- `flutter_cache_manager: ^3.4.1` added explicitly to pubspec.',
    '- Removed the fake 600 ms `Future.delayed` from the download flow.',
    '- Download UI now reports real progress (`done/total places +`,
    '  `images ok/failed`) and the final snack bar includes image counts.',
    '',
    '### 2. AI Trip Planner — strict database grounding',
    '- The system prompt now injects `id`, `name`, `category`,',
    '  `description`, `address`, `bestTimeToVisit`, `isIndoor`, `lat`,',
    '  `lng` for every available place — not just the id+category.',
    '- Added explicit per-vibe rules: "sea" must match a place whose',
    '  category is `Nature` or `Beach` and whose description mentions',
    '  sea/corniche/coast. Same for fish/seafood, history, mosques, etc.',
    '- AI is now forbidden from inventing placeIds.',
    '- `PlaceProvider._placeFromSupabase` now also parses `name_ar`,',
    '  `description_ar`, `category_ar`, `address_ar`, `price_note_ar`,',
    '  `best_time_note`, `best_time_to_visit`, and `is_indoor` so the',
    '  AI prompt and the UI see the full Arabic + admin fields.',
    '',
    '### 3. Profile counters — Tours formula corrected',
    '- "Tours" was incorrectly `savedTours.length + placesVisited`',
    '  (two unrelated metrics). Now it is just `tourP.savedTours.length`.',
    '- `Saves` / `Explored` / `Tours` all rebuild via `context.watch` so',
    '  toggling a save or visiting a place updates the counter live.',
    '',
    '### 4. Best Time moved + redesigned',
    '- Home Screen quick action for "Best Time" is removed (it was a',
    '  duplicate of the dedicated screen anyway).',
    '- The Place Details "Best Time" badge is now a hero-style gradient',
    '  card (amber → red) with the admin-entered label rendered at 22 pt',
    '  bold, a CURATED pill, and a 18 px blur shadow. It sits at the top',
    '  of the body, right after the Save/Go quick actions.',
    '- `best_time_admin_hint` l10n key wired through EN + AR.',
    '',
    '### 5. New brand logo',
    '- New `assets/logo/streetlore_logo.png` (1024×1024) showing the open',
    '  book + road + location-pin + stars motif.',
    '- Splash screen renders the asset inside a 150 px circular ClipOval',
    '  with the existing pulse/scale/orbit animations around it.',
    '- Login screen renders the asset inside the rounded gradient square',
    '  that previously held the `explore_rounded` icon.',
    '- All Android launcher densities regenerated from the same source:',
    '  mdpi (48) → hdpi (72) → xhdpi (96) → xxhdpi (144) → xxxhdpi (192).',
    '- `pubspec.yaml` `assets:` section now declares the logo.',
    '',
    '## Build',
    '- Target: arm64 only (`--split-per-abi --target-platform android-arm64`).',
    '- Release-signed with existing `release.keystore`.',
    '- SHA-1 (release): 27B21C426A09FC90AE4B3A1E2C82E09D7E9B9994',
    '- SHA-256 (release): F2C0ACF9385B55D24153FAB1EBA7E4FBACAE914D62FA834439CAC47FCBFECC4E',
    '- `flutter analyze`: 0 issues.'
)
$releaseBody = $lines -join "`n"

$payload = @{
    tag_name = $tag
    name = 'v1.0.18 - Offline Download real, AI grounded, counters wired, new brand logo'
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
