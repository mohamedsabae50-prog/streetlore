# Streetlore — Supabase Setup Guide

This guide walks you through wiring the Streetlore app and the new Admin panel to a real Supabase project.

---

## 0. Prerequisites
- A Supabase account — https://supabase.com (free tier is fine)
- Flutter SDK 3.x
- An admin user will be created in step 3

---

## 1. Create the database schema

In your Supabase project:

1. Open **SQL Editor** → **New query**
2. Copy the entire contents of `supabase_setup.sql` (in the project root) and paste
3. Click **Run**

You should see: `Success. No rows returned` — the tables, policies, view, and storage bucket are now created.

For an existing database, apply `supabase/migrations/2026_10_10_tour_draft_status.sql` in the SQL Editor. It adds the `tours.status` column and updates `tours_with_places` to expose tour status and place image URLs.

Apply `supabase/migrations/2026_10_11_admin_analytics.sql` after that migration to enable tour view counts and the protected Admin analytics RPC. AI guide usage reports the current-day quota usage in `ai_quota`, not a lifetime total; check-ins and tour views are cumulative.

Apply `supabase/migrations/2026_10_12_admin_checkins_by_place.sql` after the analytics migration to add the Top Places by Check-ins breakdown to the Admin dashboard.

---

## 2. Create the admin user (one-time)

1. In Supabase dashboard, go to **Authentication** → **Users** → **Add user**
2. Choose **Create new user**
3. Enter your email and password (this is the admin login)
4. Click **Create user**

Save the email/password — you'll use them to sign in to the admin panel.

---

## 3. Seed the database with the 30 Alexandria places

From the project root (`D:\codes\streetlore`):

```bash
flutter pub get
dart run tools/seed.dart
```

You should see lines like:
```
+ place 1 (Qaitbay Citadel)
+ place 2 (Bibliotheca Alexandrina)
...
+ tour t1 (Alexandria Historical Walk) with 3 stops
...
--- Done ---
```

If you get a permissions error, make sure RLS policies were created in step 1 (anon key only does SELECT — the seed script also only does SELECT/INSERT via the anon key for the demo. For production, use the service_role key in the seed script.)

---

## 4. Run the main app

The app is now wired to Supabase. On startup, `main.dart` will:
1. Initialize the Supabase client
2. Trigger `PlaceProvider.loadPlaces()` and `TourProvider.loadTours()`

```bash
flutter run -d edge --web-port 8080
```

The places and tours in the UI will now come from your Supabase database.

### Important note about the UI

You told me NOT to modify `home_screen.dart` and `place_details_screen.dart`. Those screens still call `MockData.places` and `MockData.getByCategory()` for their data source. The new `PlaceProvider.places` is the source of truth from the database.

**To see real Supabase data in the UI**, do this in any of those screens:

```dart
final places = MockData.places;

final places = context.watch<PlaceProvider>().places;
```

The `PlaceProvider` and `TourProvider` are now fully integrated with Supabase — once the screens read from them, the app is 100% data-driven.

---

## 5. Run the admin panel

The admin is a separate Flutter project at `D:\codes\streetlore_admin\`.

```bash
cd D:\codes\streetlore_admin
flutter pub get
flutter run -d edge --web-port 8081
```

Open http://localhost:8081 and log in with the email/password you created in step 2.

### What you can do in the admin
- **Dashboard** — counts of places and tours
- **Places** — list, create, edit, delete
- **Tours** — list, create, edit, delete (with multi-place picker, drag-to-reorder, and Draft/Published status)
- **User Photos** — moderate user-submitted photos; official place image URLs are managed separately on each place
- **Users** — search Auth accounts by name or email and remove inappropriate accounts
- **Official place images** — add, reorder, and remove multiple image URLs; mobile Place Details shows them in a swipeable carousel

User accounts are stored in Supabase Auth, with names in Auth user metadata. The `profiles` table stores the RevenueCat Pro entitlement used by the AI quota, along with its subscription tier and expiry. Users with no profile or an unverified entitlement are treated as free users. Apply `supabase/migrations/20261019000000_profile_subscription_tiers.sql` before deploying the updated functions.

```bash
supabase functions deploy admin-user-management --no-verify-jwt --project-ref tbivoxyxclwjjspwsgvc
supabase functions deploy sync-subscription --project-ref tbivoxyxclwjjspwsgvc
supabase secrets set ADMIN_EMAIL=mohamedsabae50@gmail.com --project-ref tbivoxyxclwjjspwsgvc
```

The admin function verifies the caller's Auth token and admin email itself before accessing the Auth Admin API. It prevents deleting or changing the admin account and removes the user's submitted photos, uploaded photo files, chat, check-ins, saved items, leaderboard entry, and AI quota before deleting the Auth account. The admin Users screen can set Weekly (+7 days), Monthly (+30 days), Annual (+365 days), Lifetime (no expiry), or Free. The `sync-subscription` function verifies the signed-in user and checks their active `pro` entitlement against RevenueCat before updating the profile; it does not trust a tier sent by the app. Sandbox and RevenueCat Test Store purchases never grant Pro unless `REVENUECAT_ALLOW_SANDBOX=true` is set (leave it unset on production).

Set a RevenueCat **secret API key** (never the public SDK key) and a JSON map of exact store product identifiers to tiers, then deploy the webhook:

```powershell
supabase secrets set REVENUECAT_SECRET_API_KEY="your_revenuecat_secret_api_key" REVENUECAT_WEBHOOK_SECRET="your_webhook_authorization_secret" REVENUECAT_PRODUCT_TIERS='{"weekly_product_id":"weekly","monthly_product_id":"monthly","annual_product_id":"annual","lifetime_product_id":"lifetime"}' --project-ref tbivoxyxclwjjspwsgvc
supabase functions deploy revenuecat-webhook --no-verify-jwt --project-ref tbivoxyxclwjjspwsgvc
```

Use the exact product identifiers configured in RevenueCat, mapping every product attached to the `pro` entitlement. Configure the RevenueCat webhook to call `revenuecat-webhook` with the `REVENUECAT_WEBHOOK_SECRET` authorization value. The mobile app calls `sync-subscription` after a successful purchase or restore; the webhook is only a trigger: for every app user id in the event (including both sides of a `TRANSFER`) it re-reads the current state from the RevenueCat REST API and applies the same rules, so replayed or out-of-order events are harmless and sandbox events are ignored. Pro also expires server-side: the AI quota treats a profile as Pro only while `subscription_end_date` is empty (lifetime) or in the future. Apply `supabase/migrations/20261105000001_subscription_integrity.sql` (adds the `annual` tier and the expiry rule) before deploying these functions, and redeploy `sync-subscription` and `revenuecat-webhook` (both import `supabase/functions/_shared/`) plus `admin-user-management` (now accepts the `annual` plan). Before using photo moderation, run `supabase/migrations/2026_10_13_admin_photo_storage_delete.sql` in the Supabase SQL Editor. It grants the configured admin account permission to delete both photo rows and files from the `place-images` bucket.

For local mobile purchase testing, build/run with the platform's RevenueCat **public SDK key** and explicitly enable the SDK. Keep `REVENUECAT_SECRET_API_KEY` out of the app:

```powershell
flutter run --dart-define=ENABLE_REVENUECAT=true --dart-define=REVENUECAT_ANDROID_API_KEY=your_android_public_sdk_key
```

Use `REVENUECAT_IOS_API_KEY` for iOS builds. Purchases remain disabled by default when `ENABLE_REVENUECAT` is omitted.
- **Images** — uploaded to Supabase Storage bucket `place-images`

### Gemini AI credentials

All Flutter Gemini requests use the `ai-proxy` Edge Function; no Gemini credential is included in the app build. Configure one server-side credential:

- Recommended: set `GEMINI_SERVICE_ACCOUNT_JSON` to the complete Google service-account JSON in the Supabase project's Edge Function secrets. The function exchanges it for OAuth access tokens and refreshes them as needed.
- `GEMINI_OAUTH_ACCESS_TOKEN` accepts a bearer access token, but these tokens expire and must be rotated.
- `GEMINI_API_KEY` remains supported for standard Gemini API keys.

Apply the relevant migrations in timestamp order: `supabase/migrations/20261017000000_ai_quota_utc_calendar_day.sql`, `supabase/migrations/20261018000000_ai_chat_logs.sql`, `supabase/migrations/20261019000000_profile_subscription_tiers.sql`, then `supabase/migrations/20261028000000_chat_sessions_and_midnight_quota.sql`. The latest migration switches the quota boundary to midnight in `Africa/Cairo`, exposes the current quota and next Cairo reset time to the app, groups logged messages by chat session, and retains the 3-call free / 50-call Pro daily limits. Users with no profile or an `is_pro` value other than `true` receive the free quota. Chat requests include the full in-session transcript, and chat-log records carry the chat screen's session UUID.

Deploy the proxy after setting the secret:

```powershell
supabase functions deploy ai-proxy --no-verify-jwt --project-ref tbivoxyxclwjjspwsgvc
supabase functions deploy admin-user-management --no-verify-jwt --project-ref tbivoxyxclwjjspwsgvc
```

The function validates each Supabase access token itself, so requests must come from a signed-in user. Do not pass Google credentials to Flutter or `--dart-define`.

---

## 6. Architecture summary

```
Supabase
   ├── table: places             (publicly readable, auth-write)
   ├── table: tours              (publicly readable, auth-write)
   ├── table: tour_places        (junction)
   ├── view: tours_with_places   (auto-joins)
   └── bucket: place-images      (publicly readable, auth-write)
   ↑
   │  supabase_flutter
   │
   ├──→ Main App (D:\codes\streetlore)
   │     ├── PlaceProvider  →  fetchPlaces() / createPlace() etc.
   │     ├── TourProvider   →  fetchTours()  / createTour() etc.
   │     └── main.dart      →  init Supabase + auto-load
   │
   └──→ Admin Panel (D:\codes\streetlore_admin)
         ├── AdminService →  full CRUD on places & tours
         ├── LoginScreen  →  Supabase Auth
         └── Dashboard    →  stat cards + quick actions
```

---

## 7. Files changed / created

### Main app
- ✏️ `lib/main.dart` — initializes Supabase, auto-loads data
- ✏️ `lib/logic/place_provider.dart` — fetches from Supabase
- ✏️ `lib/logic/tour_provider.dart` — fetches from Supabase
- ➕ `lib/core/config/supabase_config.dart` — URL + key
- ➕ `supabase_setup.sql` — schema
- ➕ `tools/seed.dart` — initial data import

### Admin panel (new project)
- ➕ `D:\codes\streetlore_admin/` — entire Flutter project
  - `lib/main.dart`, `lib/theme.dart`
  - `lib/config/supabase_config.dart`
  - `lib/models/models.dart`
  - `lib/services/admin_service.dart`
  - `lib/screens/login_screen.dart`
  - `lib/screens/dashboard_screen.dart`
  - `lib/screens/places_list_screen.dart`
  - `lib/screens/place_form_screen.dart`
  - `lib/screens/tours_list_screen.dart`
  - `lib/screens/tour_form_screen.dart`

---

## 8. Troubleshooting

**Q: App shows error "Failed to load places"**
A: Check that:
1. The SQL schema ran successfully
2. The seed script populated the tables
3. The Supabase URL/key in `supabase_config.dart` is correct

**Q: Admin can't sign in**
A: Make sure you created the user in step 2. Check that RLS policies allow authenticated users to write.

**Q: "permission denied for table places"**
A: Re-run the SQL. RLS is enabled and the policies must be created.

**Q: Image upload fails**
A: Verify the `place-images` bucket exists (step 1 creates it). Check that you can read its policies under **Storage** → **Policies**.

---

## 9. Production checklist

Before going live, replace the anon key in:
- `D:\codes\streetlore\lib\core\config\supabase_config.dart`
- `D:\codes\streetlore_admin\lib\config\supabase_config.dart`
- `D:\codes\streetlore\tools\seed.dart`

with the **anon (publishable) key** from your Supabase project settings. The service_role key should NEVER be in client code.

For real production, you should:
1. Set up proper auth flow (email verification, password reset)
2. Add rate limiting via Edge Functions
3. Add image optimization
4. Move secrets to a proper env loader (`flutter_dotenv` or `dart-define`)
