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

$tag = "v1.0.33"
$apkName = "streetlore-v1.0.33-arm64.apk"

$lines = @(
    '## What is new in v1.0.33 - Gemini 401 real fix + Hotels tap + Check-in visible feedback',
    '',
    '### 1. Gemini 401 - isolated HttpClient (the real fix)',
    '- v1.0.33 replaces the shared `http.Client()` with a brand-new `dart:io HttpClient()` per request, wrapped in an `IOClient` (from `package:http/io_client.dart`). The fresh `HttpClient` instance is constructed with `userAgent = ''streetlore/1.0.33''` and an empty header set so it cannot inherit `Authorization: Bearer ...` from a global `HttpOverrides` / shared interceptor.',
    '- The request itself only ever sets `Content-Type: application/json`, `Accept: application/json`, `User-Agent: streetlore/1.0.33`, and the body. The code also explicitly `remove()`s the canonical auth-related keys (authorization, x-goog-api-key, x-goog-user-project, cookie) right before the request, so even a future SDK that tries to auto-attach a header will not leak through.',
    '- The URL still carries the API key in `?key=...`. The `debugPrintGemini(''API URL: $uri'')` line prints the full endpoint on every request so a 401 can be triaged from logcat.',
    '',
    '### 2. Hotels map markers are now tappable',
    '- The `Marker` for every seed hotel now has a real `onTap` that finds the matching `PlaceModel` in the merged `places` list (DB hotels + `PlaceProvider.mergeSeedHotels()` seed) and selects it. That triggers the same `_SelectedPlaceCard` that the regular place markers use: hotel name, address, rating, and the `Go` (Google Maps directions) button.',
    '- If the hotel only exists in the seed (no DB row), the onTap falls back to a synthetic `PlaceModel` built from the `MapPoi` so the card still renders correctly.',
    '- A `MapController.move(LatLng(hotel.lat, hotel.lng), 14)` is fired so the camera focuses on the tapped hotel.',
    '',
    '### 3. Check-ins now surface failures and re-fetch remote counts',
    '- `place_details_screen.dart` captures the return value of `gamification.applyAction(''check_in'', placeId: place.id)`. If the underlying `registerCheckin` write to `place_checkins` fails (RLS denial, missing table, network), the user now sees a red `SnackBar` with the exact remediation hint instead of a silent failure.',
    '- On a successful check-in, `placeProvider.fetchRemoteCounts(userId)` is awaited so the Profile screen''s "Explored" / "Saved" counters update the next time the user opens that tab (no stale zeros).',
    '- The `registerCheckin` SQL (reproduced below) must still be created in your Supabase project. The hint SnackBar in the app tells you exactly when it is missing.',
    '',
    '### Required Supabase SQL (if not already applied)',
    '```sql',
    'create table if not exists public.place_checkins (',
    '  id bigint generated always as identity primary key,',
    '  user_id text not null,',
    '  place_id text not null,',
    '  checked_in_at timestamptz not null default now()',
    ');',
    'alter table public.place_checkins enable row level security;',
    'create policy "place_checkins_read"   on public.place_checkins for select   using (auth.uid()::text = user_id);',
    'create policy "place_checkins_insert" on public.place_checkins for insert  with check (auth.uid()::text = user_id);',
    'create policy "place_checkins_delete" on public.place_checkins for delete  using (auth.uid()::text = user_id);',
    '```',
    '',
    '### Working mechanics preserved (per handover rules)',
    '- Authentication: Google OAuth + Supabase (v1.0.30 Web Client ID + new keystore), unchanged.',
    '- State management: save / fetch / merge for places, unchanged.',
    '- Map filters: Hotels / ATMs exclusive behaviour, unchanged.',
    '- Logos: 200x200 internal + gradient+logo legacy mipmaps, unchanged.',
    '- R8 / ProGuard still disabled (`isMinifyEnabled = false`).',
    '',
    '## Build',
    '- Target: arm64 only.',
    '- Release-signed with new keystore `android/app/release_v2.keystore` (alias `streetlore`).',
    '- Release certificate SHA-1: `AF:62:89:44:B5:F3:A0:0A:4E:CE:1E:72:34:13:26:EA:5A:E7:B4:8F` (already in your Google Cloud Console).',
    '- APK file SHA-1: `A273B517C994AD17C50B3648CFDF887870DF3E37`',
    '- APK file SHA-256: `8703C5E77EE7642106A9F5A0BA7132B6DDFE20046512DBE12F3CE78D1A6A90D6`',
    '- Size: 26.3 MB',
    '- `flutter analyze`: 0 issues.'
)
$releaseBody = $lines -join "`n"

$payload = @{
    tag_name = $tag
    name = 'v1.0.33 - Gemini 401 real fix + Hotels marker tappable + Check-in errors visible'
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
