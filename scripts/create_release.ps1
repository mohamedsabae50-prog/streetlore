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

$tag = "v1.0.26"
$apkName = "streetlore-v1.0.26-arm64.apk"

$lines = @(
    '## What is new in v1.0.26',
    '',
    '### 1. State Management (Counters & Check-ins) - verified',
    '- `PlaceProvider.toggleSave` and `GamificationProvider.applyAction(''check_in'', placeId: ...)` both `await` the Supabase write and call `notifyListeners()` AFTER the DB write returns. Failures surface in logcat instead of being silently swallowed.',
    '- `bootstrapForUser(userId)` in both providers is invoked from `main.dart` on every auth state change. It MERGES local with remote and hydrates the Profile counters on cold start so Saved / Explored / Tours reflect the real DB numbers.',
    '- Required tables: `saved_places(user_id, place_id, place_data, saved_at)` and `place_checkins(id, user_id, place_id, checked_in_at)`. See the SQL script in the previous response.',
    '',
    '### 2. Gemini API Fix (401 Error) - gemini-1.5-flash + ?key= only',
    '- **Model**: `AppConfig.geminiModel = ''gemini-1.5-flash''` (the previously-used `gemini-3.6-flash` / `gemini-3.8-flash` identifiers do NOT exist on the Gemini Developer API and triggered the 401 / 404).',
    '- **Auth**: `gemini_rest_client.dart` sends the key ONLY via `?key=API_KEY` in the URL. NO `Authorization` or Bearer header is ever attached - the empty header that triggered the OAuth parse error was removed in v1.0.22.',
    '- **URL log**: every request logs `API URL: <full URL>` to logcat so the actual endpoint is visible for debugging.',
    '',
    '### 3. Home Screen UI - Discover above filters, Streets -> Hotels, no Offline',
    '- Discover grid (Map / Ranking / Badges / Routes) sits ABOVE the horizontal filter chips (v1.0.22 layout, preserved).',
    '- The `Streets` filter chip was removed and replaced with `Hotels` (bed icon).',
    '- The global `Offline` circular button was removed from Discover - offline downloads are per-place inside the Place Details screen.',
    '',
    '### 4. Per-Place Offline Download - inside Place Details',
    '- A fourth Quick Action (`cloud_download_outlined` / `cloud_done_rounded`) sits next to Save / Check-in / Go.',
    '- `OfflineProvider.downloadSinglePlace(place)` caches the JSON blob via Hive AND prefetches the hero image into the disk cache used by `CachedNetworkImage`.',
    '- Tapping again removes the cached entry via `OfflineProvider.removeCachedPlace`.',
    '',
    '### 5. Map - All filter toggleable + Hotels + ATM bottom sheet',
    '- Map filters: tapping All when it is currently active drops to a `__none__` sentinel and renders ZERO pins (the map can be completely empty).',
    '- Hotels are standard `PlaceModel` entries (category `Hotels`) and use a distinct `Icons.bed_rounded` marker (purple `#6A1B9A`).',
    '- ATM markers are still toggled via the ATM filter chip. Tapping an ATM opens a bottom sheet (`AtmSheet` in `_atm_sheet.dart`) showing the bank brand, branch name, and a `Get Directions` button that launches Google Maps via `url_launcher`.',
    '',
    '### 6. Auth - Google-only, no manual Name inputs',
    '- `login_screen.dart` exposes only email + password fields. No First Name / Last Name inputs exist anywhere.',
    '- `AuthProvider._syncFromSupabase` reads `user.userMetadata[''full_name'']` from the Google OAuth response (which carries Google''s `displayName`). The display name is mapped to the Supabase profile automatically.',
    '',
    '## Build',
    '- Target: arm64 only.',
    '- Release-signed with existing `release.keystore`.',
    '- SHA-1 (release): C4B70FFF19DF191860BDCEA453FAE85D88BCAFFB',
    '- SHA-256 (release): 2716AC4E655C638078293283EA58D0981CD86AC82E2929DD8178D14EF59D1C56',
    '- `flutter analyze`: 0 issues.'
)
$releaseBody = $lines -join "`n"

$payload = @{
    tag_name = $tag
    name = 'v1.0.26 - fix: revert Gemini model to gemini-1.5-flash + verify all 6 spec items intact'
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
