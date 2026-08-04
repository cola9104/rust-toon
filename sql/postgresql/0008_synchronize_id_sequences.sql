-- The consolidated pg_dump restored table rows without advancing many ID
-- sequences. New records could therefore collide with existing primary keys.
-- Synchronize every conventional `<table>_seq` and `<table>_id_seq` sequence.
DO $$
DECLARE
  sequence_row record;
  table_name text;
  table_regclass regclass;
  maximum_id bigint;
BEGIN
  FOR sequence_row IN
    SELECT namespace.nspname AS schema_name,
           sequence.relname AS sequence_name
    FROM pg_class sequence
    JOIN pg_namespace namespace ON namespace.oid = sequence.relnamespace
    WHERE sequence.relkind = 'S'
      AND namespace.nspname IN ('public', 'ai', 'infra', 'toonflow')
  LOOP
    IF sequence_row.sequence_name LIKE '%\_id\_seq' ESCAPE '\' THEN
      table_name := regexp_replace(sequence_row.sequence_name, '_id_seq$', '');
    ELSE
      table_name := regexp_replace(sequence_row.sequence_name, '_seq$', '');
    END IF;

    table_regclass := to_regclass(format('%I.%I', sequence_row.schema_name, table_name));
    IF table_regclass IS NULL OR NOT EXISTS (
      SELECT 1
      FROM pg_attribute
      WHERE attrelid = table_regclass
        AND attname = 'id'
        AND NOT attisdropped
    ) THEN
      CONTINUE;
    END IF;

    EXECUTE format('SELECT max(id)::bigint FROM %s', table_regclass)
      INTO maximum_id;

    IF maximum_id IS NULL THEN
      PERFORM setval(
        format('%I.%I', sequence_row.schema_name, sequence_row.sequence_name)::regclass,
        1,
        false
      );
    ELSE
      PERFORM setval(
        format('%I.%I', sequence_row.schema_name, sequence_row.sequence_name)::regclass,
        maximum_id,
        true
      );
    END IF;
  END LOOP;
END
$$;
