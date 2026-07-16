-- Restored Yudao table data can be ahead of PostgreSQL sequence state.
-- Align every conventionally named public.system_*_seq with its table so
-- future inserts cannot collide with restored primary keys.
do $$
declare
    sequence_record record;
    table_name text;
    maximum_id bigint;
    current_value bigint;
begin
    for sequence_record in
        select sequencename
        from pg_sequences
        where schemaname = 'public'
          and sequencename like 'system\_%\_seq' escape '\'
    loop
        table_name := left(sequence_record.sequencename, -4);
        if to_regclass('public.' || quote_ident(table_name)) is null then
            continue;
        end if;

        execute format('select coalesce(max(id), 0) from public.%I', table_name)
            into maximum_id;
        execute format('select last_value from public.%I', sequence_record.sequencename)
            into current_value;
        perform setval(
            format('public.%I', sequence_record.sequencename)::regclass,
            greatest(maximum_id, current_value, 1),
            true
        );
    end loop;
end
$$;
