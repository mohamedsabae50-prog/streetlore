# Google Sign-In Fix — Streetlore

## Diagnosis (Confirmed)
- Error: `PlatformException(sign_in_failed, y1.d: 10: , null, null)` → **API Exception Code 10 (DEVELOPER_ERROR)**
- Cause: **Debug SHA-1 fingerprint not registered** in Google Cloud Console OAuth client for `com.example.streetlore`
- The Web Client ID (`504340157609-pj8oox9662299u613glititqn4dqa7ij.apps.googleusercontent.com`) is correctly used as `serverClientId`, but Android Sign-In SDK requires an **Android OAuth client** with matching SHA-1 + package name.

## Values You Need

| Field | Value |
|-------|-------|
| **Package name** | `com.example.streetlore` |
| **Debug SHA-1** | `A4:30:B8:FD:D5:69:9F:35:07:34:51:16:1D:D9:90:77:4D:31:CA:E5` |
| **Release SHA-1** | _(run keytool against your release keystore when ready — see step 3)_ |
| **Web Client ID** | `504340157609-pj8oox9662299u613glititqn4dqa7ij.apps.googleusercontent.com` |
| **Mobile redirect** | `io.supabase.streetlore://login-callback/` |
| **Supabase URL** | `https://tbivoxyxclwjjspwsgvc.supabase.co` |

---

## Step 1 — Add Android OAuth Client in Google Cloud Console

1. Open: https://console.cloud.google.com/apis/credentials?project=_
   (sign in with the account that owns the project containing client `504340157609-...`)
2. Click **+ Create Credentials → OAuth client ID**
3. Application type: **Android**
4. Name: `Streetlore Android (debug)` (or anything)
5. Package name: `com.example.streetlore`
6. SHA-1 certificate fingerprint: `A4:30:B8:FD:D5:69:9F:35:07:34:51:16:1D:D9:90:77:4D:31:CA:E5`
7. Click **Create**

You should now see 2 OAuth clients in the list:
- One **Web** (`504340157609-...apps.googleusercontent.com`)
- One **Android** (just created)

---

## Step 2 — (Optional but Recommended) Add Release SHA-1

When you build a release APK with your own keystore, the SHA-1 changes. Add a **second Android OAuth client** for the release SHA-1:

```powershell
keytool -list -v -keystore "PATH\TO\YOUR\release.keystore" -alias YOUR_ALIAS 2>&1 | Select-String "SHA1:"
```

Create another Android OAuth client with that SHA-1.

---

## Step 3 — Verify Web Client Settings

For the **Web** OAuth client (`504340157609-...`):

- **Authorized JavaScript origins**:
  - `https://streetlore-web-app.vercel.app` (or wherever the web app is hosted)
  - `http://localhost:5000` (for local dev — Flutter web uses `Uri.base.origin` if `webRedirectUrl` is null)
- **Authorized redirect URIs**:
  - `https://tbivoxyxclwjjspwsgvc.supabase.co/auth/v1/callback`

> The custom scheme `io.supabase.streetlore://` goes in **Supabase** redirect URLs, NOT in Google Cloud's web client.

---

## Step 4 — Verify Supabase Configuration

1. Open: https://supabase.com/dashboard/project/tbivoxyxclwjjspwsgvc/auth/providers
2. **Authentication → Providers → Google**:
   - Enabled: ✓
   - Client ID: `504340157609-pj8oox9662299u613glititqn4dqa7ij.apps.googleusercontent.com`
   - Client Secret: _(from Google Cloud → Web client → Client secret)_
   - Authorized Client IDs: same Client ID above
3. **Authentication → URL Configuration → Redirect URLs**, add:
   - `io.supabase.streetlore://login-callback/`
   - `https://streetlore-web-app.vercel.app` (web app domain)
   - any localhost variants for dev

---

## Step 5 — Rebuild & Deploy

Once step 1 is done:

```powershell
cd D:\codes\streetlore
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

APK will appear at:
```
build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
```

Rename to `streetlore-v1.0.6-arm64.apk` and upload to GitHub release.

---

## Quick Verification (no rebuild needed)

The new error message (after commit `9dc2ee3`) tells you the root cause:
- `ApiException: 10` / `DEVELOPER_ERROR` → SHA-1 fingerprint not registered
- `network` / `socket` / `timeout` → no internet
- `platform` / `sign_in_failed` → Supabase redirect URL missing
- Anything else → raw error in monospace below the message
