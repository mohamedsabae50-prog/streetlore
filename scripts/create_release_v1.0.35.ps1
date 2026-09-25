$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class CredMan {
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
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

$tag = "v1.0.35"
$apkName = "streetlore-v1.0.35-arm64.apk"

$lines = @(
    '## What is new in v1.0.35 - Gemini `1.5-flash-latest` + Real Supabase error',
    '',
    '### 1. Gemini 1.5-flash-latest (fixes 404 NOT_FOUND)',
    '- `AppConfig.geminiModel` switched from `gemini-1.5-flash` to `gemini-1.5-flash-latest`.',
    '- The bare `gemini-1.5-flash` alias is being rolled off the Gemini Developer API v1beta endpoint and started returning `404 NOT_FOUND: models/gemini-1.5-flash is not found for API version v1beta`.',
    '- `gemini-1.5-flash-latest` is the documented pointer that always resolves to the latest stable 1.5-Flash build on v1beta, so it does not 404.',
    '- Full URL: `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=...`.',
    '- 5-key rotation from v1.0.34 preserved unchanged (401/403/429/5xx/timeouts rotate, 400/404 surface immediately to protect quota).',
    '',
    '### 2. Real Supabase error in the red SnackBar',
    '- `SupabaseService.registerCheckin` now returns `({bool ok, PostgrestException? error})` - a Dart record - instead of a bare `bool`. The PostgrestException (when present) carries the EXACT server message (`new row violates row-level security policy`, `column "xyz" does not exist`, etc.).',
    '- `GamificationProvider.lastCheckinError` is the new public String field. It holds `[code] message` (the Supabase error code in brackets + the human-readable message) right after a failed insert, and is cleared automatically at the start of the next check-in attempt (and by the new `clearCheckinError()` method).',
    '- `place_details_screen.dart` drives the red SnackBar off `gamification.lastCheckinError != null` instead of the old `checkInResult == null` test (which fired on every normal check-in because `applyAction` returns null when no badge is earned). Real failures now show `"Check-in failed: [PGRST116] new row violates row-level security policy for table place_checkins"` so you know immediately whether to look at the RLS policies or the column types.',
    '- The optimistic local bump (`PlaceProvider.bumpLocalCheckinCount`) is now skipped when `lastCheckinError` is set, so the "Explored" counter never goes above the real persisted count.',
    '- `place_checkins` insert payload was unchanged from v1.0.22: `{user_id, place_id, checked_in_at}` only. No typo''d / extra keys can trip a "column does not exist" error.',
    '',
    '### Working mechanics preserved (per handover rules)',
    '- Authentication: Google OAuth + Supabase (v1.0.30 Web Client ID + same keystore), unchanged.',
    '- Hotels markers: `onTap` wired to `_SelectedPlaceCard` (v1.0.33), unchanged.',
    '- Gemini 5-key rotation (v1.0.34 _shouldRotateKey classifier), unchanged.',
    '- Instant counter optimistic bumps (v1.0.34), unchanged on success path.',
    '- R8 / ProGuard still disabled (`isMinifyEnabled = false`).',
    '',
    '## Build',
    '- Target: arm64 only.',
    '- Release-signed with `android/app/release_v2.keystore` (alias `streetlore`, SHA-1 `AF:62:89:44:B5:F3:A0:0A:4E:CE:1E:72:34:13:26:EA:5A:E7:B4:8F`).',
    '- `flutter analyze`: 0 issues.',
    '- `--dart-define=GEMINI_API_KEYS=<5 keys>` (kept out of source).',
    '- Tag force-pushed (`git push origin v1.0.35 --force`).'
)
$releaseBody = $lines -join "`n"

$payload = @{
    tag_name = $tag
    name = 'v1.0.35 - Gemini 1.5-flash-latest + Real Supabase error'
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
