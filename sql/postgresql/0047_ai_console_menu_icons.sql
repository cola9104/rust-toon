UPDATE system_menu
SET icon = CASE id
    WHEN 2760 THEN 'lucide:settings-2'
    WHEN 2761 THEN 'lucide:key-round'
    WHEN 2767 THEN 'lucide:brain-circuit'
    WHEN 2773 THEN 'lucide:bot'
    WHEN 2920 THEN 'lucide:wrench'
    WHEN 2778 THEN 'lucide:messages-square'
    WHEN 2784 THEN 'lucide:images'
    WHEN 2788 THEN 'lucide:list-music'
    WHEN 2793 THEN 'lucide:book-text'
    WHEN 2799 THEN 'lucide:network'
    ELSE icon
END,
updater = 'system',
update_time = CURRENT_TIMESTAMP
WHERE id IN (2760,2761,2767,2773,2920,2778,2784,2788,2793,2799)
  AND deleted = 0;
