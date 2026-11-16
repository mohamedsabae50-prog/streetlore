BEGIN;

DO $migration$
BEGIN
  IF to_regclass('public.user_visits') IS NULL THEN
    TRUNCATE TABLE public.place_checkins;
  ELSE
    EXECUTE
      'TRUNCATE TABLE public.place_checkins, public.user_visits';
  END IF;
END;
$migration$;

UPDATE public.leaderboard
SET total_points = 0,
    places_visited = 0,
    reviews_posted = 0,
    photos_uploaded = 0,
    chat_messages_sent = 0,
    current_streak = 0,
    longest_streak = 0,
    total_visit_days = 0,
    last_visit_date = NULL,
    badges = '[]'::jsonb,
    level = 'Explorer';

COMMIT;
