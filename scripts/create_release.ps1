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

$tag = "v1.0.29"
$apkName = "streetlore-v1.0.29-arm64.apk"

$lines = @(
    '## What is new in v1.0.29 - Google Sign-In Code 10 fix',
    '',
    '### Root cause',
    'v1.0.28 enabled R8 code shrinking + resource shrinking (`isMinifyEnabled = true`, `isShrinkResources = true`). Even with a careful `proguard-rules.pro` keeping the Flutter / Supabase / google_sign_in entry points, R8 was stripping or renaming a class the `google_sign_in` plugin needs at runtime. On a real device this surfaced as `PlatformException(sign_in_failed, 10, ...)`.',
    '',
    '### Fix',
    '- Reverted `app/build.gradle.kts` to the v1.0.27 configuration: `isMinifyEnabled = false`, `isShrinkResources = false`. No ProGuard rules run on the release build, so every class the native plugins need is preserved exactly as it was in v1.0.21 - v1.0.27 (when the user reported Google Sign-In worked).',
    '- `auth_provider.dart` was already correct: `serverClientId = ''504340157609-pj8oox9662299u613glititqn4dqa7ij.apps.googleusercontent.com''` (the Web Client ID, as required by the `google_sign_in` plugin when calling `signInWithIdToken` on Supabase).',
    '- Keystore is unchanged: `android/app/release.keystore` with alias `streetlore`. Certificate SHA-1 fingerprint: `70:83:CF:1D:21:86:FC:35:65:94:05:B8:C5:4A:DD:A4:E5:31:AE:7D` (already in the user''s Google Cloud Console OAuth client).',
    '- Debug SHA-1 (only relevant if you install a `flutter run` / debug build): `A4:30:B8:FD:D5:69:9F:35:07:34:51:16:1D:D9:90:77:4D:31:CA:E5`.',
    '',
    '### Working mechanics preserved (per handover rules)',
    '- Authentication: Google OAuth + Supabase signInWithIdToken flow, unchanged.',
    '- State management: check-ins, saved places, Profile counters (with `fetchRemoteCounts`), unchanged.',
    '- Map filters: Hotels / ATMs / All toggle behaviour, unchanged.',
    '- App Logo 260x260, unchanged.',
    '- Localization (no raw keys rendered), unchanged.',
    '- AI Tour Guide (gemini-1.5-flash, ?key= only), unchanged.',
    '',
    '## Build',
    '- Target: arm64 only.',
    '- Release-signed with existing `release.keystore` (alias `streetlore`).',
    '- Release certificate SHA-1: `70:83:CF:1D:21:86:FC:35:65:94:05:B8:C5:4A:DD:A4:E5:31:AE:7D` (already in your Google Cloud Console).',
    '- APK file SHA-1: `64FD91428A550AA0F24E3992077A70CD3A8570F4`',
    '- APK file SHA-256: `F77E00C41FC2D87B2FB734419AAF8D43CCD221FD7AFCA9E38C536EA195CC96D4`',
    '- Size: 26.3 MB (R8 disabled, back to v1.0.27 size + 4 MB of new code/assets from the local commits).',
    '- `flutter analyze`: 0 issues.'
)
$releaseBody = $lines -join "`n"

$payload = @{
    tag_name = $tag
    name = 'v1.0.29 - fix: revert R8 / ProGuard (Google Sign-In Code 10)'
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
