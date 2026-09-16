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

$lines = @(
    "## What's new",
    "- Diagnostic Google sign-in error: snackbar now shows the actual root cause",
    "  - ApiException 10 / DEVELOPER_ERROR -> SHA-1 fingerprint mismatch hint",
    "  - network / socket / timeout -> no internet",
    "  - platform / sign_in_failed -> Supabase redirect URL tip",
    "  - Other -> raw e.toString() shown in monospace for debugging",
    "- Snackbar duration extended to 8s",
    "- App is now release-signed with SHA-1: 70:83:CF:1D:21:86:FC:35:65:94:05:B8:C5:4A:DD:A4:E5:31:AE:7D",
    "- See GOOGLE_SIGNIN_FIX.md in repo for full troubleshooting guide",
    "",
    "## SHA-1 fingerprints registered in Google Cloud OAuth client",
    "- Debug: A4:30:B8:FD:D5:69:9F:35:07:34:51:16:1D:D9:90:77:4D:31:CA:E5",
    "- Release: 70:83:CF:1D:21:86:FC:35:65:94:05:B8:C5:4A:DD:A4:E5:31:AE:7D"
)
$releaseBody = $lines -join "`n"

$payload = @{
    tag_name = "v1.0.7"
    name = "v1.0.7 - OAuth redirect fix + diagnostic Google sign-in"
    body = $releaseBody
    draft = $false
    prerelease = $false
} | ConvertTo-Json -Depth 10

Write-Host "Checking existing release..."
try {
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/mohamedsabae50-prog/streetlore/releases/tags/v1.0.7" -Headers $headers
    Write-Host "Found existing release id=$($release.id) url=$($release.html_url)"
} catch {
    Write-Host "Creating new release..."
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/mohamedsabae50-prog/streetlore/releases" -Method Post -Headers $headers -Body $payload -ContentType "application/json"
    Write-Host "Created release id=$($release.id) url=$($release.html_url)"
}

$uploadUrl = $release.upload_url -replace '\{.*$',''
Write-Host "Upload URL: $uploadUrl"

$apkPath = "D:\codes\streetlore\build\app\outputs\flutter-apk\streetlore-v1.0.7-arm64.apk"
Write-Host "Uploading $apkPath..."

$uploadHeaders = @{
    "Authorization" = "Bearer $TOKEN"
    "Accept" = "application/vnd.github+json"
    "X-GitHub-Api-Version" = "2022-11-28"
    "User-Agent" = "streetlore-release-script"
    "Content-Type" = "application/vnd.android.package-archive"
}

$uploadUrlWithName = $uploadUrl + '?name=streetlore-v1.0.7-arm64.apk'
Write-Host "Final upload URL: $uploadUrlWithName"
Invoke-RestMethod -Uri $uploadUrlWithName -Method Post -Headers $uploadHeaders -InFile $apkPath -ContentType "application/vnd.android.package-archive"
Write-Host "Upload complete!"
Write-Host "Final URL: $($release.html_url)"
