-- BPM is not implemented by the Rust gateway. Remove its legacy dictionary
-- types and values along with the retired BPM frontend.
DELETE FROM public.system_dict_data
WHERE dict_type LIKE 'bpm%';

DELETE FROM public.system_dict_type
WHERE type LIKE 'bpm%';
