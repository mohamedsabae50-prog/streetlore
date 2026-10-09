ALTER TABLE public.tours
  ADD COLUMN IF NOT EXISTS title_ar text,
  ADD COLUMN IF NOT EXISTS description_ar text,
  ADD COLUMN IF NOT EXISTS duration_ar text;

CREATE OR REPLACE VIEW public.tours_with_places AS
SELECT
  t.id,
  t.title,
  t.title_ar,
  t.description,
  t.description_ar,
  t.duration,
  t.duration_ar,
  t.image_url,
  t.created_at,
  t.updated_at,
  COALESCE(
    (
      SELECT json_agg(
        json_build_object(
          'id', p.id,
          'name', p.name,
          'description', p.description,
          'imageUrl', p.image_url,
          'rating', p.rating,
          'category', p.category,
          'lat', p.lat,
          'lng', p.lng,
          'address', p.address,
          'openHours', p.open_hours,
          'reviewCount', p.review_count,
          'priceLevel', p.price_level,
          'priceNote', p.price_note,
          'priceLocalEgp', p.price_local_egp,
          'priceForeignerEgp', p.price_foreigner_egp,
          'isHiddenGem', p.is_hidden_gem,
          'isFeatured', p.is_featured
        )
        ORDER BY tp.position
      )
      FROM public.tour_places tp
      JOIN public.places p ON p.id = tp.place_id
      WHERE tp.tour_id = t.id
    ),
    '[]'::json
  ) AS places
FROM public.tours t;

INSERT INTO public.tours (
  id, title, title_ar, description, description_ar,
  duration, duration_ar, image_url
) VALUES
  (
    'tour_roman_alexandria',
    'Roman Alexandria',
    'الإسكندرية الرومانية',
    'Explore the Roman theatre, Pompey''s Pillar, and the Graeco-Roman Museum in the heart of ancient Alexandria.',
    'اكتشف المسرح الروماني وعمود السواري والمتحف اليوناني الروماني في قلب الإسكندرية القديمة.',
    '4 Hours',
    '4 ساعات',
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
