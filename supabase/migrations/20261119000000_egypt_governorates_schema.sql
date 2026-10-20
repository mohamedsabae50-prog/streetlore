ALTER TABLE public.places
  ADD COLUMN IF NOT EXISTS governorate text NOT NULL DEFAULT 'alexandria';

UPDATE public.places
SET governorate = 'alexandria'
WHERE governorate IS NULL OR btrim(governorate) = '';

CREATE INDEX IF NOT EXISTS idx_places_governorate
  ON public.places(governorate);

ALTER TABLE public.tours
  ADD COLUMN IF NOT EXISTS governorate text NOT NULL DEFAULT 'alexandria';

UPDATE public.tours
SET governorate = 'alexandria'
WHERE governorate IS NULL OR btrim(governorate) = '';

CREATE INDEX IF NOT EXISTS idx_tours_governorate
  ON public.tours(governorate);

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS current_governorate text NOT NULL DEFAULT 'alexandria';

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS unlocked_governorates text[] NOT NULL
  DEFAULT ARRAY['alexandria']::text[];

CREATE OR REPLACE VIEW public.tours_with_places AS
SELECT
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
  COALESCE(
    (
      SELECT json_agg(
        json_build_object(
          'id', p.id,
          'name', p.name,
          'description', p.description,
          'imageUrl', p.image_url,
          'image_urls', p.image_urls,
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
          'isFeatured', p.is_featured,
          'governorate', p.governorate
        )
        ORDER BY tp.position
      )
      FROM public.tour_places tp
      JOIN public.places p ON p.id = tp.place_id
      WHERE tp.tour_id = t.id
    ),
    '[]'::json
  ) AS places,
  t.status,
  t.view_count,
  t.is_premium,
  t.is_hidden_gem,
  t.governorate
FROM public.tours t;
