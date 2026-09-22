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

$tag = "v1.0.19"
$apkName = "streetlore-v1.0.19-arm64.apk"

$lines = @(
    '## What is new in v1.0.19',
    '',
    '### 1. Profile counters now reflect real data (CRITICAL fix)',
    '- PlaceProvider / GamificationProvider / TourProvider now expose a `bootstrapForUser(userId)` method that pulls the latest rows from Supabase on sign-in.',
    '- `PlaceProvider.loadPlaces()` now seeds itself from the Hive offline cache immediately so the home list is never empty while Supabase is still loading.',
    '- `findById()` falls back to `OfflineProvider.cachedFallback` when the in-memory list does not have the place, so opening a place offline works even before the network round-trip completes.',
    '- A `bootstrapFromSupabase(userId)` hook in `main.dart` listens to `AuthProvider` and triggers every provider as soon as the user id is available.',
    '',
    '### 2. Achievement localization keys (CRITICAL fix)',
    '- All 23 `ach_*_name` and `ach_*_desc` keys are now defined in `app_en.arb`, `app_ar.arb`, `app_strings.dart`, and the generated `app_localizations*.dart` files.',
    '- The badge name on the Profile / Achievements screen now resolves to a real translated string instead of leaking the raw key.',
    '',
    '### 3. Logo size doubled',
    '- Splash screen logo: 150 px -> 220 px.',
    '- Login screen logo: 86 px -> 160 px (with a 32 px blur shadow and a 36 px rounded corner).',
    '',
    '### 4. AI Trip Planner removed',
    '- `presentation/screens/ai_trip_generator_screen.dart` deleted.',
    '- The "AI Trip" quick action and its import are removed from `home_screen.dart`.',
    '- The place-specific AI Tour Guide chatbot and the AI Tour Guide screen are kept untouched.',
    '',
    '### 5. Offline Download rewritten (CRITICAL fix)',
    '- `OfflineModeScreen._onDownload` waits for `PlaceProvider.ensureLoaded()` before triggering the download.',
    '- If `PlaceProvider.places` looks suspiciously small (< 5), it now pulls the full list directly from Supabase via the new `OfflineProvider.pullAllPlacesFromSupabase()` method.',
    '- Per-place snackbar spam removed — only the final success / failure toast is shown.',
    '- Final toast: green background, 4-second duration, "Saved N places • M images cached offline".',
    '- `PlaceProvider` falls back to the Hive offline cache when Supabase times out instead of mock data; the seed is applied before the network call so the home list is ready immediately.',
    '- `RobustImage` now reads from `DefaultCacheManager` first and falls back to a live network fetch only when no disk cache entry exists. The Offline Download flow prefetches the same cache, so images render offline.',
    '',
    '### 6. Admin Panel deployed to GitHub Pages',
    '- `streetlore_admin` builds with `flutter build web --release --no-source-maps --base-href /streetlore-admin/` and is force-pushed to the `gh-pages` branch.',
    '- Live URL: https://mohamedsabae50-prog.github.io/streetlore-admin/',
    '- Place form already has the EN card (blue border) + AR card (green border) and an inline "Best Time to Visit" text field in the Identification section.',
    '',
    '## Build',
    '- Target: arm64 only.',
    '- Release-signed with existing `release.keystore`.',
    '- SHA-1 (release): 92829BA6A116DF621BEBDDF330D8830DC04B19EC',
    '- `flutter analyze`: 0 issues.'
)
$releaseBody = $lines -join "`n"

$payload = @{
    tag_name = $tag
    name = 'v1.0.19 - Offline download real, profile counters from Supabase, achievement i18n fixed'
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
