-- Private profile-claim records for matching registered users to their own family profile.
-- Run this once in the Supabase SQL editor.

create table if not exists public.profile_claims (
  id uuid primary key default gen_random_uuid(),
  person_uid text not null unique,
  person_name text,
  visitor_id uuid,
  auth_user_id uuid,
  claimant_name text,
  claimant_email text not null,
  claimant_mobile text not null,
  status text not null default 'claimed',
  claimed_at timestamptz not null default now(),
  applied_at timestamptz,
  applied_by text,
  updated_at timestamptz not null default now()
);

alter table public.profile_claims
  add column if not exists applied_at timestamptz,
  add column if not exists applied_by text;

create index if not exists idx_profile_claims_auth_user_id
  on public.profile_claims (auth_user_id);

create index if not exists idx_profile_claims_claimant_email
  on public.profile_claims (lower(claimant_email));

create index if not exists idx_profile_claims_claimed_at
  on public.profile_claims (claimed_at desc);

alter table public.profile_claims enable row level security;

drop policy if exists "Allow profile claims insert" on public.profile_claims;
create policy "Allow profile claims insert"
  on public.profile_claims
  for insert
  to public
  with check (true);

drop policy if exists "Allow profile claims update" on public.profile_claims;
create policy "Allow profile claims update"
  on public.profile_claims
  for update
  to public
  using (true)
  with check (true);

drop policy if exists "Allow profile claims read" on public.profile_claims;
create policy "Allow profile claims read"
  on public.profile_claims
  for select
  to public
  using (true);
