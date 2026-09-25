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

$tag = "v1.0.31"
$apkName = "streetlore-v1.0.31-arm64.apk"

$lines = @(
    '## What is new in v1.0.31 - logos + map filter polish',
    '',
    '### 1. App logos (external launcher + internal)',
    '- **External launcher icon**: regenerated the legacy mipmap PNGs (mdpi -> xxxhdpi) with the brand gradient background + centered logo so pre-O launchers no longer show the dark navy `#0F172A` fallback or a transparent hole. The adaptive icon (Android 8.0+) still uses the safe-zone foreground so launcher masks crop cleanly. `tools/setup_adaptive_icon.ps1` is the source of truth - run it whenever the brand logo changes.',
    '- **Internal logo (Login + Splash)**: reduced from 260x260 to 200x200. The `ClipOval` / `ClipRRect` wrapper keeps a generous inner padding so the mark sits elegantly above the form, not dominating it.',
    '',
    '### 2. Map filters - Hotels / ATMs exclusivity',
    '- `_filtered(places)` in `map_view_screen.dart` now treats the Hotels and ATMs extra-layers as exclusive modes:',
    '  - **ATMs chip ON** -> hide every main place, only the 12 ATM markers carry the map.',
    '  - **Hotels chip ON** -> main places are restricted to `category == ''Hotels''`, then the seed hotel markers from `getSeedHotels()` overlay. Result: ONLY the hotel markers render, no stale historical / mosque / food pins.',
    '  - **All chip OFF (sentinel `__none__`)** -> empty map (unchanged).',
    '  - **No extra layer + a normal category** -> filter to that category (unchanged).',
    '- No more "0 places / white map" when toggling the Hotels or ATMs chip on.',
    '',
    '### Working mechanics preserved (per handover rules)',
    '- Authentication: Google OAuth + Supabase (v1.0.30 Web Client ID + new keystore), unchanged.',
    '- State management: check-ins, saved places, Profile counters (with `fetchRemoteCounts`), unchanged.',
    '- AI Tour Guide (gemini-1.5-flash, ?key= only), unchanged.',
    '- R8 / ProGuard still disabled (`isMinifyEnabled = false`), so all native plugin entry points are preserved.',
    '',
    '## Build',
    '- Target: arm64 only.',
    '- Release-signed with the new keystore `android/app/release_v2.keystore`.',
    '- Release certificate SHA-1: `AF:62:89:44:B5:F3:A0:0A:4E:CE:1E:72:34:13:26:EA:5A:E7:B4:8F` (register in Google Cloud Console).',
    '- APK file SHA-1: `B76693A7F1423461D4A91DF116F363E078C6E35D`',
    '- APK file SHA-256: `AE70ADCF4B5507301B119396C23896738179C1491550FB78E111AF731B1D68A4`',
    '- Size: 26.3 MB',
    '- `flutter analyze`: 0 issues.'
)
$releaseBody = $lines -join "`n"

$payload = @{
    tag_name = $tag
    name = 'v1.0.31 - logos polished + map Hotels/ATMs exclusive filters'
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
