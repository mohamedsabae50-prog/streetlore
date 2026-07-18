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
// before
final places = MockData.places;

// after
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
- **Tours** — list, create, edit, delete (with multi-place picker + drag-to-reorder)
- **Images** — uploaded to Supabase Storage bucket `place-images`

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
