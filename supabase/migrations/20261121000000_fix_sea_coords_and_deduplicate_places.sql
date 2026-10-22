BEGIN;

WITH corrected_places (
  id,
  normalized_name,
  normalized_name_ar,
  lat,
  lng
) AS (
  VALUES
    ('alex_alban_swissra', 'albanswissra', 'البانسويسرا', 31.2108, 29.9225),
    ('alex_tivoli_dome', 'tivolidomealexandria', 'تيفولي دومالإسكندرية', 31.2255, 29.9435),
    ('alex_latino_cafe', 'latinocafe', 'لاتينوكافيه', 31.2342, 29.9545),
    ('alex_carlos_cafe', 'carloscafe', 'كارلوسكافيه', 31.2384, 29.9590),
    ('alex_pablo_cafe', 'pablocafelounge', 'بابلوكافيه', 31.2391, 29.9600),
    ('alex_gleem_bay_promenade', 'gleembaypromenade', 'جليمباي', 31.2388, 29.9595),
    ('alex_san_stefano_grand_plaza', 'sanstefanograndplazamall', 'سانستيفانومول', 31.2442, 29.9672),
    ('alex_abou_el_sid', 'abouelsid', 'أبوالسيد', 31.2438, 29.9676),
    ('alex_fresca_cafe_gelateria', 'frescacafegelateria', 'فريسكا', 31.2434, 29.9668),
    ('alex_ibn_hamido_seafood', 'ibnhamidoseafood', 'ابنحميدوللمأكولاتالبحرية', 31.2548, 29.9875),
    ('alex_hosny_grill_seafood', 'hosnygrillseafood', 'حسنيللمشوياتوالمأكولاتالبحرية', 31.2665, 30.0065),
    ('alex_delices_patisserie', 'delicespatisseriecafe', 'ديليس', 31.2006, 29.8992),
    ('alex_trianon_cafe', 'trianoncafepatisserie', 'تريانون', 31.2009, 29.9006),
    ('alex_gad_fouad_street', 'gadramlstation', 'جادمحطةالرمل', 31.2002, 29.9000),
    ('alex_brazilian_coffee', 'braziliancoffeestores', 'البنالبرازيلي', 31.1988, 29.8976),
    ('alex_sofianopoulo_coffee', 'sofianopoulocoffee', 'بنسفيانوبولو', 31.1992, 29.8995),
    ('alex_kebdet_el_fallah', 'kebdetelfallah', 'كبدةالفلاح', 31.1994, 29.9005),
    ('alex_asmak_shaaban', 'asmakshaaban', 'أسماكشعبان', 31.1965, 29.8935),
    ('alex_zanqat_el_sittat_market', 'zanqatelsittattraditionalmarket', 'زنقةالستاتسوقالمنشية', 31.1958, 29.8895),
    ('fallback_qaitbay', 'citadelofqaitbay', 'قلعةقايتباي', 31.2140, 29.8856),
    ('alex_white_blue_greek_club', 'whiteandbluegreeknauticalclub', 'النادياليونانيالبحريوايتآندبلو', 31.2112, 29.8852),
    ('fallback_biblio', 'bibliothecaalexandrina', 'مكتبةالإسكندرية', 31.2070, 29.9095),
    ('fallback_stanley_bridge', 'stanleybridgecorniche', 'كوبريستانليوالكورنيش', 31.2358, 29.9565),
    ('alex_royal_jewelry_museum', 'royaljewelrymuseum', 'متحفالمجوهراتالملكية', 31.2448, 29.9680)
),
targets AS (
  SELECT
    id,
    normalized_name,
    normalized_name_ar,
    lat::double precision AS lat,
    lng::double precision AS lng
  FROM corrected_places
)
UPDATE public.places AS place
SET lat = target.lat,
    lng = target.lng
FROM targets AS target
WHERE coalesce(nullif(place.governorate, ''), 'alexandria') = 'alexandria'
  AND (
    place.id = target.id
    OR regexp_replace(lower(coalesce(place.name_en, place.name, '')), '[^[:alnum:]]', '', 'g') = target.normalized_name
    OR (
      nullif(target.normalized_name_ar, '') IS NOT NULL
      AND regexp_replace(
        translate(lower(coalesce(place.name_ar, '')), 'ًٌٍَُِّْٰـ', ''),
        '[^[:alnum:]]',
        '',
        'g'
      ) = target.normalized_name_ar
    )
  );

CREATE TEMP TABLE streetlore_place_duplicate_map (
  duplicate_id text PRIMARY KEY,
  canonical_id text NOT NULL
) ON COMMIT DROP;

WITH normalized_places AS (
  SELECT
    id,
    coalesce(nullif(governorate, ''), 'alexandria') AS governorate,
    regexp_replace(lower(coalesce(name_en, name, '')), '[^[:alnum:]]', '', 'g') AS name_en,
    regexp_replace(
      translate(lower(coalesce(name_ar, '')), 'ًٌٍَُِّْٰـ', ''),
      '[^[:alnum:]]',
      '',
      'g'
    ) AS name_ar,
    coalesce(length(description_en), 0)
      + coalesce(length(description_ar), 0)
      + coalesce(length(image_url), 0)
      + coalesce(length(name_ar), 0) AS metadata_score
  FROM public.places
),
candidate_pairs AS (
  SELECT
    a.id AS id_a,
    b.id AS id_b,
    CASE
      WHEN ROW(
        CASE WHEN a.id LIKE 'alex\_%' ESCAPE '\' THEN 0 ELSE 1 END,
        -a.metadata_score,
        a.id
      ) <= ROW(
        CASE WHEN b.id LIKE 'alex\_%' ESCAPE '\' THEN 0 ELSE 1 END,
        -b.metadata_score,
        b.id
      ) THEN a.id
      ELSE b.id
    END AS canonical_id,
    CASE
      WHEN ROW(
        CASE WHEN a.id LIKE 'alex\_%' ESCAPE '\' THEN 0 ELSE 1 END,
        -a.metadata_score,
        a.id
      ) <= ROW(
        CASE WHEN b.id LIKE 'alex\_%' ESCAPE '\' THEN 0 ELSE 1 END,
        -b.metadata_score,
        b.id
      ) THEN b.id
      ELSE a.id
    END AS duplicate_id,
    CASE
      WHEN ROW(
        CASE WHEN a.id LIKE 'alex\_%' ESCAPE '\' THEN 0 ELSE 1 END,
        -a.metadata_score,
        a.id
      ) <= ROW(
        CASE WHEN b.id LIKE 'alex\_%' ESCAPE '\' THEN 0 ELSE 1 END,
        -b.metadata_score,
        b.id
      ) THEN ROW(
        CASE WHEN a.id LIKE 'alex\_%' ESCAPE '\' THEN 0 ELSE 1 END,
        -a.metadata_score,
        a.id
      )
      ELSE ROW(
        CASE WHEN b.id LIKE 'alex\_%' ESCAPE '\' THEN 0 ELSE 1 END,
        -b.metadata_score,
        b.id
      )
    END AS canonical_rank
  FROM normalized_places AS a
  JOIN normalized_places AS b
    ON a.id < b.id
   AND a.governorate = b.governorate
  JOIN public.places AS place_a ON place_a.id = a.id
  JOIN public.places AS place_b ON place_b.id = b.id
  WHERE (
    (a.name_en <> '' AND a.name_en = b.name_en)
    OR (a.name_ar <> '' AND a.name_ar = b.name_ar)
    OR (
      6371000.0 * 2 * asin(sqrt(least(
        1.0,
        power(sin(radians(place_b.lat - place_a.lat) / 2), 2)
        + cos(radians(place_a.lat))
          * cos(radians(place_b.lat))
          * power(sin(radians(place_b.lng - place_a.lng) / 2), 2)
      ))) < 45
      AND (
        (
          a.name_en <> ''
          AND b.name_en <> ''
          AND (
            strpos(a.name_en, b.name_en) > 0
            OR strpos(b.name_en, a.name_en) > 0
          )
        )
        OR (
          a.name_ar <> ''
          AND b.name_ar <> ''
          AND (
            strpos(a.name_ar, b.name_ar) > 0
            OR strpos(b.name_ar, a.name_ar) > 0
          )
        )
      )
    )
  )
),
ranked_pairs AS (
  SELECT
    duplicate_id,
    canonical_id,
    row_number() OVER (
      PARTITION BY duplicate_id
      ORDER BY canonical_rank
    ) AS choice
  FROM candidate_pairs
)
INSERT INTO streetlore_place_duplicate_map (duplicate_id, canonical_id)
SELECT duplicate_id, canonical_id
FROM ranked_pairs
WHERE choice = 1
ON CONFLICT (duplicate_id) DO NOTHING;

WITH RECURSIVE resolved AS (
  SELECT
    duplicate_id AS original_id,
    canonical_id,
    ARRAY[duplicate_id, canonical_id]::text[] AS path
  FROM streetlore_place_duplicate_map
  UNION ALL
  SELECT
    resolved.original_id,
    next.canonical_id,
    resolved.path || next.canonical_id
  FROM resolved
  JOIN streetlore_place_duplicate_map AS next
    ON next.duplicate_id = resolved.canonical_id
  WHERE NOT next.canonical_id = ANY(resolved.path)
),
final_map AS (
  SELECT DISTINCT ON (original_id)
    original_id,
    canonical_id
  FROM resolved
  WHERE NOT EXISTS (
    SELECT 1
    FROM streetlore_place_duplicate_map AS next
    WHERE next.duplicate_id = resolved.canonical_id
  )
  ORDER BY original_id, cardinality(path) DESC
)
UPDATE streetlore_place_duplicate_map AS mapping
SET canonical_id = final_map.canonical_id
FROM final_map
WHERE mapping.duplicate_id = final_map.original_id;

DO $$
DECLARE
  child record;
BEGIN
  FOR child IN
    SELECT DISTINCT
      columns.table_schema,
      columns.table_name,
      columns.column_name
    FROM information_schema.columns AS columns
    JOIN information_schema.tables AS tables
      ON tables.table_schema = columns.table_schema
     AND tables.table_name = columns.table_name
    WHERE columns.table_schema = 'public'
      AND columns.column_name = 'place_id'
      AND columns.data_type IN ('text', 'character varying', 'character')
      AND tables.table_type = 'BASE TABLE'
      AND columns.table_name <> 'places'
  LOOP
    IF child.table_name = 'tour_places'
       AND EXISTS (
         SELECT 1
         FROM information_schema.columns
         WHERE table_schema = child.table_schema
           AND table_name = child.table_name
           AND column_name = 'tour_id'
       ) THEN
      EXECUTE format(
        'DELETE FROM %I.%I AS duplicate_ref '
        'USING streetlore_place_duplicate_map AS mapping, %I.%I AS canonical_ref '
        'WHERE duplicate_ref.place_id = mapping.duplicate_id '
        'AND canonical_ref.place_id = mapping.canonical_id '
        'AND canonical_ref.tour_id = duplicate_ref.tour_id',
        child.table_schema,
        child.table_name,
        child.table_schema,
        child.table_name
      );
    END IF;

    EXECUTE format(
      'UPDATE %I.%I AS child '
      'SET %I = mapping.canonical_id '
      'FROM streetlore_place_duplicate_map AS mapping '
      'WHERE child.%I = mapping.duplicate_id',
      child.table_schema,
      child.table_name,
      child.column_name,
      child.column_name
    );
  END LOOP;
END;
$$;

DELETE FROM public.places AS duplicate
USING streetlore_place_duplicate_map AS mapping
WHERE duplicate.id = mapping.duplicate_id;

DO $$
BEGIN
  IF EXISTS (
    WITH normalized_places AS (
      SELECT
        id,
        coalesce(nullif(governorate, ''), 'alexandria') AS governorate,
        regexp_replace(lower(coalesce(name_en, name, '')), '[^[:alnum:]]', '', 'g') AS name_en,
        regexp_replace(
          translate(lower(coalesce(name_ar, '')), 'ًٌٍَُِّْٰـ', ''),
          '[^[:alnum:]]',
          '',
          'g'
        ) AS name_ar
      FROM public.places
    )
    SELECT 1
    FROM normalized_places AS a
    JOIN normalized_places AS b
      ON a.id < b.id
     AND a.governorate = b.governorate
    JOIN public.places AS place_a ON place_a.id = a.id
    JOIN public.places AS place_b ON place_b.id = b.id
    WHERE (a.name_en <> '' AND a.name_en = b.name_en)
       OR (a.name_ar <> '' AND a.name_ar = b.name_ar)
       OR (
         6371000.0 * 2 * asin(sqrt(least(
           1.0,
           power(sin(radians(place_b.lat - place_a.lat) / 2), 2)
           + cos(radians(place_a.lat))
             * cos(radians(place_b.lat))
             * power(sin(radians(place_b.lng - place_a.lng) / 2), 2)
         ))) < 45
         AND (
           (
             a.name_en <> ''
             AND b.name_en <> ''
             AND (strpos(a.name_en, b.name_en) > 0 OR strpos(b.name_en, a.name_en) > 0)
           )
           OR (
             a.name_ar <> ''
             AND b.name_ar <> ''
             AND (strpos(a.name_ar, b.name_ar) > 0 OR strpos(b.name_ar, a.name_ar) > 0)
           )
         )
       )
  ) THEN
    RAISE EXCEPTION 'Place deduplication left duplicate or nearby similar places';
  END IF;
END;
$$;

COMMIT;
