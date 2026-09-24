
create table if not exists public.places (
  id           text primary key,
  name         text not null,
  description  text not null,
  image_url    text not null,
  rating       numeric(3, 1) default 0 check (rating >= 0 and rating <= 5),
  category     text not null check (category in ('Historical','Culture','Nature','Food','Shopping','Mosques','Churches','Streets')),
  lat          numeric(10, 7) not null,
  lng          numeric(10, 7) not null,
  address      text default 'Alexandria, Egypt',
  open_hours   text default '9:00 AM - 6:00 PM',
  review_count integer default 0,
  price_level  text default 'free' check (price_level in ('free','cheap','moderate','expensive')),
  price_note   text default '',
  price_local_egp integer,
  price_foreigner_egp integer,
  is_hidden_gem boolean default false,
  is_featured  boolean default false,
  created_at   timestamptz default now(),
  updated_at   timestamptz default now()
);

create index if not exists places_category_idx on public.places (category);
create index if not exists places_is_featured_idx on public.places (is_featured);

create table if not exists public.tours (
  id          text primary key,
  title       text not null,
  description text not null,
  duration    text not null,
  image_url   text not null,
  created_at  timestamptz default now(),
  updated_at  timestamptz default now()
);

create table if not exists public.tour_places (
  tour_id   text references public.tours(id) on delete cascade,
  place_id  text references public.places(id) on delete cascade,
  position  int not null default 0,
  primary key (tour_id, place_id)
);

create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_places_updated on public.places;
create trigger trg_places_updated before update on public.places
for each row execute function public.set_updated_at();

drop trigger if exists trg_tours_updated on public.tours;
create trigger trg_tours_updated before update on public.tours
for each row execute function public.set_updated_at();

alter table public.places      enable row level security;
alter table public.tours       enable row level security;
alter table public.tour_places  enable row level security;

drop policy if exists "public read places"     on public.places;
drop policy if exists "public read tours"      on public.tours;
drop policy if exists "public read tour_places" on public.tour_places;

drop policy if exists "auth write places"      on public.places;
drop policy if exists "auth write tours"       on public.tours;
drop policy if exists "auth write tour_places" on public.tour_places;

create policy "public read places"     on public.places     for select using (true);
create policy "public read tours"      on public.tours      for select using (true);
create policy "public read tour_places" on public.tour_places for select using (true);

create policy "auth write places"      on public.places     for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "auth write tours"       on public.tours      for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "auth write tour_places" on public.tour_places for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

insert into storage.buckets (id, name, public)
values ('place-images', 'place-images', true)
on conflict (id) do nothing;

drop policy if exists "public read place-images"   on storage.objects;
drop policy if exists "auth upload place-images"   on storage.objects;
drop policy if exists "auth update place-images"   on storage.objects;
drop policy if exists "auth delete place-images"   on storage.objects;

create policy "public read place-images"   on storage.objects for select using (bucket_id = 'place-images');
create policy "auth upload place-images"   on storage.objects for insert with check (bucket_id = 'place-images' and auth.role() = 'authenticated');
create policy "auth update place-images"   on storage.objects for update using (bucket_id = 'place-images' and auth.role() = 'authenticated');
create policy "auth delete place-images"   on storage.objects for delete using (bucket_id = 'place-images' and auth.role() = 'authenticated');

create or replace view public.tours_with_places as
select
  t.id, t.title, t.description, t.duration, t.image_url, t.created_at, t.updated_at,
  coalesce(
    (select json_agg(json_build_object(
       'id', p.id, 'name', p.name, 'description', p.description,
       'imageUrl', p.image_url, 'rating', p.rating, 'category', p.category,
       'lat', p.lat, 'lng', p.lng, 'address', p.address, 'openHours', p.open_hours,
       'reviewCount', p.review_count, 'priceLevel', p.price_level,
       'priceNote', p.price_note, 'priceLocalEgp', p.price_local_egp,
       'priceForeignerEgp', p.price_foreigner_egp, 'isHiddenGem', p.is_hidden_gem,
       'isFeatured', p.is_featured
     ) order by tp.position)
     from public.tour_places tp
     join public.places p on p.id = tp.place_id
     where tp.tour_id = t.id),
    '[]'::json
  ) as places
from public.tours t;

alter table public.places drop constraint if exists places_category_check;
alter table public.places
  add constraint places_category_check
  check (category in ('Historical','Culture','Nature','Food','Shopping','Mosques','Churches','Streets','Hotels'));

alter table public.places add column if not exists price_local_egp integer;
alter table public.places add column if not exists price_foreigner_egp integer;

-- ============================================================
-- Tables required by supabase_service.dart (were missing)
-- ============================================================

-- 1. Community Chat
create table if not exists public.place_chat (
  id         bigint generated always as identity primary key,
  place_id   text not null references public.places(id) on delete cascade,
  user_id    uuid not null,
  user_name  text not null default 'Explorer',
  message    text not null,
  sent_at    timestamptz default now()
);
create index if not exists place_chat_place_idx on public.place_chat (place_id, sent_at);

alter table public.place_chat enable row level security;
create policy "public read place_chat" on public.place_chat for select using (true);
create policy "auth insert place_chat" on public.place_chat for insert
  with check (auth.uid() = user_id);
create policy "auth delete own place_chat" on public.place_chat for delete
  using (auth.uid() = user_id);

-- Enable Realtime for place_chat
alter publication supabase_realtime add table public.place_chat;

-- 2. Leaderboard (gamification stats)
create table if not exists public.leaderboard (
  user_id         uuid primary key,
  user_name       text not null default 'Explorer',
  avatar_color_hex text default '0xFF3B82F6',
  total_points    integer default 0,
  places_visited  integer default 0,
  reviews_posted  integer default 0,
  photos_uploaded integer default 0,
  level           text default 'Explorer',
  badges          jsonb default '[]'::jsonb,
  updated_at      timestamptz default now()
);

alter table public.leaderboard enable row level security;
create policy "public read leaderboard" on public.leaderboard for select using (true);
create policy "auth upsert own leaderboard" on public.leaderboard for insert
  with check (auth.uid() = user_id);
create policy "auth update own leaderboard" on public.leaderboard for update
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- 3. Saved Places (per-user bookmarks synced to cloud)
create table if not exists public.saved_places (
  user_id    uuid not null,
  place_id   text not null,
  place_data jsonb not null,
  saved_at   timestamptz default now(),
  primary key (user_id, place_id)
);

alter table public.saved_places enable row level security;
create policy "auth read own saved_places" on public.saved_places for select
  using (auth.uid() = user_id);
create policy "auth upsert own saved_places" on public.saved_places for insert
  with check (auth.uid() = user_id);
create policy "auth update own saved_places" on public.saved_places for update
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "auth delete own saved_places" on public.saved_places for delete
  using (auth.uid() = user_id);

-- 4. Place Check-ins (gamification events)
create table if not exists public.place_checkins (
  id            bigint generated always as identity primary key,
  user_id       uuid not null,
  place_id      text not null,
  checked_in_at timestamptz default now()
);
create index if not exists checkins_user_idx on public.place_checkins (user_id, checked_in_at);

alter table public.place_checkins enable row level security;
create policy "auth read own checkins" on public.place_checkins for select
  using (auth.uid() = user_id);
create policy "auth insert own checkins" on public.place_checkins for insert
  with check (auth.uid() = user_id);

-- 5. Saved Tours (per-user tour bookmarks)
create table if not exists public.saved_tours (
  id         bigint generated always as identity primary key,
  user_id    uuid not null,
  tour_data  jsonb not null,
  saved_at   timestamptz default now()
);

alter table public.saved_tours enable row level security;
create policy "auth read own saved_tours" on public.saved_tours for select
  using (auth.uid() = user_id);
create policy "auth insert own saved_tours" on public.saved_tours for insert
  with check (auth.uid() = user_id);
create policy "auth delete own saved_tours" on public.saved_tours for delete
  using (auth.uid() = user_id);
