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

$tag = "v1.0.15"
$apkName = "streetlore-v1.0.15-arm64.apk"

$lines = @(
    '## What is new in v1.0.15',
    '',
    '### 1. Admin form reorganized (Best Time moved inline)',
    '- Removed the standalone "Best Time to Visit" _section.',
    '- Added a single inline "Best Time" field at the bottom of the',
    '  Identification section (next to Rating and Featured). One text',
    '  input, simple hint text, no extra UI clutter.',
    '- The English Content card and Arabic Content card remain',
    '  visually separated with distinct colored borders (blue / green)',
    '  so admins can never confuse the two again.',
    '',
    '### 2. Gemini REST client - hard guarantee: NO Authorization header',
    '- Each request now uses a freshly-created `http.Client()` with',
    '  explicit per-request headers only (`Content-Type`, `Accept`,',
    '  `User-Agent`). The `Authorization` and `authorization` headers',
    '  are explicitly set to empty string so they cannot leak from',
    '  the runtime',
    '  interceptor layer.',
    '- Endpoint: `POST https://generativelanguage.googleapis.com/v1beta/models/{m}:generateContent?key=API_KEY`.',
    '  Only the URL parameter is used for authentication.',
    '- 4 Gemini keys are rotated on 4xx / timeout.',
    '',
    '### 3. Sign-out: bulletproof wipe across every storage layer',
    '- `AuthProvider.signOut()` now, in order:',
    '   1) flip `_isLoggedIn=false` + `_userId=""` + `_userEmail=""` + ',
    '     `notifyListeners()` (UI updates instantly)',
    '   2) `await Supabase.instance.client.auth.signOut()`',
    '   3) wipe every well-known `FlutterSecureStorage` key + a full',
    '     `readAll()` sweep (defensive belt-and-braces even if the SDK',
    '     is configured with SharedPreferencesLocalStorage)',
    '   4) wipe every SharedPreferences key we ever wrote (`sb_*`, ',
    '     `user_*`, `is_logged_in`, `has_seen_onboarding`) + the Supabase',
    '     host-named session key + a sweep of every `sb-*` key as final',
    '     defense.',
    '- Profile screen then `pushAndRemoveUntil` to the LoginScreen so',
    '  the navigation stack cannot navigate back.',
    '- After this, on next cold start `bootstrap()` finds nothing to',
    '  restore and the user lands on the Login screen.',
    '',
    '## Build',
    '- Target: arm64 only (`--split-per-abi --target-platform android-arm64`).',
    '- Release-signed with existing `release.keystore`.',
    '- SHA-1 (release): 70:83:CF:1D:21:86:FC:35:65:94:05:B8:C5:4A:DD:A4:E5:31:AE:7D',
    '- `flutter analyze`: 0 issues.'
)
$releaseBody = $lines -join "`n"

$payload = @{
    tag_name = $tag
    name = 'v1.0.15 - definitive fixes (admin inline, Gemini no auth headers, signOut wipes all)'
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
