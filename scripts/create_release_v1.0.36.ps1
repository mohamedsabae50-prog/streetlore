$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class CredMan {
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
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

$tag = "v1.0.36"
$apkName = "streetlore-v1.0.36-arm64.apk"

$lines = @(
    '## What is new in v1.0.36 - Official Gemini SDK + Direct check-in upsert',
    '',
    '### 1. Official `google_generative_ai` SDK (replaces manual REST)',
    '- `lib/core/services/gemini_rest_client.dart` was rewritten on top of the official `google_generative_ai: ^0.4.4` Dart SDK (already pinned in pubspec since v1.0.21).',
    '- New call shape per the user spec:',
    '  ```dart',
    '  final model = GenerativeModel(model: ''gemini-1.5-flash'', apiKey: currentKey);',
    '  final response = await model.generateContent([Content.text(body)]);',
    '  ```',
    '- The SDK uses the documented `x-goog-api-key` header (NOT the manual `?key=` query form), so the auth path is exactly what Google AI Studio expects.',
    '- 5-key rotation preserved unchanged: tries the first key, catches `InvalidApiKey` (401) / `UnsupportedUserLocation` (403) / 5xx / timeouts / "quota" + "rate" + "too many requests" + "API key" + "not found" text-pattern detection on the SDK''s exception message, and silently falls through to the next key.',
    '- `AppConfig.geminiModel` reverted to `gemini-1.5-flash` (v1.0.35 had tried `gemini-1.5-flash-latest` against the manual REST and the user reported it was still 404''ing; with the official SDK''s auth the bare alias should now route correctly).',
    '- Surface immediately (no rotation) on the explicitly non-rotation failures like a 400-class malformed prompt or 0 (no status) when the SDK package itself is broken.',
    '- Full debug log prefix per attempt: `[GeminiRestClient] SDK call: model=... key=ABCD...wxyz attempt=N/M`.',
    '',
    '### 2. Radical check-in simplification - direct upsert + manual UI bump',
    '- `place_details_screen.dart` no longer routes the check-in through `GamificationProvider.applyAction` -> `SupabaseService.registerCheckin`. The previous path was failing silently (PostgrestException caught inside `applyAction`, surfaced through `lastCheckinError`, AND the `gamification._stats.placesVisited` local counter would''ve been out of sync).',
    '- The Check-in button now does EXACTLY what the user asked for:',
    '  ```dart',
    '  await Supabase.instance.client',
    '      .from(''place_checkins'')',
    '      .upsert({''user_id'': userId, ''place_id'': place.id}).select();',
    '  ```',
    '  - Direct, simple, no intermediate providers.',
    '  - `.select()` forces RLS denials and column mismatches to throw as `PostgrestException` instead of being swallowed.',
    '- IMMEDIATELY after the upsert returns without throwing (on the same frame), the screen forces the UI to reflect the check-in:',
    '  - `setState(() => _isVisited = true)` -> the green check badge appears instantly.',
    '  - `placeProvider.bumpLocalCheckinCount()` -> increments `PlaceProvider._remoteCheckinCount` and calls `notifyListeners()` -> the Profile screen''s "Explored" counter is one larger on next open (no waiting for the remote fetch).',
    '- On exception the screen rolls back `_isVisited` to false and shows the EXACT `PostgrestException.code + message` in a red SnackBar that stays for 6 seconds, so an RLS denial `"[42501] new row violates row-level security policy for table place_checkins"` is immediately readable.',
    '- The user must be signed in; if `currentUser.id` is empty the screen shows "Please sign in to check in." in a red SnackBar and returns.',
    '- Streak provider still fires (`streak.registerVisit()`) right before the network call so the streak digit starts incrementing instantly too.',
    '- The now-unused `GamificationProvider` / `AchievementProvider` imports were removed from `place_details_screen.dart`.',
    '',
    '### Working mechanics preserved (per handover rules)',
    '- Authentication: Google OAuth + Supabase (v1.0.30 Web Client ID + same keystore), unchanged.',
    '- Hotels markers: `onTap` wired to `_SelectedPlaceCard` (v1.0.33), unchanged.',
    '- R8 / ProGuard still disabled (`isMinifyEnabled = false`).',
    '- AI Tour Guide token budget: 800 tokens / "never cut a sentence mid-thought" prompt (v1.0.21), unchanged.',
    '',
    '## Build',
    '- Target: arm64 only.',
    '- Release-signed with `android/app/release_v2.keystore` (alias `streetlore`, SHA-1 `AF:62:89:44:B5:F3:A0:0A:4E:CE:1E:72:34:13:26:EA:5A:E7:B4:8F`).',
    '- `flutter analyze`: 0 issues.',
    '- `--dart-define=GEMINI_API_KEYS=<5 keys>` (kept out of source).',
    '- Tag force-pushed (`git push origin v1.0.36 --force`).'
)
$releaseBody = $lines -join "`n"

$payload = @{
    tag_name = $tag
    name = 'v1.0.36 - Official Gemini SDK + Direct check-in upsert'
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
