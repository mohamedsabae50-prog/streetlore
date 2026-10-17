CREATE TABLE IF NOT EXISTS public.saved_tours (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  tour_data jsonb NOT NULL,
  saved_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS saved_tours_user_saved_at_idx
  ON public.saved_tours (user_id, saved_at DESC);

ALTER TABLE public.saved_tours ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their saved tours"
  ON public.saved_tours;
CREATE POLICY "Users can manage their saved tours"
  ON public.saved_tours
  FOR ALL
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
GRANT SELECT, INSERT, UPDATE, DELETE ON public.saved_tours TO authenticated;

DO $$
DECLARE
  foreign_key record;
  definition text;
  cascade_definition text;
BEGIN
  FOR foreign_key IN
    SELECT
      constraint_row.oid,
      namespace_row.nspname AS table_schema,
      table_row.relname AS table_name,
      constraint_row.conname AS constraint_name
    FROM pg_constraint AS constraint_row
    JOIN pg_class AS table_row
      ON table_row.oid = constraint_row.conrelid
    JOIN pg_namespace AS namespace_row
      ON namespace_row.oid = table_row.relnamespace
    WHERE constraint_row.contype = 'f'
      AND namespace_row.nspname = 'public'
      AND constraint_row.confrelid = 'auth.users'::regclass
      AND constraint_row.confkey = ARRAY[
        (
          SELECT attribute_row.attnum
          FROM pg_attribute AS attribute_row
          WHERE attribute_row.attrelid = 'auth.users'::regclass
            AND attribute_row.attname = 'id'
            AND NOT attribute_row.attisdropped
        )
      ]::smallint[]
  LOOP
    SELECT pg_get_constraintdef(foreign_key.oid, true)
    INTO definition;

    IF definition ~* ' ON DELETE (NO ACTION|RESTRICT|CASCADE|SET NULL|SET DEFAULT)' THEN
      cascade_definition := regexp_replace(
        definition,
        ' ON DELETE (NO ACTION|RESTRICT|CASCADE|SET NULL|SET DEFAULT)( \([^)]*\))?',
        ' ON DELETE CASCADE',
        'i'
      );
    ELSE
      cascade_definition := regexp_replace(
        definition,
        '( ON UPDATE | DEFERRABLE| NOT DEFERRABLE| INITIALLY | NOT VALID)',
        ' ON DELETE CASCADE\1',
        'i'
      );
      IF cascade_definition = definition THEN
        cascade_definition := definition || ' ON DELETE CASCADE';
      END IF;
    END IF;

    EXECUTE format(
      'ALTER TABLE %I.%I DROP CONSTRAINT %I',
      foreign_key.table_schema,
      foreign_key.table_name,
      foreign_key.constraint_name
    );
    EXECUTE format(
      'ALTER TABLE %I.%I ADD CONSTRAINT %I %s',
      foreign_key.table_schema,
      foreign_key.table_name,
      foreign_key.constraint_name,
      cascade_definition
    );
  END LOOP;
END;
$$;

NOTIFY pgrst, 'reload schema';
