-- Remove the remaining legacy BPM root menu that points to /bpm.
DELETE FROM public.system_menu
WHERE path = '/bpm'
   OR path = 'bpm'
   OR component = 'bpm';
