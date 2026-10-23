BEGIN;

WITH image_fixes (id, image_url) AS (
  VALUES
    (
      'alex_kebdet_el_fallah',
      'https://images.unsplash.com/photo-1558030006-450675393462?auto=format&fit=crop&w=1200&q=85'
    ),
    (
      'alex_city_centre_alexandria',
      'https://images.unsplash.com/photo-1578916171728-46686eac8d58?auto=format&fit=crop&w=1200&q=85'
    ),
    (
      'alex_gleem_bay_promenade',
      'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=85'
    ),
    (
      'alex_designia_mall',
      'https://images.unsplash.com/photo-1567958451986-2de427a4a0be?auto=format&fit=crop&w=1200&q=85'
    ),
    (
      'alex_green_plaza_mall',
      'https://images.unsplash.com/photo-1534452203293-494d7ddbf7e0?auto=format&fit=crop&w=1200&q=85'
    ),
    (
      'alex_tivoli_dome',
      'https://images.unsplash.com/photo-1555529669-e69e7aa0ba9a?auto=format&fit=crop&w=1200&q=85'
    )
)
UPDATE public.places AS place
SET image_url = image_fixes.image_url,
    image_urls = ARRAY[image_fixes.image_url]
FROM image_fixes
WHERE place.id = image_fixes.id;

UPDATE public.places
SET name = name_en,
    description = description_en,
    rating = greatest(4.4, least(4.9, rating)),
    governorate = 'alexandria';

DO $$
BEGIN
  IF (SELECT count(*) FROM public.places) <> 78 THEN
    RAISE EXCEPTION 'Expected 78 places after image and metadata repair';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.places
    WHERE name IS NULL OR btrim(name) = ''
       OR name_en IS NULL OR btrim(name_en) = ''
       OR name_ar IS NULL OR btrim(name_ar) = ''
       OR description IS NULL OR btrim(description) = ''
       OR description_en IS NULL OR btrim(description_en) = ''
       OR description_ar IS NULL OR btrim(description_ar) = ''
       OR image_url IS NULL OR btrim(image_url) = ''
       OR open_hours IS NULL OR btrim(open_hours) = ''
       OR rating IS NULL OR rating < 4.4 OR rating > 4.9
       OR lat IS NULL OR lng IS NULL
       OR governorate IS DISTINCT FROM 'alexandria'
  ) THEN
    RAISE EXCEPTION 'Place metadata repair left required fields invalid';
  END IF;

  IF (
    SELECT count(DISTINCT split_part(image_url, '?', 1))
    FROM public.places
  ) <> 78 THEN
    RAISE EXCEPTION 'Place image URLs are not unique by base URL';
  END IF;
END;
$$;

COMMIT;
