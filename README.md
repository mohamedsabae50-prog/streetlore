# StreetLore

Alexandria tourism app — places, curated tours, an AI guide, offline maps,
prayer times and Qibla, check-ins with achievements, and a community feed.

- **App:** Flutter (Android, iOS scaffold, Web on GitHub Pages)
- **Backend:** Supabase — Postgres with RLS, Storage, Edge Functions
  (`ai-proxy` for Gemini, `sync-subscription` / `revenuecat-webhook` for Pro,
  `delete-user-account`, `admin-user-management`)
- **Payments:** RevenueCat (off unless built with `--dart-define=ENABLE_REVENUECAT=true`)

## Develop

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

No AI keys live in the app: every Gemini call goes through the `ai-proxy`
Edge Function, which holds the credentials and enforces the daily quota.

## Backend

- Schema and policies: `supabase/migrations/` (applied in filename order).
  `supabase_setup.sql` is the original bootstrap — do not re-run it on an
  existing project; it predates the admin-only write policies.
- Setup steps and Edge Function secrets: [SETUP_SUPABASE.md](SETUP_SUPABASE.md)
- Google Sign-In SHA-1 notes: [GOOGLE_SIGNIN_FIX.md](GOOGLE_SIGNIN_FIX.md)

## Release

`.github/workflows/release.yml` runs `flutter analyze` + `flutter test`
(job `quality`), then builds the signed APK + AAB and deploys the web build
to `gh-pages`.
