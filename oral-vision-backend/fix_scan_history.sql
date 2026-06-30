-- Add missing columns to scan_history if they don't exist
ALTER TABLE public.scan_history 
ADD COLUMN IF NOT EXISTS scan_type text default 'oral',
ADD COLUMN IF NOT EXISTS affected_area float default 0.0;
