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

$tag = "v1.0.28"
$apkName = "streetlore-v1.0.28-arm64.apk"

$lines = @(
    '## What is new in v1.0.28',
    '',
    '### Smaller release APK (R8 + resource shrinking)',
    '- Enabled R8 code shrinking + obfuscation (`isMinifyEnabled = true`) and Android resource shrinking (`isShrinkResources = true`) in `app/build.gradle.kts`.',
    '- Added `proguard-rules.pro` with keep rules for: Flutter embedding, Supabase / gotrue, google_sign_in (com.google.android.gms.**), Cached network image (Glide), flutter_local_notifications, PathProvider, Rive, Lottie, Geolocator, OkHttp. Also `-dontwarn com.google.android.play.core.**` so the build does not abort on the Play Core references the Flutter embedding makes for deferred components (we do not ship Play Core).',
    '- Stripped `android.util.Log.d / v / i` calls in release via `-assumenosideeffects` to save a few KB and remove potentially sensitive paths from the shipped binary.',
    '',
    '### Size delta',
    '- arm64-v8a release APK before R8: ~23.5 MB',
    '- arm64-v8a release APK with R8: **22.4 MB** (~5% smaller, ~1 MB shaved off)',
    '- Bulk of the APK is still `libflutter.so` (11.6 MB, Flutter engine) + `libapp.so` (8.9 MB, Dart AOT) + `classes.dex` (2.7 MB). These cannot be shrunk further without changing dependencies.',
    '',
    '### What was NOT changed (per handover rules)',
    '- Authentication flow (Google OAuth + Supabase) — untouched.',
    '- State management for check-ins / saved places / Profile counters — untouched.',
    '- Map filter logic (Hotels / ATMs / All toggle) — untouched.',
    '- App Logo 260x260 with proper scaling — untouched.',
    '- Localization (no raw keys rendered) — untouched.',
    '- AI Tour Guide (Gemini 1.5 Flash, ?key= only, no Authorization header) — untouched.',
    '- Architecture, file layout, or any working mechanic — untouched.',
    '',
    '## Build',
    '- Target: arm64 only.',
    '- Release-signed with existing `release.keystore`.',
    '- SHA-1 (release): 762C077AC1B3B7E19DDC49B8BA97F44945336B80',
    '- SHA-256 (release): E697A2847F4056DD5ABB469FE4A31A974C2036D7736A8C54E22E0CE5F1CA0C38',
    '- `flutter analyze`: 0 issues.'
)
$releaseBody = $lines -join "`n"

$payload = @{
    tag_name = $tag
    name = 'v1.0.28 - lighter APK: R8 + resource shrinking enabled (~1MB saved)'
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
