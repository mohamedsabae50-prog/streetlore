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

$tag = "v1.0.24"
$apkName = "streetlore-v1.0.24-arm64.apk"

$lines = @(
    '## What is new in v1.0.24 - PHASE 1 (logic + state only)',
    '',
    'Phase 1 keeps the Home Screen UI, Map UI, and Offline UI untouched. Only backend / state / API plumbing was hardened.',
    '',
    '### 1. AI 401 Authentication (CRITICAL) - already correct from v1.0.22',
    '- `gemini_rest_client.dart` uses the standard Google AI Studio REST endpoint `https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key=API_KEY`.',
    '- No `Authorization` / Bearer header is ever sent - the empty header that triggered the 401 was removed.',
    '',
    '### 2. State management - Check-ins & Profile counters (already correct from v1.0.22, verified in v1.0.24)',
    '- `SupabaseService.pushSavedPlace` / `deleteSavedPlace` / `registerCheckin` are called from `PlaceProvider.toggleSave` and `GamificationProvider.applyAction(''check_in'', placeId: ...)` respectively, so saves and check-ins hit the database permanently.',
    '- `bootstrapForUser(userId)` in `PlaceProvider` and `GamificationProvider` is invoked from `main.dart` on every auth state change. It MERGES local with remote and hydrates the Profile counters on cold start, so Saved / Explored / Tours are real numbers, not zeros.',
    '',
    '### 3. Geofencing & toggles (NEW hardening in v1.0.24)',
    '- `GeofenceProvider._load()` now calls `_syncService()` after hydrating `_alerts` from SharedPreferences. The background location stream is automatically re-armed if any persisted alerts are still enabled - previously the position stream only resumed when the user manually opened the Geofencing settings screen.',
    '- `GeofenceProvider.toggle` / `remove` / `updateRadius` already persist every change to SharedPreferences and call `_syncService()` to push the new alert set into `GeofencingService`. `setAlerts` is smart: empty list -> `stop()` (cancels position stream), non-empty list without active stream -> requests permission and starts streaming.',
    '- `startMonitoring` / `stopMonitoring` cleanly start and stop the position subscription.',
    '',
    '### 4. Google Sign-in flow (already correct from v1.0.22)',
    '- `AuthProvider._syncFromSupabase` extracts the display name from the Google profile: `full_name` -> `name` -> email local-part -> `Explorer`. No manual Name input is ever requested.',
    '',
    '## Build',
    '- Target: arm64 only.',
    '- Release-signed with existing `release.keystore`.',
    '- SHA-1 (release): 0405BEF3235CF5AE4744AF06510DD2CDEF3F43B3',
    '- SHA-256 (release): 0AD6D5588C878191603A726AFCA94FEBFB0BEE07B85F94B333BD856252FF3580',
    '- `flutter analyze`: 0 issues.'
)
$releaseBody = $lines -join "`n"

$payload = @{
    tag_name = $tag
    name = 'v1.0.24 - Phase 1: harden AI 401, DB persistence, geofencing auto-resume, Google-only name (no UI changes)'
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
