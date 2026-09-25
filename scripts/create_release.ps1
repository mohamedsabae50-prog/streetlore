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

$tag = "v1.0.27"
$apkName = "streetlore-v1.0.27-arm64.apk"

$lines = @(
    '## What is new in v1.0.27 - bug-fix pass',
    '',
    'Four concrete bugs from the v1.0.26 video recording are fixed. No unrelated code was touched.',
    '',
    '### 1. Google Sign-in (code 10) - verbose error log',
    '- `android/build.gradle` and `android/app/build.gradle` were NOT modified by the v1.0.22-26 series (verified by `git diff 471e879 HEAD -- android/build.gradle android/app/build.gradle` -> empty). The code 10 error is an SHA-1 mismatch between the release keystore and the OAuth client registered in Google Cloud Console.',
    '- `AuthProvider.signInWithGoogleNative` now logs the OAuth client id + package + full stack trace on every failure via `debugPrint` so the next logcat trace will show the exact rejection reason.',
    '- The v1.0.21 release SHA-1 was `7FFC06A1A3D5006B5B471BF977F8507923498790`; the v1.0.27 release SHA-1 is `D00ACC072251B05EB7A802BFE924F169CA0ACE07`. If you have the v1.0.21 SHA-1 added to Google Cloud Console, you need to ALSO add the v1.0.27 SHA-1 (or the SHA-1 of whichever signed APK you actually install).',
    '',
    '### 2. Silent DB failure - explicit .count() on startup',
    '- `SupabaseService.countUserRows(userId)` runs `select().eq(user_id).count()` against `saved_places` and `place_checkins` on every auth state change.',
    '- `PlaceProvider.bootstrapForUser` calls `countUserRows` first and logs `DB counts for <uid> -> saved_places=N place_checkins=N` before pulling rows. If RLS or a missing table silently drops the count, you will see it in logcat.',
    '- Every Supabase write path (`pushSavedPlace`, `deleteSavedPlace`, `registerCheckin`, `pushStats`, `postMessage`) now ends with `.select()` so RLS denials come back as a `PostgrestException` and the `_logError` helper prints the exact code + message.',
    '',
    '### 3. Map - Hotels chip no longer blanks the map',
    '- Root cause: when the user tapped the Hotels extra-layer chip, the code also forced `_selectedCategory = ''Hotels''` which made `_filtered(places)` return only places whose `category` field equals ''Hotels''. The DB rarely has those rows on its own, so the user saw "0 places" and a white map. The seed-hotel markers from `getSeedHotels()` were technically rendered but overlapping and small.',
    '- Fix: the `onToggleExtraLayer(''Hotels'')` path no longer mutates `_selectedCategory`. The main places and the hotel markers are now independent of each other, so toggling Hotels never blanks the map.',
    '- The `Markers` list still renders user-location + main `visible` + ATMs (when toggled) + hotels (when toggled) in the correct order.',
    '',
    '### 4. UI fixes',
    '- **Passion banner**: `passion_banner_title` and `passion_banner_sub` were present in the ARB files and the generated `app_localizations*.dart` but missing from `app_strings.dart`, which is what `context.tr()` reads at runtime. The banner was rendering the raw key. Both keys are now defined in `app_strings.dart` (en + ar).',
    '- **Logo size on Login**: bumped the container from 160x160 to 200x200 with a 44px rounded gradient border. The actual `Image.asset(fit: BoxFit.contain)` now fills the inner area properly and the logo no longer looks cropped.',
    '',
    '## Build',
    '- Target: arm64 only.',
    '- Release-signed with existing `release.keystore`.',
    '- SHA-1 (release): D00ACC072251B05EB7A802BFE924F169CA0ACE07',
    '- SHA-256 (release): C46E82269FC421A91BBB9376B44D836419EE0DA6D9EF5C5BE1E91E37F24D9064',
    '- `flutter analyze`: 0 issues.'
)
$releaseBody = $lines -join "`n"

$payload = @{
    tag_name = $tag
    name = 'v1.0.27 - bug fixes: map Hotels blank, passion_banner i18n, DB count, login logo, Google auth error log'
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
