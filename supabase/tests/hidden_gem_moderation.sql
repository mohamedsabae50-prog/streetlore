BEGIN;

SELECT set_config(
  'request.jwt.claims',
  json_build_object(
    'sub', (SELECT id FROM auth.users
             WHERE lower(email) = lower('mohamedsabae50@gmail.com')
             LIMIT 1),
    'email', 'mohamedsabae50@gmail.com',
    'role', 'authenticated'
  )::text,
  true
);

SET LOCAL ROLE authenticated;

DO $$
DECLARE
  v_approved_id uuid;
  v_approved_place_id text;
  v_rejected_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Admin account is required to run this moderation test';
  END IF;

  INSERT INTO public.suggested_places (
    user_id, title, description, category, lat, lng, status
  )
  VALUES (
    auth.uid(), 'Rollback moderation test', 'Temporary integration test',
    'Culture', 31.2, 29.9, 'pending'
  )
  RETURNING id INTO v_approved_id;

  v_approved_place_id := public.moderate_hidden_gem(
    v_approved_id, 'approve'
  );

  IF NOT EXISTS (
    SELECT 1
      FROM public.suggested_places
     WHERE id = v_approved_id AND status = 'approved'
  ) THEN
    RAISE EXCEPTION 'Approval did not update suggestion status';
  END IF;
  IF NOT EXISTS (
    SELECT 1
      FROM public.places
     WHERE id = v_approved_place_id AND is_hidden_gem = true
  ) THEN
    RAISE EXCEPTION 'Approval did not promote a live hidden gem';
  END IF;

  INSERT INTO public.suggested_places (
    user_id, title, description, category, lat, lng, status
  )
  VALUES (
    auth.uid(), 'Rollback rejection test', 'Temporary integration test',
    'Culture', 31.2, 29.9, 'pending'
  )
  RETURNING id INTO v_rejected_id;

  PERFORM public.moderate_hidden_gem(v_rejected_id, 'reject');
  IF NOT EXISTS (
    SELECT 1
      FROM public.suggested_places
     WHERE id = v_rejected_id AND status = 'rejected'
  ) THEN
    RAISE EXCEPTION 'Rejection did not update suggestion status';
  END IF;
END;
$$;

ROLLBACK;
