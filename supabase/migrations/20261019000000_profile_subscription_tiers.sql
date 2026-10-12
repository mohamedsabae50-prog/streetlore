ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS subscription_tier text,
  ADD COLUMN IF NOT EXISTS subscription_end_date timestamptz;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'profiles_subscription_tier_check'
      AND conrelid = 'public.profiles'::regclass
  ) THEN
    ALTER TABLE public.profiles
      ADD CONSTRAINT profiles_subscription_tier_check
      CHECK (
        subscription_tier IS NULL OR
        subscription_tier IN ('weekly', 'monthly', 'lifetime', 'free')
      );
  END IF;
END;
$$;
