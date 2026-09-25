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

$tag = "v1.0.34"
$apkName = "streetlore-v1.0.34-arm64.apk"

$lines = @(
    '## What is new in v1.0.34 - Gemini 5-key rotation + Instant check-in counters',
    '',
    '### 1. Gemini Multi-Key Fallback (5-key rotation)',
    '- The Tour Guide now ships with 5 Gemini API keys (all 4 unique - one was provided twice).',
    '- The `GeminiRestClient` explicitly classifies what counts as a "this key is bad / exhausted" error:',
    '  - `401` (invalid / revoked key)',
    '  - `403` (forbidden - usually wrong model / project)',
    '  - `429` (quota / rate-limit)',
    '  - `5xx` (transient upstream failure)',
    '- On any of those it silently switches to the next key. On a `400` (bad request - our bug) or `404` (model not found - our bug) it stops immediately so we do not waste quota.',
    '- Network timeouts and connection refused also trigger rotation because they are usually local-proxy flakiness, not key issues.',
    '- The error is only surfaced to the user when ALL keys in the list fail.',
    '- Per-request telemetry prints `[GeminiRestClient] generateContent: HTTP <code> on key #N` so a single bad key is visible in `adb logcat`.',
    '',
    '### 2. Instant Check-in / Saved Counters (State Management)',
    '- `PlaceProvider.bumpLocalCheckinCount()` and `bumpLocalSavedCount()` / `unbumpLocalSavedCount()` were added. They increment the in-memory `_remoteCheckinCount` / `_remoteSavedCount` and emit `notifyListeners()` immediately.',
    '- `place_details_screen.dart` calls `placeProvider.bumpLocalCheckinCount()` right after `gamification.applyAction(''check_in'', placeId: place.id)` returns a non-null badge, BEFORE awaiting `fetchRemoteCounts`. The "Explored" counter on the Profile tab updates the instant the user taps Check-in.',
    '- `PlaceProvider.toggleSave` does the same for Saved: bump on save, unbump on unsave, with automatic rollback (`unbump...` / `bump...`) if the Supabase write throws or returns `false`. The UI always reflects the final DB state.',
    '- `fetchRemoteCounts` is still awaited right after the optimistic bump so the source-of-truth count is reconciled once Supabase replies.',
    '',
    '### Working mechanics preserved (per handover rules)',
    '- Authentication: Google OAuth + Supabase (v1.0.30 Web Client ID + new keystore), unchanged.',
    '- Hotels markers: `onTap` wired to `_SelectedPlaceCard` (v1.0.33), unchanged.',
    '- Map filters: Hotels / ATMs exclusive behaviour, unchanged.',
    '- R8 / ProGuard still disabled (`isMinifyEnabled = false`).',
    '- Ai Tour Guide token budget: 800 tokens / "never cut a sentence mid-thought" prompt (v1.0.21), unchanged.',
    '',
    '## Build',
    '- Target: arm64 only.',
    '- Release-signed with `android/app/release_v2.keystore` (alias `streetlore`, SHA-1 `AF:62:89:44:B5:F3:A0:0A:4E:CE:1E:72:34:13:26:EA:5A:E7:B4:8F`).',
    '- `flutter analyze`: 0 issues.',
    '- `--dart-define=GEMINI_API_KEYS=<5 keys>` (kept out of source).',
    '- Tag is force-pushed (`git push origin v1.0.34 --force`).'
)
$releaseBody = $lines -join "`n"

$payload = @{
    tag_name = $tag
    name = 'v1.0.34 - Gemini 5-key rotation + Instant Check-in counters'
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
