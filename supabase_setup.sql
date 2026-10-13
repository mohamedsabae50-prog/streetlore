
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
  enable_chat boolean not null default true,
  enable_gallery boolean not null default true,
  created_at   timestamptz default now(),
  updated_at   timestamptz default now()
);

create index if not exists places_category_idx on public.places (category);
create index if not exists places_is_featured_idx on public.places (is_featured);

create table if not exists public.tours (
  id          text primary key,
  title       text not null,
  title_ar    text,
  description text not null,
  description_ar text,
  duration    text not null,
  duration_ar text,
  category    text,
  category_ar text,
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
drop policy if exists "owner delete place-images" on storage.objects;
drop policy if exists "admin can delete place-images" on storage.objects;

create policy "public read place-images"   on storage.objects for select using (bucket_id = 'place-images');
create policy "auth upload place-images"   on storage.objects for insert with check (bucket_id = 'place-images' and auth.role() = 'authenticated');
create policy "auth update place-images"   on storage.objects for update using (bucket_id = 'place-images' and auth.role() = 'authenticated');
create policy "owner delete place-images" on storage.objects for delete
  to authenticated using (
    bucket_id = 'place-images'
    and name like 'user-photos/%'
    and owner_id = auth.uid()::text
  );
create policy "admin can delete place-images" on storage.objects for delete
  to authenticated using (
    bucket_id = 'place-images'
    and lower(coalesce(auth.jwt() ->> 'email', '')) =
      lower('mohamedsabae50@gmail.com')
  );

create or replace view public.tours_with_places as
select
  t.id,
  t.title,
  t.title_ar,
  t.description,
  t.description_ar,
  t.duration,
  t.duration_ar,
  t.category,
  t.category_ar,
  t.image_url,
  t.created_at,
  t.updated_at,
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

-- 2. User-contributed place photos (metadata in Postgres, files in place-images)
create table if not exists public.place_photos (
  id         text primary key,
  place_id   text not null references public.places(id) on delete cascade,
  user_id    text,
  user_name  text not null default 'Traveler',
  image_url  text not null,
  caption_en text not null default '',
  caption_ar text not null default '',
  likes      integer not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists place_photos_place_created_idx
  on public.place_photos (place_id, created_at desc);

alter table public.place_photos enable row level security;
create policy "Public read place_photos" on public.place_photos for select
  using (true);
create policy "Owner insert place_photos" on public.place_photos for insert
  with check (auth.uid()::text = user_id);

-- 2b. Profiles used by the social/activity feed
create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  username text,
  is_pro boolean not null default false,
  updated_at timestamptz not null default now()
);

create unique index if not exists profiles_username_lower_unique
  on public.profiles (lower(username))
  where username is not null;

alter table public.profiles enable row level security;
drop policy if exists "users can read own profile" on public.profiles;
create policy "users can read own profile" on public.profiles for select
  using (auth.uid() = user_id);
drop policy if exists "authenticated can read public profile fields"
  on public.profiles;
create policy "authenticated can read public profile fields" on public.profiles
  for select to authenticated using (true);

revoke insert, update, delete on public.profiles from anon, authenticated;
grant select on public.profiles to authenticated;
grant all on public.profiles to service_role;

create or replace function public.create_user_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (user_id)
  values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_profile on auth.users;
create trigger on_auth_user_created_profile
  after insert on auth.users
  for each row execute function public.create_user_profile();

insert into public.profiles (user_id)
select id from auth.users
on conflict (user_id) do nothing;

-- 3. Leaderboard (gamification stats)
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
  current_streak  integer not null default 0,
  longest_streak  integer not null default 0,
  total_visit_days integer not null default 0,
  last_visit_date timestamptz,
  updated_at      timestamptz default now()
);

alter table public.leaderboard enable row level security;
create policy "public read leaderboard" on public.leaderboard for select using (true);
create policy "auth upsert own leaderboard" on public.leaderboard for insert
  with check (auth.uid() = user_id);
create policy "auth update own leaderboard" on public.leaderboard for update
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

create or replace function public.get_city_leaderboard(
  p_period text default 'week',
  p_metric text default 'check_ins',
  p_limit integer default 50
)
returns table (
  user_id uuid,
  user_name text,
  avatar_color_hex text,
  total_points integer,
  places_visited integer,
  reviews_posted integer,
  photos_uploaded integer,
  level text,
  badges jsonb,
  current_streak integer,
  longest_streak integer,
  total_visit_days integer,
  last_visit_date timestamptz,
  check_ins bigint,
  hidden_gems bigint,
  score bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_since timestamptz;
begin
  if p_period not in ('week', 'month', 'all_time') then
    raise exception 'Unsupported leaderboard period';
  end if;
  if p_metric not in ('check_ins', 'longest_streak', 'hidden_gems') then
    raise exception 'Unsupported leaderboard metric';
  end if;

  v_since := case p_period
    when 'week' then date_trunc('week', statement_timestamp() at time zone 'UTC') at time zone 'UTC'
    when 'month' then date_trunc('month', statement_timestamp() at time zone 'UTC') at time zone 'UTC'
    else null
  end;

  return query
  with checkin_rollup as (
    select
      cast(checkins.user_id as uuid) as user_id,
      count(*) filter (
        where v_since is null or checkins.checked_in_at >= v_since
      ) as check_ins,
      count(distinct checkins.place_id) filter (
        where places.is_hidden_gem is true
          and (v_since is null or checkins.checked_in_at >= v_since)
      ) as hidden_gems
    from public.place_checkins as checkins
    left join public.places as places on places.id = checkins.place_id
    group by cast(checkins.user_id as uuid)
  ),
  ranked as (
    select
      cast(leaderboard.user_id as uuid) as user_id,
      leaderboard.user_name,
      leaderboard.avatar_color_hex,
      leaderboard.total_points,
      leaderboard.places_visited,
      leaderboard.reviews_posted,
      leaderboard.photos_uploaded,
      leaderboard.level,
      coalesce(leaderboard.badges, '[]'::jsonb) as badges,
      leaderboard.current_streak,
      leaderboard.longest_streak,
      leaderboard.total_visit_days,
      leaderboard.last_visit_date,
      coalesce(checkin_rollup.check_ins, 0) as check_ins,
      coalesce(checkin_rollup.hidden_gems, 0) as hidden_gems,
      case p_metric
        when 'check_ins' then coalesce(checkin_rollup.check_ins, 0)
        when 'longest_streak' then coalesce(leaderboard.longest_streak, 0)
        when 'hidden_gems' then coalesce(checkin_rollup.hidden_gems, 0)
      end as score
    from public.leaderboard as leaderboard
    left join checkin_rollup
      on checkin_rollup.user_id = leaderboard.user_id
  )
  select
    ranked.user_id,
    ranked.user_name,
    ranked.avatar_color_hex,
    ranked.total_points,
    ranked.places_visited,
    ranked.reviews_posted,
    ranked.photos_uploaded,
    ranked.level,
    ranked.badges,
    ranked.current_streak,
    ranked.longest_streak,
    ranked.total_visit_days,
    ranked.last_visit_date,
    ranked.check_ins,
    ranked.hidden_gems,
    ranked.score
  from ranked
  order by ranked.score desc, ranked.total_points desc, ranked.user_name
  limit greatest(1, least(coalesce(p_limit, 50), 100));
end;
$$;

revoke all on function public.get_city_leaderboard(text, text, integer) from public;
grant execute on function public.get_city_leaderboard(text, text, integer) to anon, authenticated;

create or replace function public.get_following_activity(p_limit integer default 50)
returns table(
  event_id text,
  event_type text,
  actor_id uuid,
  actor_username text,
  target_id text,
  title text,
  description text,
  occurred_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_checkin_count integer;
  v_badge_count integer;
  v_suggestion_count integer;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select count(*) into v_checkin_count
    from public.place_checkins as checkins
    join public.user_follows as follows
      on follows.following_id = checkins.user_id
    where follows.follower_id = auth.uid()
    limit 1;

  select count(*) into v_badge_count
    from public.leaderboard as leaderboard
    join public.user_follows as follows
      on follows.following_id = leaderboard.user_id
    where follows.follower_id = auth.uid()
    limit 1;

  select count(*) into v_suggestion_count
    from public.suggested_places as suggestions
    join public.user_follows as follows
      on follows.following_id = suggestions.user_id
    where follows.follower_id = auth.uid()
      and suggestions.status = 'approved'
    limit 1;

  return query
  with followed_users as (
    select follows.following_id
    from public.user_follows as follows
    where follows.follower_id = auth.uid()
  ),
  activities as (
    select
      'checkin:' || checkins.id::text as event_id,
      'checkin'::text as event_type,
      checkins.user_id as actor_id,
      profile.username as actor_username,
      checkins.place_id as target_id,
      coalesce(places.name, checkins.place_id) as title,
      'Checked in at a place'::text as description,
      checkins.checked_in_at as occurred_at
    from public.place_checkins as checkins
    join followed_users on followed_users.following_id = checkins.user_id
    left join public.profiles as profile on profile.user_id = checkins.user_id
    left join public.places as places on places.id = checkins.place_id

    union all

    select
      'badge:' || leaderboard.user_id::text || ':' || coalesce(badge->>'id', ''),
      'badge'::text,
      leaderboard.user_id,
      profile.username,
      coalesce(badge->>'id', ''),
      coalesce(badge->>'name', badge->>'id', 'Achievement'),
      coalesce(badge->>'description', 'Unlocked an achievement'),
      coalesce(nullif(badge->>'earned_at', '')::timestamptz, leaderboard.updated_at)
    from public.leaderboard as leaderboard
    join followed_users on followed_users.following_id = leaderboard.user_id
    join public.profiles as profile on profile.user_id = leaderboard.user_id
    cross join lateral jsonb_array_elements(coalesce(leaderboard.badges, '[]'::jsonb)) as badge

    union all

    select
      'suggestion:' || suggestions.id::text,
      'suggestion'::text,
      suggestions.user_id,
      profile.username,
      suggestions.id::text,
      suggestions.title,
      suggestions.description,
      suggestions.created_at
    from public.suggested_places as suggestions
    join followed_users on followed_users.following_id = suggestions.user_id
    join public.profiles as profile on profile.user_id = suggestions.user_id
    where suggestions.status = 'approved'
  )
  select
    activities.event_id,
    activities.event_type,
    activities.actor_id,
    activities.actor_username,
    activities.target_id,
    activities.title,
    activities.description,
    activities.occurred_at
  from activities
  order by activities.occurred_at desc nulls last
  limit greatest(1, least(coalesce(p_limit, 50), 100));
end;
$$;

revoke all on function public.get_following_activity(integer) from public, anon;
grant execute on function public.get_following_activity(integer) to authenticated;

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
