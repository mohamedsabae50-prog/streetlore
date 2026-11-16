DO $migration$
DECLARE
  v_had_suggestion_type boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1
      FROM information_schema.columns
     WHERE table_schema = 'public'
       AND table_name = 'suggested_places'
       AND column_name = 'suggestion_type'
  )
    INTO v_had_suggestion_type;

  ALTER TABLE public.suggested_places
    ADD COLUMN IF NOT EXISTS is_hidden_gem boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS suggestion_type text NOT NULL DEFAULT 'regular',
    ADD COLUMN IF NOT EXISTS reward_days integer NOT NULL DEFAULT 7;

  IF NOT v_had_suggestion_type THEN
    UPDATE public.suggested_places
       SET is_hidden_gem = true,
           suggestion_type = 'hidden_gem',
           reward_days = 30;
  END IF;
END;
$migration$;

ALTER TABLE public.suggested_places
  ADD COLUMN IF NOT EXISTS reward_granted boolean NOT NULL DEFAULT false;

UPDATE public.suggested_places
   SET suggestion_type = CASE
         WHEN is_hidden_gem OR suggestion_type = 'hidden_gem'
           THEN 'hidden_gem'
         ELSE 'regular'
       END,
       is_hidden_gem = (is_hidden_gem OR suggestion_type = 'hidden_gem'),
       reward_days = CASE
         WHEN is_hidden_gem OR suggestion_type = 'hidden_gem' THEN 30
         ELSE 7
       END;

ALTER TABLE public.suggested_places
  DROP CONSTRAINT IF EXISTS suggested_places_suggestion_type_check,
  DROP CONSTRAINT IF EXISTS suggested_places_suggestion_reward_check;

ALTER TABLE public.suggested_places
  ADD CONSTRAINT suggested_places_suggestion_type_check
    CHECK (suggestion_type IN ('regular', 'hidden_gem')),
  ADD CONSTRAINT suggested_places_suggestion_reward_check
    CHECK (
      is_hidden_gem = (suggestion_type = 'hidden_gem')
      AND reward_days = CASE
        WHEN suggestion_type = 'hidden_gem' THEN 30
        ELSE 7
      END
    );

CREATE OR REPLACE FUNCTION public.grant_suggestion_pro_reward(
  target_user_id uuid,
  p_days integer DEFAULT 7
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $function$
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role'
     AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Only an administrator can grant suggestion rewards'
      USING ERRCODE = '42501';
  END IF;

  IF target_user_id IS NULL THEN
    RAISE EXCEPTION 'A target user is required'
      USING ERRCODE = '22023';
  END IF;
  IF p_days IS NULL OR p_days NOT IN (7, 30) THEN
    RAISE EXCEPTION 'Suggestion rewards must be 7 or 30 days'
      USING ERRCODE = '22023';
  END IF;

  UPDATE public.profiles
     SET is_pro = true,
         subscription_tier = CASE
           WHEN is_pro AND subscription_end_date IS NULL THEN
             COALESCE(NULLIF(subscription_tier, 'free'), 'lifetime')
           WHEN is_pro AND subscription_end_date > clock_timestamp() THEN
             subscription_tier
           WHEN p_days = 30 THEN 'monthly_reward'
           ELSE 'weekly'
         END,
         subscription_end_date = CASE
           WHEN is_pro AND subscription_end_date IS NULL THEN NULL
           ELSE GREATEST(
             COALESCE(subscription_end_date, clock_timestamp()),
             clock_timestamp()
           ) + make_interval(days => p_days)
         END,
         updated_at = clock_timestamp()
   WHERE user_id = target_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Profile for user % was not found', target_user_id
      USING ERRCODE = 'P0002';
  END IF;
END;
$function$;

CREATE OR REPLACE FUNCTION public.grant_hidden_gem_reward(
  target_user_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $function$
BEGIN
  PERFORM public.grant_suggestion_pro_reward(target_user_id, 30);
END;
$function$;

CREATE OR REPLACE FUNCTION public.grant_hidden_gem_reward()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $function$
BEGIN
  IF NEW.status = 'approved'
     AND OLD.status IS DISTINCT FROM 'approved'
     AND NEW.reward_granted = false
     AND NEW.user_id IS NOT NULL THEN
    PERFORM public.grant_suggestion_pro_reward(
      NEW.user_id,
      NEW.reward_days
    );
    NEW.reward_granted := true;
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS suggested_places_grant_pro_reward
  ON public.suggested_places;
CREATE TRIGGER suggested_places_grant_pro_reward
  BEFORE UPDATE OF status ON public.suggested_places
  FOR EACH ROW
  EXECUTE FUNCTION public.grant_hidden_gem_reward();

CREATE OR REPLACE FUNCTION public.moderate_hidden_gem(
  p_suggestion_id uuid,
  p_action text
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $function$
DECLARE
  v_suggestion public.suggested_places%ROWTYPE;
  v_place_id text;
  v_category text;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Only an administrator can moderate suggestions'
      USING ERRCODE = '42501';
  END IF;

  IF p_action IS NULL OR p_action NOT IN ('approve', 'reject') THEN
    RAISE EXCEPTION 'Unsupported moderation action: %', p_action
      USING ERRCODE = '22023';
  END IF;

  SELECT *
    INTO v_suggestion
    FROM public.suggested_places
   WHERE id = p_suggestion_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Place suggestion % was not found', p_suggestion_id
      USING ERRCODE = 'P0002';
  END IF;
  IF v_suggestion.status <> 'pending' THEN
    RAISE EXCEPTION 'Place suggestion is already %', v_suggestion.status
      USING ERRCODE = '55000';
  END IF;

  IF p_action = 'approve' THEN
    v_place_id := 'suggestion-' || v_suggestion.id::text;
    v_category := CASE
      WHEN v_suggestion.category = ANY (
        ARRAY[
          'Historical', 'Culture', 'Nature', 'Food',
          'Shopping', 'Mosques', 'Churches', 'Streets'
        ]::text[]
      ) THEN v_suggestion.category
      ELSE 'Culture'
    END;

    INSERT INTO public.places (
      id, name, name_en, name_ar, description, description_en,
      category, category_ar, lat, lng, address, image_url, image_urls,
      is_hidden_gem, is_featured, rating, review_count, price_level,
      price_note, display_order, enable_chat, enable_gallery
    )
    VALUES (
      v_place_id,
      v_suggestion.title,
      v_suggestion.title,
      v_suggestion.name_ar,
      v_suggestion.description,
      v_suggestion.description,
      v_category,
      coalesce(v_suggestion.category_ar, v_category),
      v_suggestion.lat,
      v_suggestion.lng,
      v_suggestion.address,
      coalesce(v_suggestion.image_url, ''),
      CASE WHEN nullif(v_suggestion.image_url, '') IS NULL
        THEN ARRAY[]::text[]
        ELSE ARRAY[v_suggestion.image_url]
      END,
      v_suggestion.is_hidden_gem,
      false,
      0,
      0,
      'free',
      '',
      coalesce((SELECT max(display_order) FROM public.places), 0) + 1,
      false,
      false
    )
    ON CONFLICT (id) DO NOTHING;
  END IF;

  UPDATE public.suggested_places
     SET status = CASE p_action
       WHEN 'approve' THEN 'approved'
       ELSE 'rejected'
     END
   WHERE id = p_suggestion_id;

  RETURN CASE WHEN p_action = 'approve' THEN v_place_id ELSE NULL END;
END;
$function$;

REVOKE ALL ON FUNCTION public.grant_suggestion_pro_reward(uuid, integer)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.grant_hidden_gem_reward(uuid)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.grant_hidden_gem_reward()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.grant_suggestion_pro_reward(uuid, integer)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.grant_hidden_gem_reward(uuid)
  TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.moderate_hidden_gem(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.moderate_hidden_gem(uuid, text)
  TO authenticated;
