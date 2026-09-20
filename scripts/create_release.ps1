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

$tag = "v1.0.17"
$apkName = "streetlore-v1.0.17-arm64.apk"

$lines = @(
    '## What is new in v1.0.17',
    '',
    '### 1. Featured section removed from Home Screen',
    '- The whole Featured section (title + Open Now / Nearest filter',
    '  chips + horizontal featured cards carousel + parallax',
    '  animation) is deleted from `lib/presentation/screens/home_screen.dart`.',
    '- Dead code cleaned up: `featured_card.dart` import,',
    '  unused `displayedPlaces` + `featured` locals, the',
    '  `_scrollCtrl`-driven parallax AnimatedBuilder, and the unused',
    '  `placeProvider` watch in `_buildMain`.',
    '- `PlaceProvider.applyFilters`, `isFilterOpenNow`,',
    '  `toggleFilterOpenNow`, `isFilterNearest`, `toggleFilterNearest`',
    '  remain in the provider (kept for backward compatibility + admin',
    '  presets). The Featured entry point that called them is gone.',
    '',
    '### 2. Best Time to Visit now shown on Place Details',
    '- Place Details screen now displays the admin-entered',
    '  `bestTimeToVisit` value verbatim (the manual override field).',
    '- New `_BestTimeBanner` widget sits directly under the price',
    '  banner with: amber clock icon, "Best Time" title, the admin-',
    '  entered label as the headline, and a "CURATED" pill plus a',
    '  "Set by the editorial team" hint line.',
    '- Falls back gracefully: if `bestTimeToVisit` is null or empty',
    '  the banner is hidden entirely so the screen keeps the same',
    '  rhythm as before.',
    '- New l10n keys: `best_time_admin_hint` (EN / AR) wired through',
    '  `app_en.arb`, `app_ar.arb`, `app_strings.dart`, and the',
    '  generated localizations.',
    '',
    '## Build',
    '- Target: arm64 only (`--split-per-abi --target-platform android-arm64`).',
    '- Release-signed with existing `release.keystore`.',
    '- SHA-1 (release): see release asset.',
    '- `flutter analyze`: 0 issues.'
)
$releaseBody = $lines -join "`n"

$payload = @{
    tag_name = $tag
    name = 'v1.0.17 - Featured removed + admin Best Time surfaced on Place Details'
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
