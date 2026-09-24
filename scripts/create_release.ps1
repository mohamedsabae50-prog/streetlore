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

$tag = "v1.0.25"
$apkName = "streetlore-v1.0.25-arm64.apk"

$lines = @(
    '## What is new in v1.0.25 - PHASE 1 (logic + state + API hardening)',
    '',
    'No UI changes in this release - Home Screen, Map Screen, and Offline UI are unchanged. Only backend, state management, and the API client were tightened.',
    '',
    '### 1. Gemini API (CRITICAL) - exact endpoint + visible URL',
    '- `gemini_rest_client.dart` calls `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent?key=API_KEY`.',
    '- The key travels ONLY in the URL query string - no `Authorization` / Bearer header is ever sent.',
    '- For triaging the 401 error: every request now logs `API URL: <full URL>` to logcat via `debugPrintGemini(''API URL: $uri'')` before the HTTP send, so the exact endpoint can be verified in `adb logcat`.',
    '',
    '### 2. Supabase silent failure - root cause + fix',
    '**Root cause**: `PlaceProvider.toggleSave` and `GamificationProvider.applyAction(''check_in'', ...)` were calling Supabase as fire-and-forget without `await`. The local UI state was updated and `notifyListeners()` fired BEFORE the network round-trip. If the insert failed (RLS, expired token, network), the failure was logged to `debugPrint` inside `SupabaseService` but no one in the call chain was listening, so the check-in/save "disappeared" after a screen exit and the next bootstrap re-pulled 0 from the database.',
    '',
    '**Fix**:',
    '- `toggleSave` now `await`s the Supabase write, wraps it in `try/catch`, prints the exact success / failure (`debugPrint(''PlaceProvider.toggleSave: Supabase write OK placeId=...'')` or `error: ...`), and fires a **second** `notifyListeners()` AFTER the DB write so the UI reflects the DB source of truth.',
    '- `applyAction(''check_in'', placeId: ...)` got the same treatment around `registerCheckin`.',
    '- All RLS / token errors now surface in logcat instead of being silently swallowed.',
    '',
    '### 3. Geofencing - already correct from v1.0.24',
    '- `GeofenceProvider._load()` re-arms `GeofencingService` after hydrating alerts from SharedPreferences, so the background location stream resumes automatically after a cold start.',
    '- `GeofenceProvider.toggle / remove / updateRadius` persist every change to SharedPreferences and re-sync the service. Empty alert list -> `stop()` cancels the position stream.',
    '',
    '### 4. Google Sign-in - name comes from Google profile, no manual input',
    '- `login_screen.dart` exposes only email + password fields. No First Name / Last Name inputs.',
    '- `AuthProvider._syncFromSupabase` reads `user.userMetadata[''full_name'']` -> `name` -> email-local-part -> `Explorer`. The Google OAuth response puts `displayName` into `full_name`, so the app maps the Google profile name directly without ever asking the user.',
    '',
    '## Build',
    '- Target: arm64 only.',
    '- Release-signed with existing `release.keystore`.',
    '- SHA-1 (release): EA4193852AEFA998DDE5B82C5AD8D2E934278DF3',
    '- SHA-256 (release): CB241A76066C227F778E03A4F9D1F33E9BD2484876DAF391DF4499B8C370BFD0',
    '- `flutter analyze`: 0 issues.'
)
$releaseBody = $lines -join "`n"

$payload = @{
    tag_name = $tag
    name = 'v1.0.25 - Phase 1: awaited Supabase writes + API URL log + Google-only name (no UI changes)'
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
