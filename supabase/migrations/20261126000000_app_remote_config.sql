CREATE TABLE IF NOT EXISTS public.app_remote_config (
  id integer PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  apple_sign_in_enabled boolean NOT NULL DEFAULT false,
  weekly_price_en text NOT NULL DEFAULT '49 EGP / week',
  weekly_price_ar text NOT NULL DEFAULT '49 ج.م / أسبوع',
  weekly_usd_label text NOT NULL DEFAULT '~$0.99 USD',
  monthly_price_en text NOT NULL DEFAULT '49 EGP / month',
  monthly_price_ar text NOT NULL DEFAULT '49 ج.م / شهر',
  monthly_usd_label text NOT NULL DEFAULT '~$0.99 USD',
  annual_price_en text NOT NULL DEFAULT '199 EGP / year',
  annual_price_ar text NOT NULL DEFAULT '199 ج.م / سنة',
  annual_usd_label text NOT NULL DEFAULT '~$4.99 USD',
  promo_banner_enabled boolean NOT NULL DEFAULT false,
  promo_banner_en text NOT NULL DEFAULT '',
  promo_banner_ar text NOT NULL DEFAULT '',
  latest_app_version text NOT NULL DEFAULT '2.1.40',
  latest_build_number integer NOT NULL DEFAULT 243,
  direct_apk_url text NOT NULL DEFAULT 'https://github.com/mohamedsabae50-prog/streetlore/releases/latest/download/app-release.apk',
  release_notes_en text NOT NULL DEFAULT '',
  release_notes_ar text NOT NULL DEFAULT '',
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.app_remote_config (id)
VALUES (1)
ON CONFLICT (id) DO UPDATE SET id = EXCLUDED.id;

ALTER TABLE public.app_remote_config ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.app_remote_config FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.app_remote_config TO anon, authenticated;

DROP POLICY IF EXISTS app_remote_config_read ON public.app_remote_config;
CREATE POLICY app_remote_config_read
  ON public.app_remote_config
  FOR SELECT
  TO anon, authenticated
  USING (true);

DO $block$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_publication
    WHERE pubname = 'supabase_realtime'
  ) AND NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'app_remote_config'
  ) THEN
    ALTER PUBLICATION supabase_realtime
      ADD TABLE public.app_remote_config;
  END IF;
END;
$block$;

CREATE OR REPLACE FUNCTION public.admin_update_remote_config(p_payload jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_config public.app_remote_config%ROWTYPE;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Admin access required' USING ERRCODE = '42501';
  END IF;
  IF p_payload IS NULL OR jsonb_typeof(p_payload) <> 'object' THEN
    RAISE EXCEPTION 'Remote config payload must be a JSON object'
      USING ERRCODE = '22023';
  END IF;

  UPDATE public.app_remote_config AS config
  SET apple_sign_in_enabled = coalesce(
        (p_payload ->> 'apple_sign_in_enabled')::boolean,
        config.apple_sign_in_enabled
      ),
      weekly_price_en = coalesce(
        p_payload ->> 'weekly_price_en',
        config.weekly_price_en
      ),
      weekly_price_ar = coalesce(
        p_payload ->> 'weekly_price_ar',
        config.weekly_price_ar
      ),
      weekly_usd_label = coalesce(
        p_payload ->> 'weekly_usd_label',
        config.weekly_usd_label
      ),
      monthly_price_en = coalesce(
        p_payload ->> 'monthly_price_en',
        config.monthly_price_en
      ),
      monthly_price_ar = coalesce(
        p_payload ->> 'monthly_price_ar',
        config.monthly_price_ar
      ),
      monthly_usd_label = coalesce(
        p_payload ->> 'monthly_usd_label',
        config.monthly_usd_label
      ),
      annual_price_en = coalesce(
        p_payload ->> 'annual_price_en',
        config.annual_price_en
      ),
      annual_price_ar = coalesce(
        p_payload ->> 'annual_price_ar',
        config.annual_price_ar
      ),
      annual_usd_label = coalesce(
        p_payload ->> 'annual_usd_label',
        config.annual_usd_label
      ),
      promo_banner_enabled = coalesce(
        (p_payload ->> 'promo_banner_enabled')::boolean,
        config.promo_banner_enabled
      ),
      promo_banner_en = coalesce(
        p_payload ->> 'promo_banner_en',
        config.promo_banner_en
      ),
      promo_banner_ar = coalesce(
        p_payload ->> 'promo_banner_ar',
        config.promo_banner_ar
      ),
      latest_app_version = coalesce(
        p_payload ->> 'latest_app_version',
        config.latest_app_version
      ),
      latest_build_number = coalesce(
        (p_payload ->> 'latest_build_number')::integer,
        config.latest_build_number
      ),
      direct_apk_url = coalesce(
        p_payload ->> 'direct_apk_url',
        config.direct_apk_url
      ),
      release_notes_en = coalesce(
        p_payload ->> 'release_notes_en',
        config.release_notes_en
      ),
      release_notes_ar = coalesce(
        p_payload ->> 'release_notes_ar',
        config.release_notes_ar
      ),
      updated_at = now()
  WHERE config.id = 1
  RETURNING config.* INTO v_config;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Remote config singleton row is missing'
      USING ERRCODE = 'P0002';
  END IF;
  RETURN to_jsonb(v_config);
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_update_remote_config(jsonb)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_remote_config(jsonb)
  TO authenticated;
