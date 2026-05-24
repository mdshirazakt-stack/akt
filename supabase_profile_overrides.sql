-- Community profile update overlay for Apno Ki Talash.
-- Run this in the AKT Supabase project used by apnonkitalash.com:
-- https://fusairoeiabmqvsbxhfi.supabase.co
--
-- GEDCOM tables remain unchanged. Approved community updates are stored here
-- and can later be merged into an enriched GEDCOM export.

create table if not exists public.person_profile_overrides (
  person_uid text primary key,
  corrected_name text,
  corrected_gender text,
  is_deceased boolean,
  email text,
  birth_date_text text,
  death_date_text text,
  death_location text,
  mobile_number text,
  root_location text,
  birth_location text,
  current_location text,
  birth_order_text text,
  profile_note text,
  source_request_id text,
  approved_by text,
  approved_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table public.person_profile_overrides
  add column if not exists corrected_name text,
  add column if not exists corrected_gender text,
  add column if not exists is_deceased boolean,
  add column if not exists email text,
  add column if not exists birth_date_text text,
  add column if not exists death_date_text text,
  add column if not exists death_location text,
  add column if not exists mobile_number text,
  add column if not exists root_location text,
  add column if not exists birth_location text,
  add column if not exists current_location text,
  add column if not exists birth_order_text text,
  add column if not exists profile_note text,
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
  add column if not exists correction_profile_note text,
  add column if not exists duplicate_profile_uid text,
  add column if not exists duplicate_profile_link text,
  add column if not exists duplicate_profile_note text,
  add column if not exists applied_to_profile boolean default false,
  add column if not exists applied_at timestamptz;

alter table public.people
  add column if not exists notes text,
  add column if not exists root_place text,
  add column if not exists current_place text,
  add column if not exists contact_address text,
  add column if not exists email text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'person_profile_overrides_profile_note_len'
  ) then
    alter table public.person_profile_overrides
      add constraint person_profile_overrides_profile_note_len
      check (profile_note is null or char_length(profile_note) <= 1024);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'correction_requests_profile_note_len'
  ) then
    alter table public.correction_requests
      add constraint correction_requests_profile_note_len
      check (correction_profile_note is null or char_length(correction_profile_note) <= 1024);
  end if;
end $$;

create index if not exists idx_person_profile_overrides_person_uid
  on public.person_profile_overrides(person_uid);

create index if not exists idx_correction_requests_person_uid
  on public.correction_requests(person_uid);
