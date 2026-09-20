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

$tag = "v1.0.14"
$apkName = "streetlore-v1.0.14-arm64.apk"

$lines = @(
    '## What is new in v1.0.14',
    '',
    '### 1. Sign-out now fully wipes the session',
    '- `signOut()` now calls `Supabase.auth.signOut()` first (clears the',
    '  server-side session + the Supabase SharedPreferences key), then',
    '  removes every mirrored key (`sb_access_token`, `sb_refresh_token`,',
    '  `sb_expires_at_s`, etc.), then sweeps any remaining `sb-*` keys,',
    '  AND clears the user identity keys (`user_name`, `user_email`,',
    '  `user_id`) so the next cold start has no path to auto-restore.',
    '- You can now switch accounts reliably.',
    '',
    '### 2. Daylight calculation fixed (was "Sunrise 00:53, Sunset 00:53, 24h")',
    '- Bug: `halfMinutes = h * 60` (treating degrees as hours).',
    '- Fix: `halfMinutes = h * 4` (1 degree = 4 minutes — earth rotates',
    '  360 degrees in 24 hours).',
    '- Added NOAA-style altitude target (-0.833 degrees) for refraction',
    '  + solar disc and a proper `cosH` formula.',
    '- Solar-noon normalization handles any timezone offset.',
    '',
    '### 3. Admin "Best Time to Visit" override',
    '- Added `best_time_to_visit` text field on the Place form. The admin',
    '  can set the exact recommendation label (e.g. "Morning", "Sunset",',
    '  "Late Night") and the Best Time screen displays it verbatim instead',
    '  of computing one.',
    '- Added quick-set chips (Early Morning, Morning, Midday, Afternoon,',
    '  Sunset, Evening, Night, Late Night) for one-tap filling.',
    '- Wired through both Place models + JSON serialization.',
    '',
    '### 4. Gemini API - raw REST call with key rotation',
    '- Replaced the `google_generative_ai` SDK with a hand-written REST',
    '  client using `https://generativelanguage.googleapis.com/v1beta/models/{m}:generateContent?key=API_KEY`.',
    '  This eliminates any SDK-side Bearer-token formatting that caused the',
    '  "Expected OAuth 2 access token" error.',
    '- Configured 4 Gemini keys. The client rotates through them on 4xx/',
    '  timeout, so a single revoked or rate-limited key never breaks the',
    '  feature.',
    '- Keys are injected at build time via `--dart-define=GEMINI_API_KEYS=k1,k2,k3,k4`',
    '  so the source repository stays clean of secrets (GitHub push',
    '  protection no longer blocks uploads).',
    '- The chat surfaces real errors: HTTP 400 (bad model/key), 401/403',
    '  (auth denied), 404 (model not found), 429 (rate limited), timeout,',
    '  DNS failure.',
    '',
    '## Build',
    '- Target: arm64 only (`--split-per-abi --target-platform android-arm64`).',
    '- Release-signed with existing `release.keystore`.',
    '- SHA-1 (release): 70:83:CF:1D:21:86:FC:35:65:94:05:B8:C5:4A:DD:A4:E5:31:AE:7D',
    '- `flutter analyze`: 0 issues.'
)
$releaseBody = $lines -join "`n"

$payload = @{
    tag_name = $tag
    name = 'v1.0.14 - 4 critical fixes (sign out, daylight math, admin best time, Gemini REST)'
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
