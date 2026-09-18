-- Built-in visual styles were duplicated into both art_styles and
-- creative_manuals. Production projects and Agents consume creative_manuals, so
-- make that complete manual editor the single UI entry point.
UPDATE public.system_menu
SET name = '创作手册',
    component = 'toonflow/manuals/index',
    update_time = CURRENT_TIMESTAMP
WHERE id = 20002
  AND path = 'styles';

-- Remove only the known synchronized seed copies. User-created lightweight
-- reference styles use timestamp IDs and are deliberately preserved.
DELETE FROM toonflow.art_styles AS style
USING toonflow.creative_manuals AS manual
WHERE style.id BETWEEN 560100 AND 560110
  AND manual.kind = 'visual'
  AND style.name = manual.name
  AND style.label = manual.path;
