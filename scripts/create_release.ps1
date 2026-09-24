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

$tag = "v1.0.23"
$apkName = "streetlore-v1.0.23-arm64.apk"

$lines = @(
    '## What is new in v1.0.23',
    '',
    '### Rollback + restore',
    'Restored the global **Offline** circular button on the Home Discover grid and the **email / password** login form (Google still works as the primary entry point). All seven surgical fixes from v1.0.22 are kept intact:',
    '',
    '### 1. AI Tour Guide - 401 OAuth error fixed',
    '- `gemini_rest_client.dart`: removed the empty `Authorization` header that the gateway parsed as a malformed Bearer token. Auth now relies purely on `?key=API_KEY` in the URL.',
    '',
    '### 2. State management - DB-persisted Check-ins & Counters',
    '- `SupabaseService` exposes `pushSavedPlace`, `deleteSavedPlace`, and `registerCheckin`. `PlaceProvider.toggleSave` mirrors every change to `saved_places` so the saved list survives logout / reinstall.',
    '- `GamificationProvider.applyAction(''check_in'', placeId: ...)` records a `place_checkins` row AND upserts the leaderboard, so the Explored counter hydrates from the database on every cold start.',
    '',
    '### 3. Map - All filter toggleable + Hotel/Bed icon',
    '- Tapping All when it is currently active drops to a `__none__` sentinel and renders ZERO pins. Tapping again brings everything back.',
    '- Hotels category marker now uses `Icons.bed_rounded` (purple `#6A1B9A`) instead of a generic location pin.',
    '- The `Streets` category was removed app-wide.',
    '',
    '### 4. Home - Discover above filters',
    '- Discover grid (Map / Ranking / Offline / Badges / Routes) now sits ABOVE the horizontal category filter chips.',
    '- The `Streets` filter chip was replaced with `Hotels` (`Icons.bed_rounded`).',
    '',
    '### 5. Place Details - "Download for Offline" button',
    '- A fourth Quick Action (`cloud_download_outlined` / `cloud_done_rounded`) sits next to Save / Check-in / Go.',
    '- `OfflineProvider.downloadSinglePlace(place)` caches the JSON blob via Hive AND prefetches the hero image into the disk cache used by `CachedNetworkImage`.',
    '',
    '### 6. Auth - Google primary, name auto-extracted',
    '- Google sign-in is the primary entry point. The display name is extracted automatically from the Google profile (`full_name` -> `name` -> email-local-part) in `AuthProvider._syncFromSupabase` - no manual Name input.',
    '- Email / password login was restored as a secondary option (v1.0.21 form, untouched).',
    '',
    '## Build',
    '- Target: arm64 only.',
    '- Release-signed with existing `release.keystore`.',
    '- SHA-1 (release): 34E6BEA453610E44C88CE4CFE24AF9BC51E082AD',
    '- SHA-256 (release): 9222F50B54A24C8CBE795DFD3353D6B1B0D327B4DBCEB16928F835974DA9F303',
    '- `flutter analyze`: 0 issues.'
)
$releaseBody = $lines -join "`n"

$payload = @{
    tag_name = $tag
    name = 'v1.0.23 - rollback: restore Offline + email/password; keep 7 surgical fixes (AI 401, DB persistence, map toggle, Hotels, per-place offline, Google-only name)'
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
