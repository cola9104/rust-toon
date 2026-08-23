-- BPM management APIs are not implemented by the Rust gateway. Remove the
-- legacy menu rows so they cannot expose unavailable frontend or API routes.
DELETE FROM public.system_menu
WHERE id IN (
    SELECT id
    FROM public.system_menu
    WHERE id IN (1186, 1200)
       OR component LIKE 'bpm/%'
       OR permission LIKE 'bpm:%'
);
