DROP TRIGGER IF EXISTS sync_place_photo_gallery ON public.place_photos;
DROP FUNCTION IF EXISTS public.sync_place_photo_gallery();
DROP FUNCTION IF EXISTS public.refresh_place_image_urls(text, text);

WITH admin_photos AS (
  SELECT photo.place_id,
         photo.image_url,
         photo.created_at,
         photo.id
    FROM public.place_photos AS photo
    JOIN public.places AS place
      ON place.id = photo.place_id
   WHERE photo.user_id IS NULL
      OR photo.user_id::text IN (
        SELECT admin.user_id::text
          FROM public.admin_users AS admin
      )
      OR lower(btrim(coalesce(photo.user_name, ''))) IN (
        'admin',
        'streetlore',
        'streetlore admin'
      )
      OR btrim(coalesce(photo.image_url, '')) = ANY(
        coalesce(place.image_urls, ARRAY[]::text[])
      )
),
candidates AS (
  SELECT place.id AS place_id,
         nullif(btrim(place.image_url), '') AS url,
         0::bigint AS sort_order
    FROM public.places AS place
  UNION ALL
  SELECT place.id,
         nullif(btrim(existing.url), ''),
         existing.ordinality
    FROM public.places AS place
    CROSS JOIN LATERAL unnest(
      coalesce(place.image_urls, ARRAY[]::text[])
    ) WITH ORDINALITY AS existing(url, ordinality)
  UNION ALL
  SELECT photo.place_id,
         nullif(btrim(photo.image_url), ''),
         1000000 + row_number() OVER (
           PARTITION BY photo.place_id
           ORDER BY photo.created_at NULLS LAST, photo.id
         )
    FROM admin_photos AS photo
),
unique_urls AS (
  SELECT candidate.place_id,
         candidate.url,
         min(candidate.sort_order) AS sort_order
    FROM candidates AS candidate
   WHERE candidate.url IS NOT NULL
   GROUP BY candidate.place_id, candidate.url
),
galleries AS (
  SELECT unique_urls.place_id,
         array_agg(
           unique_urls.url
           ORDER BY unique_urls.sort_order, unique_urls.url
         ) AS image_urls
    FROM unique_urls
   GROUP BY unique_urls.place_id
)
UPDATE public.places AS place
   SET image_urls = coalesce(gallery.image_urls, ARRAY[]::text[]),
       image_url = coalesce(gallery.image_urls[1], '')
  FROM galleries AS gallery
 WHERE place.id = gallery.place_id
   AND (
     place.image_urls IS DISTINCT FROM gallery.image_urls
     OR place.image_url IS DISTINCT FROM coalesce(gallery.image_urls[1], '')
   );

DELETE FROM public.place_photos AS photo
 USING public.places AS place
 WHERE place.id = photo.place_id
   AND (
     photo.user_id IS NULL
     OR photo.user_id::text IN (
       SELECT admin.user_id::text
         FROM public.admin_users AS admin
     )
     OR lower(btrim(coalesce(photo.user_name, ''))) IN (
       'admin',
       'streetlore',
       'streetlore admin'
     )
     OR btrim(coalesce(photo.image_url, '')) = ANY(
       coalesce(place.image_urls, ARRAY[]::text[])
     )
   );
