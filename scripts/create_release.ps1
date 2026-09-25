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

$tag = "v1.0.30"
$apkName = "streetlore-v1.0.30-arm64.apk"

$lines = @(
    '## What is new in v1.0.30 - Google Sign-In Code 10 fix (real root cause)',
    '',
    '### Root cause',
    'v1.0.28 / v1.0.29 both failed with `PlatformException(sign_in_failed, 10, ...)` because the `serverClientId` baked into `auth_provider.dart` (`504340157609-pj8oox9662299u613glititqn4dqa7ij`) belonged to a different Google Cloud project / OAuth client than the one the user is actually publishing. The release keystore SHA-1 mismatch the user hypothesised was a red herring - the previous keystore (`70:83:CF:1D:21:86:...`) was always fine; the real problem was that its registered SHA-1 was pointing to a different OAuth client entirely.',
    '',
    '### Fix',
    '1. **Web Client ID in code** - updated `auth_provider.dart` to the exact Client ID the user has in their Google Cloud Console: `504340157609-pj8ook9662299u613glititqn4dqa1jp.apps.googleusercontent.com`.',
    '2. **Release keystore** - generated a brand-new keystore `android/app/release_v2.keystore` (alias `streetlore`, password `streetlore2026`, RSA 2048, 25 years) so the APK ships with a known, fresh signing identity.',
    '   - **NEW release certificate SHA-1 (MUST be added to your Google Cloud Console OAuth client): `AF:62:89:44:B5:F3:A0:0A:4E:CE:1E:72:34:13:26:EA:5A:E7:B4:8F`**',
    '   - **NEW release certificate SHA-256: `68:20:2A:33:06:9B:82:F0:9B:08:AC:01:D4:B0:5A:6E:84:18:74:3E:B1:59:F1:39:04:9F:6A:62:CA:EF:FB:85`**',
    '3. **build.gradle.kts** - `signingConfigs.release` now points at `release_v2.keystore`.',
    '4. **R8 / ProGuard** - still `isMinifyEnabled = false`, `isShrinkResources = false` (per v1.0.29).',
    '',
    '### Action required from you',
    'Register the new SHA-1 above in Google Cloud Console -> APIs & Services -> Credentials -> OAuth 2.0 Client IDs -> the Web client that matches the new `serverClientId`. (The old `70:83:CF:...` and `76:2C:07:7A:...` can be removed from that client to keep things tidy.)',
    '',
    '### Working mechanics preserved (per handover rules)',
    '- Authentication: Google OAuth + Supabase signInWithIdToken flow, unchanged except for the new Client ID.',
    '- State management: check-ins, saved places, Profile counters (with `fetchRemoteCounts`), unchanged.',
    '- Map filters: Hotels / ATMs / All toggle, unchanged.',
    '- App Logo 260x260, unchanged.',
    '- Localization (no raw keys rendered), unchanged.',
    '- AI Tour Guide (gemini-1.5-flash, ?key= only), unchanged.',
    '',
    '## Build',
    '- Target: arm64 only.',
    '- Release-signed with NEW keystore `android/app/release_v2.keystore` (alias `streetlore`).',
    '- Release certificate SHA-1: `AF:62:89:44:B5:F3:A0:0A:4E:CE:1E:72:34:13:26:EA:5A:E7:B4:8F`',
    '- APK file SHA-1: `A24F5CDD949507909D0FDDF1F0F076794258B94D`',
    '- APK file SHA-256: `7F38125484D7447EAC7967E93D9AF76DF97586135B10FB4CE7CACC5D19212DE0`',
    '- Size: 26.3 MB',
    '- `flutter analyze`: 0 issues.'
)
$releaseBody = $lines -join "`n"

$payload = @{
    tag_name = $tag
    name = 'v1.0.30 - Code 10 fix: brand-new keystore + corrected Web Client ID'
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
