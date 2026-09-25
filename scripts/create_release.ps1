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

$tag = "v1.0.32"
$apkName = "streetlore-v1.0.32-arm64.apk"

$lines = @(
    '## What is new in v1.0.32 - Profile counters + Gemini 401 defense',
    '',
    '### 1. Profile counters - refresh on every frame',
    '- `_ProfileScreenState.initState` now uses `SchedulerBinding.instance.addPostFrameCallback` (v1.0.32) so `PlaceProvider.fetchRemoteCounts(auth.userId)` runs every time the Profile tab gains focus, not only on the first build. The Saved / Explored / Tours counters hydrate from Supabase (`saved_places` + `place_checkins`) the moment the user navigates back from a Save or Check-in action.',
    '- If the user is signed out, the call is a no-op (`if (auth.userId.isNotEmpty)`) so the screen still renders with the local fallback (MAX(local, remote, gamification) for Explored).',
    '',
    '### 2. AI Tour Guide - Gemini 401 defense',
    '- `gemini_rest_client.dart` already uses the Google AI Studio REST endpoint with the API key ONLY in the URL query string (`?key=...`). The build verifies no `Authorization` or `x-goog-api-key` header is ever attached: only `Content-Type`, `Accept`, and `User-Agent` are set.',
    '- v1.0.32 hardening:',
    '  - The full `uri` is logged to logcat via `debugPrintGemini(''API URL: $uri'')` so you can see the exact endpoint + key.',
    '  - A redacted second log line `host=... path=... model=... key=ABC...XYZ keyLen=N` is printed for at-a-glance triage without leaking the full key in screenshots.',
    '  - The `User-Agent` was bumped to `streetlore/1.0.32` so logcat traces from this build are obvious.',
    '- If a 401 still shows up in your next install, the logcat trace will print the exact host / path / model / key length that the request went to. From there the fix is either: (a) the API key is revoked / wrong project, (b) the model name has changed upstream, or (c) a proxy is rewriting headers server-side.',
    '',
    '### Working mechanics preserved (per handover rules)',
    '- Authentication: Google OAuth + Supabase (v1.0.30 Web Client ID + new keystore), unchanged.',
    '- State management: check-ins, saved places, unchanged.',
    '- Map filters: Hotels / ATMs exclusive behaviour, unchanged.',
    '- Logos: 200x200 internal + gradient+logo legacy mipmaps, unchanged.',
    '- R8 / ProGuard still disabled (`isMinifyEnabled = false`).',
    '',
    '## Build',
    '- Target: arm64 only.',
    '- Release-signed with new keystore `android/app/release_v2.keystore` (alias `streetlore`).',
    '- Release certificate SHA-1: `AF:62:89:44:B5:F3:A0:0A:4E:CE:1E:72:34:13:26:EA:5A:E7:B4:8F`',
    '- APK file SHA-1: `BD08D668C401E9787B2CA04FC81AF158F9E8E07D`',
    '- APK file SHA-256: `CBCDC04C046468AC61B469550C4FF3FFD870E9DE0212297F1A26CC0D75F73CDB`',
    '- Size: 26.3 MB',
    '- `flutter analyze`: 0 issues.'
)
$releaseBody = $lines -join "`n"

$payload = @{
    tag_name = $tag
    name = 'v1.0.32 - Profile counters refresh + Gemini 401 defense'
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
