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

$tag = "v1.0.12"
$apkName = "streetlore-v1.0.12-arm64.apk"

$lines = @(
    "## What's new in v1.0.12",
    "",
    "### Auth & session",
    "- Email/Password sign-in is now wired to Supabase `auth.signInWithPassword`",
    "  (and `signUp` for registration) with proper `AuthException` mapping:",
    "  wrong password, email not confirmed, rate-limited, and account-exists",
    "  cases now surface friendly messages instead of generic crashes.",
    "- Local SharedPreferences fallback is preserved so the app still works",
    "  offline for returning users.",
    "",
    "### Smart Trip Planner + Place chatbot",
    "- System prompt now anchors every answer to a curated set of Alexandria",
    "  facts (lighthouse history, climate, Corniche, Bibliotheca, Qaitbay,",
    "  signature foods, rush hours, day-trip options).",
    "- Local fallback plan now produces unique tips, category-aware notes,",
    "  and time-of-day-aware replies (`is it good now?` returns a real verdict).",
    "",
    "### Currency Converter",
    "- Live rates via `open.er-api.com` (no API key, CORS-enabled).",
    "- 6-hour in-memory cache + static fallback table.",
    "- LIVE / OFFLINE badge shows whether the current rate is live or cached.",
    "",
    "### Best Time to Visit + Daylight",
    "- Sun-times clamped to [0, 24h]; daylight duration handles negative",
    "  or wraparound windows safely (no more 99h/24h garbage).",
    "",
    "### Offline download",
    "- Pack matching now supports `__all__` plus category-based filtering.",
    "  No more `No places found` for valid packs.",
    "",
    "### Featured section (Home)",
    "- Filter chips trimmed to **Open Now** + **Nearest** only — less",
    "  clutter, faster decisions.",
    "",
    "### Admin Panel",
    "- Place form reorganized: all English fields in one section, all Arabic",
    "  fields in another, and a dedicated Identification section.",
    "",
    "### Removed",
    "- Public Transport screen and localization keys removed entirely.",
    "- Journal quick-action removed from Home (still accessible from Profile).",
    "",
    "## Build",
    "- Target: arm64 only (`--split-per-abi --target-platform android-arm64`).",
    "- Release-signed with existing `release.keystore`.",
    "- SHA-1 (release): 70:83:CF:1D:21:86:FC:35:65:94:05:B8:C5:4A:DD:A4:E5:31:AE:7D",
)
$releaseBody = $lines -join "`n"

$payload = @{
    tag_name = $tag
    name = "v1.0.12 - 8 fixes: auth, AI, currency, offline, daylight, admin UI"
    body = $releaseBody
    draft = $false
    prerelease = $false
} | ConvertTo-Json -Depth 10

Write-Host "Checking existing release $tag..."
try {
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/mohamedsabae50-prog/streetlore/releases/tags/$tag" -Headers $headers
    Write-Host "Found existing release id=$($release.id) url=$($release.html_url)"
} catch {
    Write-Host "Creating new release..."
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/mohamedsabae50-prog/streetlore/releases" -Method Post -Headers $headers -Body $payload -ContentType "application/json"
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
