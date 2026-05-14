-- Community profile update overlay for Apno Ki Talash.
-- Run this in the AKT Supabase project used by apnonkitalash.com:
-- https://fusairoeiabmqvsbxhfi.supabase.co
--
-- GEDCOM tables remain unchanged. Approved community updates are stored here
-- and can later be merged into an enriched GEDCOM export.

create table if not exists public.person_profile_overrides (
  person_uid text primary key,
  corrected_name text,
  is_deceased boolean,
  birth_date_text text,
  death_date_text text,
  death_location text,
  mobile_number text,
  root_location text,
  birth_location text,
  current_location text,
  birth_order_text text,
  source_request_id text,
  approved_by text,
  approved_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table public.person_profile_overrides
  add column if not exists corrected_name text,
  add column if not exists is_deceased boolean,
  add column if not exists birth_date_text text,
  add column if not exists death_date_text text,
  add column if not exists death_location text,
  add column if not exists mobile_number text,
  add column if not exists root_location text,
  add column if not exists birth_location text,
  add column if not exists current_location text,
  add column if not exists birth_order_text text,
  add column if not exists source_request_id text,
  add column if not exists approved_by text,
  add column if not exists approved_at timestamptz default now(),
  add column if not exists updated_at timestamptz default now();

alter table public.correction_requests
  add column if not exists correction_is_deceased boolean,
  add column if not exists correction_birth_date text,
  add column if not exists correction_death_date text,
  add column if not exists correction_death_location text,
  add column if not exists correction_mobile text,
  add column if not exists correction_root_location text,
  add column if not exists correction_birth_location text,
  add column if not exists correction_current_location text,
  add column if not exists correction_birth_order text,
  add column if not exists applied_to_profile boolean default false,
  add column if not exists applied_at timestamptz;

create index if not exists idx_person_profile_overrides_person_uid
  on public.person_profile_overrides(person_uid);

create index if not exists idx_correction_requests_person_uid
  on public.correction_requests(person_uid);
