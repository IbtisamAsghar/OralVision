-- Run this in Supabase SQL Editor to enable prescriptions
create table if not exists public.prescriptions (
  id uuid primary key default gen_random_uuid(),
  dentist_id uuid references auth.users(id) on delete cascade not null,
  patient_id uuid references auth.users(id) on delete set null,
  patient_name text not null,
  diagnosis text not null,
  medications text not null,
  dosage text,
  instructions text,
  notes text,
  created_at timestamptz default now()
);

alter table public.prescriptions enable row level security;

create policy "Dentists manage own prescriptions"
  on public.prescriptions
  for all
  using (auth.uid() = dentist_id)
  with check (auth.uid() = dentist_id);

create policy "Patients read own prescriptions"
  on public.prescriptions
  for select
  using (auth.uid() = patient_id);
