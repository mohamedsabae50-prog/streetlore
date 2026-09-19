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

$tag = "v1.0.13"
$apkName = "streetlore-v1.0.13-arm64.apk"

$lines = @(
    '## What is new in v1.0.13',
    '',
    '### 1. Session persistence - bulletproof restore (radical fix)',
    '- Supabase.initialize keeps its default `SharedPreferencesLocalStorage` (already reliable on Android),',
    '  AND we now mirror the active session to plain SharedPreferences on every',
    '  signed-in / token-refreshed event.',
    '- On bootstrap we try, in order: `currentSession` -> explicit',
    '  `refreshSession()` -> wait up to 5s for `initialSession` event',
    '  -> `setSession(accessToken)` from the SharedPreferences mirror.',
    '- This fixes the "logged out after every restart" symptom when Supabase''s',
    '  own storage layer fails silently on devices with broken keystores.',
    '',
    '### 2. Sign-In form - no more username field',
    '- Username field removed from `LoginScreen`. The form now strictly requires',
    '  Email + Password.',
    '- `AuthProvider.signIn()` makes `name` optional and derives a friendly',
    '  display name from the email local-part when not provided (e.g.',
    '  `mohamed.sabae` -> `Mohamed Sabae`).',
    '',
    '### 3. AI chatbots - real Gemini API integration',
    '- Removed the restrictive `key.startsWith(''AIza'')` check that was',
    '  silently rejecting the configured Gemini key and forcing every reply',
    '  down the static offline path.',
    '- New `_looksLikeRealKey()` heuristic accepts AIza*, Vertex-style, and',
    '  any sufficiently long token while still rejecting obvious placeholders',
    '  (`YOUR_*`, empty, too-short).',
    '- Real Gemini calls are now attempted for both Smart Trip Planner and',
    '  Place chatbot. If the API rejects the key or the network fails, the',
    '  chat surfaces the actual error (400/403/429/DNS/timeout) so the user',
    '  knows the key needs updating.',
    '- New `AiSource { live, local }` enum on `AiTripPlan` and chat replies',
    '  marks live vs local so the UI can label local answers honestly.',
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
    name = 'v1.0.13 - radical fixes: session persistence, no-username login, real Gemini API'
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
