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

$tag = "v1.0.22"
$apkName = "streetlore-v1.0.22-arm64.apk"

$lines = @(
    '## What is new in v1.0.22',
    '',
    '### 1. AI Tour Guide - 401 OAuth error fixed',
    '- `gemini_rest_client.dart`: removed the empty `Authorization` header that the gateway was parsing as a malformed Bearer token and returning `Expected OAuth 2 access token`. Auth now relies purely on the URL query parameter `?key=API_KEY`, which is the documented Google AI Studio REST format.',
    '',
    '### 2. State management - Check-ins & Counters persist to the DB',
    '- `SupabaseService` gained three new helpers: `pushSavedPlace`, `deleteSavedPlace`, and `registerCheckin`. `PlaceProvider.toggleSave` now mirrors every save / unsave to `saved_places` so the list survives logout, reinstall, or device switch.',
    '- `GamificationProvider.applyAction(''check_in'', placeId: ...)` now records a `place_checkins` row in addition to the leaderboard upsert, so the "Explored" counter is sourced from the database on every app start, not just SharedPreferences.',
    '- `bootstrapForUser(userId)` in both providers is called on every auth change from `main.dart` and MERGES remote with local, so a fresh install hydrates real numbers on first launch.',
    '',
    '### 3. Map - All filter is now toggleable',
    '- Tapping the All chip when it is currently active drops to a `__none__` sentinel and renders ZERO pins (the map can be completely empty). Tapping again brings everything back.',
    '- The Hotels category marker now uses `Icons.bed_rounded` (purple `#6A1B9A`) instead of the generic location pin, so hotels are clearly distinct from historical places.',
    '- The `Streets` category was removed app-wide (it was the source of redundant keywords in the AI service).',
    '',
    '### 4. Home screen - Discover above filters, Offline removed',
    '- The Discover grid (Map / Ranking / Badges / Routes) now sits ABOVE the horizontal category filter chips, so users see shortcuts first and the city listing second.',
    '- The Offline circular button was removed from Discover. Offline is now a per-place action (see below).',
    '- The `Streets` filter was replaced with `Hotels` (`Icons.bed_rounded`, EN/AR).',
    '',
    '### 5. Place Details - "Download for Offline" button',
    '- A fourth Quick Action (`cloud_download_outlined` / `cloud_done_rounded`) sits next to Save / Check-in / Go.',
    '- `OfflineProvider.downloadSinglePlace(place)` caches the JSON blob via Hive AND prefetches the hero image into the disk cache used by `CachedNetworkImage`.',
    '- Tapping again removes the cached entry. The button reflects state (`Download for Offline` <-> `Downloaded`) via a `Consumer<OfflineProvider>`.',
    '',
    '### 6. Geofencing & toggles',
    '- `GeofenceProvider.toggle` already persists to SharedPreferences and re-syncs the foreground service. Toggle state survives cold starts.',
    '',
    '### 7. Auth - Google-only, no manual name',
    '- `login_screen.dart` removed the email/password form, the sign-up toggle, and any manual "Name" input field. The only entry point is the Google button.',
    '- `AuthProvider._syncFromSupabase` extracts the display name automatically from the Google profile (`full_name` -> `name` -> email local-part).',
    '',
    '## Build',
    '- Target: arm64 only.',
    '- Release-signed with existing `release.keystore`.',
    '- SHA-1 (release): 0B075C83885D37E3DCBFB80B3C08D3DBA2EE35BC',
    '- SHA-256 (release): 4BCE3E7C3C9FFE8A2437EB1FBEE03E8310D28F3F1453AFE3CA13CC2DA972E4EB',
    '- `flutter analyze`: 0 issues.'
)
$releaseBody = $lines -join "`n"

$payload = @{
    tag_name = $tag
    name = 'v1.0.22 - AI 401 fix + DB-persisted counters/check-ins + map toggle + per-place offline + Google-only auth'
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
