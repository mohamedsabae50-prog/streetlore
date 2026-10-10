CREATE OR REPLACE FUNCTION public.get_admin_analytics()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF lower(coalesce(auth.jwt() ->> 'email', '')) <>
     lower('mohamedsabae50@gmail.com') THEN
    RAISE EXCEPTION 'Admin access required'
      USING ERRCODE = '42501';
  END IF;

  RETURN jsonb_build_object(
    'total_ai_guide_usage',
    coalesce((SELECT sum(used_today) FROM public.ai_quota), 0),
    'total_checkins',
    (SELECT count(*) FROM public.place_checkins),
    'popular_tours',
    coalesce(
      (
        SELECT jsonb_agg(
          jsonb_build_object(
            'id', popular.id,
            'title', popular.title,
            'view_count', popular.view_count
          )
          ORDER BY popular.view_count DESC, popular.title
        )
        FROM (
          SELECT id, title, view_count
          FROM public.tours
          WHERE status = 'published'
          ORDER BY view_count DESC, title
          LIMIT 5
        ) AS popular
      ),
      '[]'::jsonb
    ),
    'top_places_by_checkins',
    coalesce(
      (
        SELECT jsonb_agg(
          jsonb_build_object(
            'place_id', popular.place_id,
            'place_name', popular.place_name,
            'checkin_count', popular.checkin_count
          )
          ORDER BY popular.checkin_count DESC, popular.place_name
        )
        FROM (
          SELECT
            checkins.place_id,
            coalesce(nullif(places.name, ''), checkins.place_id) AS place_name,
            count(*) AS checkin_count
          FROM public.place_checkins AS checkins
          LEFT JOIN public.places AS places
            ON places.id = checkins.place_id
          GROUP BY checkins.place_id, places.name
          ORDER BY count(*) DESC, place_name
          LIMIT 5
        ) AS popular
      ),
      '[]'::jsonb
    )
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.get_admin_analytics() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_admin_analytics() TO authenticated;
