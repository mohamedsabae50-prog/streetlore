CREATE OR REPLACE FUNCTION public.search_users(
  p_query text,
  p_limit integer DEFAULT 30
)
RETURNS TABLE (
  user_id uuid,
  username text,
  display_name text,
  is_following boolean
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    profile.user_id,
    btrim(profile.username),
    COALESCE(
      NULLIF(btrim(to_jsonb(profile)->>'display_name'), ''),
      NULLIF(btrim(to_jsonb(profile)->>'full_name'), ''),
      NULLIF(btrim(to_jsonb(leaderboard)->>'display_name'), ''),
      NULLIF(btrim(to_jsonb(leaderboard)->>'full_name'), ''),
      NULLIF(btrim(to_jsonb(leaderboard)->>'user_name'), ''),
      btrim(profile.username)
    ),
    EXISTS (
      SELECT 1
      FROM public.user_follows AS follows
      WHERE follows.follower_id = auth.uid()
        AND follows.following_id = profile.user_id
    )
  FROM public.profiles AS profile
  LEFT JOIN public.leaderboard AS leaderboard
    ON leaderboard.user_id::text = profile.user_id::text
  WHERE auth.uid() IS NOT NULL
    AND profile.user_id <> auth.uid()
    AND NULLIF(btrim(profile.username), '') IS NOT NULL
    AND btrim(profile.username) NOT ILIKE 'explorer%'
    AND COALESCE(
      NULLIF(btrim(to_jsonb(profile)->>'display_name'), ''),
      NULLIF(btrim(to_jsonb(profile)->>'full_name'), ''),
      NULLIF(btrim(to_jsonb(leaderboard)->>'display_name'), ''),
      NULLIF(btrim(to_jsonb(leaderboard)->>'full_name'), ''),
      NULLIF(btrim(to_jsonb(leaderboard)->>'user_name'), ''),
      ''
    ) NOT ILIKE 'explorer%'
    AND (
      length(btrim(COALESCE(p_query, ''))) = 0
      OR (
        length(btrim(p_query)) >= 2
        AND (
          profile.username ILIKE '%' || btrim(p_query) || '%'
          OR COALESCE(to_jsonb(profile)->>'display_name', '') ILIKE
             '%' || btrim(p_query) || '%'
          OR COALESCE(to_jsonb(profile)->>'full_name', '') ILIKE
             '%' || btrim(p_query) || '%'
          OR COALESCE(to_jsonb(leaderboard)->>'display_name', '') ILIKE
             '%' || btrim(p_query) || '%'
          OR COALESCE(to_jsonb(leaderboard)->>'full_name', '') ILIKE
             '%' || btrim(p_query) || '%'
          OR COALESCE(to_jsonb(leaderboard)->>'user_name', '') ILIKE
             '%' || btrim(p_query) || '%'
        )
      )
    )
  ORDER BY COALESCE(leaderboard.total_points, 0) DESC,
           btrim(profile.username), profile.user_id
  LIMIT LEAST(GREATEST(COALESCE(p_limit, 30), 1), 50);
$$;

REVOKE ALL ON FUNCTION public.search_users(text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.search_users(text, integer) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_public_profile(target_user_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT jsonb_build_object(
    'user_id', profile.user_id,
    'username', btrim(profile.username),
    'display_name', COALESCE(
      NULLIF(btrim(to_jsonb(profile)->>'display_name'), ''),
      NULLIF(btrim(to_jsonb(profile)->>'full_name'), ''),
      NULLIF(btrim(to_jsonb(leaderboard)->>'display_name'), ''),
      NULLIF(btrim(to_jsonb(leaderboard)->>'full_name'), ''),
      NULLIF(btrim(to_jsonb(leaderboard)->>'user_name'), ''),
      btrim(profile.username)
    )
  )
  FROM public.profiles AS profile
  LEFT JOIN public.leaderboard AS leaderboard
    ON leaderboard.user_id::text = profile.user_id::text
  WHERE auth.uid() IS NOT NULL
    AND profile.user_id = target_user_id
    AND NULLIF(btrim(profile.username), '') IS NOT NULL
    AND btrim(profile.username) NOT ILIKE 'explorer%'
    AND COALESCE(
      NULLIF(btrim(to_jsonb(profile)->>'display_name'), ''),
      NULLIF(btrim(to_jsonb(profile)->>'full_name'), ''),
      NULLIF(btrim(to_jsonb(leaderboard)->>'display_name'), ''),
      NULLIF(btrim(to_jsonb(leaderboard)->>'full_name'), ''),
      NULLIF(btrim(to_jsonb(leaderboard)->>'user_name'), ''),
      ''
    ) NOT ILIKE 'explorer%'
  LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.get_public_profile(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_public_profile(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_user_visited_places(target_user_id uuid)
RETURNS TABLE (
  id text,
  name_en text,
  name_ar text,
  description_en text,
  description_ar text,
  image_url text,
  image_urls text[],
  category text,
  lat double precision,
  lng double precision,
  address text,
  address_ar text,
  checked_in_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    places.id::text,
    COALESCE(NULLIF(to_jsonb(places)->>'name_en', ''), places.name),
    NULLIF(to_jsonb(places)->>'name_ar', ''),
    COALESCE(NULLIF(to_jsonb(places)->>'description_en', ''), places.description),
    NULLIF(to_jsonb(places)->>'description_ar', ''),
    places.image_url,
    COALESCE(places.image_urls, ARRAY[]::text[]),
    places.category,
    places.lat::double precision,
    places.lng::double precision,
    places.address,
    NULLIF(to_jsonb(places)->>'address_ar', ''),
    checkins.checked_in_at::timestamptz
  FROM public.place_checkins AS checkins
  JOIN public.places AS places
    ON places.id::text = checkins.place_id::text
  WHERE auth.uid() IS NOT NULL
    AND checkins.user_id::text = target_user_id::text
  ORDER BY checkins.checked_in_at DESC NULLS LAST, places.id;
$$;

REVOKE ALL ON FUNCTION public.get_user_visited_places(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_user_visited_places(uuid) TO authenticated;

UPDATE public.places
SET category = 'Culture',
    category_ar = 'ثقافة'
WHERE id = '13cf4401-ce36-4560-9398-fb81cbf0f28c';

DELETE FROM public.tour_places AS tour_places
WHERE EXISTS (
  SELECT 1
  FROM public.places AS places
  WHERE places.category = 'Streets'
    AND places.id::text = tour_places.place_id::text
);

DELETE FROM public.places
WHERE category = 'Streets';

INSERT INTO public.places (
  id, name, name_en, name_ar, description, description_en, description_ar,
  category, category_ar, image_url, image_urls, lat, lng, address, address_ar,
  open_hours, rating, review_count, price_level, price_note,
  price_local_egp, price_foreigner_egp, is_featured
) VALUES
(
  'alex_royal_jewelry_museum',
  'Royal Jewelry Museum', 'Royal Jewelry Museum', 'متحف المجوهرات الملكية',
  'A former royal palace in Zizinia displaying the jewelry, ceremonial objects and personal collections of Egypt’s Muhammad Ali dynasty. The richly decorated palace rooms are part of the visit.',
  'A former royal palace in Zizinia displaying the jewelry, ceremonial objects and personal collections of Egypt’s Muhammad Ali dynasty. The richly decorated palace rooms are part of the visit.',
  'قصر ملكي سابق في زيزينيا يعرض مجوهرات ومقتنيات أسرة محمد علي، إلى جانب القاعات المزخرفة التي تشكل جزءاً من تجربة الزيارة.',
  'Culture', 'ثقافة',
  'https://upload.wikimedia.org/wikipedia/commons/f/f6/AlexRoyalJewelleryMusLeft.jpg',
  ARRAY[]::text[],
  31.2494, 29.9665, '27 Ahmed Yehia Pasha Street, Zizinia, Alexandria',
  '٢٧ شارع أحمد يحيى باشا، زيزينيا، الإسكندرية',
  '9:00 AM - 5:00 PM', 4.6, 0, 'cheap',
  'Paid museum admission; verify current ticket prices before visiting',
  NULL, NULL, true
),
(
  'alex_cavafy_museum',
  'Cavafy Museum', 'Cavafy Museum', 'متحف كفافيس',
  'The preserved Alexandria apartment of Greek poet Constantine P. Cavafy, presented with archival material and objects tracing his life and literary work in the city.',
  'The preserved Alexandria apartment of Greek poet Constantine P. Cavafy, presented with archival material and objects tracing his life and literary work in the city.',
  'شقة الشاعر اليوناني قسطنطين كفافيس المحفوظة في الإسكندرية، وتضم مقتنيات ووثائق تستعرض حياته وأعماله الأدبية وصلته بالمدينة.',
  'Culture', 'ثقافة',
  'https://upload.wikimedia.org/wikipedia/commons/4/47/AlexCavafyMuseum.jpg',
  ARRAY[
    'https://thumb.wikimedia.org/wikipedia/commons/thumb/9/9b/AlexCavafyHouse.jpg/1280px-AlexCavafyHouse.jpg',
    'https://upload.wikimedia.org/wikipedia/commons/8/80/Cavafy_entrance.jpg'
  ],
  31.1984, 29.9018, '4 Sharm El Sheikh Street, Alexandria',
  '٤ شارع شرم الشيخ، الإسكندرية',
  'Check current visiting hours before visiting', 4.5, 0, 'cheap',
  'Paid admission; verify opening and ticket details in advance',
  NULL, NULL, true
),
(
  'alex_nabi_daniel_mosque',
  'Nabi Daniel Mosque',
  'Nabi Daniel Mosque', 'مسجد النبي دانيال',
  'A landmark historic mosque in central Alexandria, known for its distinctive Ottoman-era architecture and long-standing place in the city’s religious and urban history.',
  'A landmark historic mosque in central Alexandria, known for its distinctive Ottoman-era architecture and long-standing place in the city’s religious and urban history.',
  'مسجد تاريخي بارز في وسط الإسكندرية، يشتهر بعمارة تعود إلى العصر العثماني ومكانته الراسخة في التاريخ الديني والعمراني للمدينة.',
  'Mosques', 'مساجد',
  'https://upload.wikimedia.org/wikipedia/commons/5/59/Nabi_Daniel_Mosque.JPG',
  ARRAY[]::text[],
  31.1981, 29.9017, 'Nabi Daniel Street, central Alexandria',
  'شارع النبي دانيال، وسط الإسكندرية',
  '9:00 AM - 5:00 PM', 4.5, 0, 'cheap',
  'Free entry to the mosque; observe prayer times and visitor etiquette',
  NULL, NULL, true
),
(
  'alex_sayed_darwish_theatre',
  'Sayed Darwish Theatre (Alexandria Opera House)',
  'Sayed Darwish Theatre (Alexandria Opera House)',
  'مسرح سيد درويش (دار أوبرا الإسكندرية)',
  'Alexandria’s historic opera house, opened in 1921 and named for Egyptian composer Sayed Darwish. The restored Italianate theatre remains an active venue for opera, concerts and cultural performances.',
  'Alexandria’s historic opera house, opened in 1921 and named for Egyptian composer Sayed Darwish. The restored Italianate theatre remains an active venue for opera, concerts and cultural performances.',
  'دار أوبرا الإسكندرية التاريخية، افتُتحت عام ١٩٢١ وسُمّيت باسم الموسيقار المصري سيد درويش. لا يزال المسرح الإيطالي الطراز يستضيف الأوبرا والحفلات والعروض الثقافية.',
  'Culture', 'ثقافة',
  'https://thumb.wikimedia.org/wikipedia/commons/thumb/5/5d/Sayed_Darwish_Theatre_in_Alexandria%2C_76.JPG/1280px-Sayed_Darwish_Theatre_in_Alexandria%2C_76.JPG',
  ARRAY[]::text[],
  31.1995, 29.9038, 'Fouad Street, Alexandria',
  'شارع فؤاد، الإسكندرية',
  'Performance schedule varies; check the theatre programme',
  4.6, 0, 'moderate',
  'Ticketed performances; prices and schedule vary',
  NULL, NULL, true
)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  name_en = EXCLUDED.name_en,
  name_ar = EXCLUDED.name_ar,
  description = EXCLUDED.description,
  description_en = EXCLUDED.description_en,
  description_ar = EXCLUDED.description_ar,
  category = EXCLUDED.category,
  category_ar = EXCLUDED.category_ar,
  image_url = EXCLUDED.image_url,
  image_urls = EXCLUDED.image_urls,
  lat = EXCLUDED.lat,
  lng = EXCLUDED.lng,
  address = EXCLUDED.address,
  address_ar = EXCLUDED.address_ar,
  open_hours = EXCLUDED.open_hours,
  price_level = EXCLUDED.price_level,
  price_note = EXCLUDED.price_note,
  is_featured = EXCLUDED.is_featured;

UPDATE public.places AS places
SET image_url = correction.image_url,
    image_urls = ARRAY[correction.image_url]::text[]
FROM (VALUES
  ('50', 'https://thumb.wikimedia.org/wikipedia/commons/thumb/5/5c/AlexAttarinOutside.jpg/1280px-AlexAttarinOutside.jpg'),
  ('32', 'https://thumb.wikimedia.org/wikipedia/commons/thumb/8/84/San_Stefano_Grand_Plaza%2C_Alexandria%2C_Egypt.jpg/1280px-San_Stefano_Grand_Plaza%2C_Alexandria%2C_Egypt.jpg'),
  ('49', 'https://thumb.wikimedia.org/wikipedia/commons/thumb/d/d0/Nabi_Daniel_Mosque_Today.jpg/1280px-Nabi_Daniel_Mosque_Today.jpg'),
  ('55', 'https://thumb.wikimedia.org/wikipedia/commons/thumb/b/b0/Saad_Zaghloul_square_in_Alexandria_01.jpg/1280px-Saad_Zaghloul_square_in_Alexandria_01.jpg'),
  ('57', 'https://thumb.wikimedia.org/wikipedia/commons/thumb/4/48/Mustafa_Kamel_Necropolis%2C_Alexandria%2C_August_2005-1.jpg/1280px-Mustafa_Kamel_Necropolis%2C_Alexandria%2C_August_2005-1.jpg'),
  ('46', 'https://thumb.wikimedia.org/wikipedia/commons/thumb/9/9b/AlexCavafyHouse.jpg/1280px-AlexCavafyHouse.jpg'),
  ('51', 'https://thumb.wikimedia.org/wikipedia/commons/thumb/2/21/Alexandria_Zoo_1.jpg/1280px-Alexandria_Zoo_1.jpg'),
  ('53', 'https://thumb.wikimedia.org/wikipedia/commons/thumb/4/43/Aquarium_Alex_31.JPG/1280px-Aquarium_Alex_31.JPG')
) AS correction(id, image_url)
WHERE places.id::text = correction.id;

INSERT INTO public.tour_places (tour_id, place_id, position)
SELECT tours.id, curated.place_id, curated.position
FROM (VALUES
  ('t7', 'alex_royal_jewelry_museum', 5),
  ('t10', 'alex_cavafy_museum', 3),
  ('t1', 'alex_nabi_daniel_mosque', 4),
  ('t6', 'alex_sayed_darwish_theatre', 4)
) AS curated(tour_id, place_id, position)
JOIN public.tours AS tours ON tours.id = curated.tour_id
ON CONFLICT (tour_id, place_id) DO UPDATE
SET position = EXCLUDED.position;

UPDATE public.tours
SET image_url = 'https://thumb.wikimedia.org/wikipedia/commons/thumb/4/48/Mustafa_Kamel_Necropolis%2C_Alexandria%2C_August_2005-1.jpg/1280px-Mustafa_Kamel_Necropolis%2C_Alexandria%2C_August_2005-1.jpg'
WHERE id = 't8';

UPDATE public.tours
SET image_url = 'https://thumb.wikimedia.org/wikipedia/commons/thumb/f/f6/AlexRoyalJewelleryMusLeft.jpg/1280px-AlexRoyalJewelleryMusLeft.jpg'
WHERE id = 't7';

UPDATE public.tours
SET image_url = 'https://thumb.wikimedia.org/wikipedia/commons/thumb/9/9b/AlexCavafyHouse.jpg/1280px-AlexCavafyHouse.jpg'
WHERE id = 't10'
  AND (image_url IS NULL OR image_url = '');

UPDATE public.tours
SET image_url = 'https://thumb.wikimedia.org/wikipedia/commons/thumb/2/21/Alexandria_Zoo_1.jpg/1280px-Alexandria_Zoo_1.jpg'
WHERE id = 't9';

UPDATE public.tours
SET image_url = 'https://thumb.wikimedia.org/wikipedia/commons/thumb/6/65/Mansheya%2C_Alexandria.jpg/1280px-Mansheya%2C_Alexandria.jpg'
WHERE id = 't10';

UPDATE public.tours
SET image_url = 'https://thumb.wikimedia.org/wikipedia/commons/thumb/7/71/Egypt%2C_Alexandria%2C_The_Corniche_of_Alexandria.jpg/1280px-Egypt%2C_Alexandria%2C_The_Corniche_of_Alexandria.jpg'
WHERE id = 'tour_city_highlights';
