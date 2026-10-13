ALTER TABLE public.tours
  ADD COLUMN IF NOT EXISTS title_ar text,
  ADD COLUMN IF NOT EXISTS description_ar text,
  ADD COLUMN IF NOT EXISTS duration_ar text,
  ADD COLUMN IF NOT EXISTS category text,
  ADD COLUMN IF NOT EXISTS category_ar text;

INSERT INTO public.tours (
  id, title, title_ar, description, description_ar,
  duration, duration_ar, category, category_ar, image_url
) VALUES
  (
    'tour_roman_alexandria',
    'Roman Alexandria',
    'الإسكندرية الرومانية',
    'Explore the Roman theatre, Pompey''s Pillar, and the Graeco-Roman Museum in the heart of ancient Alexandria.',
    'اكتشف المسرح الروماني وعمود السواري والمتحف اليوناني الروماني في قلب الإسكندرية القديمة.',
    '4 Hours',
    '4 ساعات',
    'Historical',
    'تاريخي',
    'https://upload.wikimedia.org/wikipedia/commons/f/f9/Alexandria%2C_Kom_el-Dikka%2C_Theatre.JPG'
  ),
  (
    'tour_city_highlights',
    'Alexandria City Highlights',
    'أبرز معالم الإسكندرية',
    'Visit Alexandria''s National Museum and Bibliotheca Alexandrina, with time to enjoy the Mediterranean Corniche.',
    'زر المتحف الوطني ومكتبة الإسكندرية، واستمتع بأجواء كورنيش البحر المتوسط.',
    '5 Hours',
    '5 ساعات',
    'City Highlights',
    'أبرز المعالم',
    'https://upload.wikimedia.org/wikipedia/commons/7/70/Stanley_Bridge%2C_Alexandria%2C_Jan._2019-1.jpg'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.tour_places (tour_id, place_id, position)
SELECT 'tour_roman_alexandria', places.id, places.position
FROM (VALUES ('43', 0), ('9', 1), ('7', 2)) AS places(id, position)
WHERE EXISTS (
  SELECT 1 FROM public.tours WHERE id = 'tour_roman_alexandria'
)
AND EXISTS (
  SELECT 1 FROM public.places WHERE id = places.id
)
ON CONFLICT (tour_id, place_id) DO NOTHING;

INSERT INTO public.tour_places (tour_id, place_id, position)
SELECT 'tour_city_highlights', places.id, places.position
FROM (VALUES ('11', 0), ('2', 1), ('38', 2), ('8', 3)) AS places(id, position)
WHERE EXISTS (
  SELECT 1 FROM public.tours WHERE id = 'tour_city_highlights'
)
AND EXISTS (
  SELECT 1 FROM public.places WHERE id = places.id
)
ON CONFLICT (tour_id, place_id) DO NOTHING;

UPDATE public.tours AS t
SET image_url = COALESCE(
  (
    SELECT NULLIF(BTRIM(p.image_url), '')
    FROM public.tour_places AS tp
    JOIN public.places AS p ON p.id = tp.place_id
    WHERE tp.tour_id = t.id
      AND NULLIF(BTRIM(p.image_url), '') IS NOT NULL
    ORDER BY (
      SELECT COUNT(DISTINCT other_tp.tour_id)
      FROM public.tour_places AS other_tp
      JOIN public.places AS other_p ON other_p.id = other_tp.place_id
      WHERE other_tp.tour_id <> t.id
        AND NULLIF(BTRIM(other_p.image_url), '') = NULLIF(BTRIM(p.image_url), '')
    ), tp.position, p.id
    LIMIT 1
  ),
  ''
)
WHERE EXISTS (
  SELECT 1
  FROM public.tour_places AS tp
  WHERE tp.tour_id = t.id
);
