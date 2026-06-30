-- Run once in Supabase SQL Editor to backfill profiles for dentists
-- who signed up before the profiles-row fix.

INSERT INTO profiles (id, full_name, phone, role)
SELECT
  dp.user_id,
  COALESCE(au.raw_user_meta_data->>'full_name', 'Dentist'),
  COALESCE(au.raw_user_meta_data->>'phone', ''),
  'dentist'
FROM dentist_profiles dp
JOIN auth.users au ON au.id = dp.user_id
WHERE NOT EXISTS (
  SELECT 1 FROM profiles p WHERE p.id = dp.user_id
)
ON CONFLICT (id) DO UPDATE
SET role = 'dentist';
