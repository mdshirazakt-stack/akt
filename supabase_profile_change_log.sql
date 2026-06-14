-- Activity History for person.html profile pages.
-- Run this once in Supabase SQL Editor.
--
-- Records each profile/relationship change made via edit.html, alongside the
-- admin's stated source of information, so it can be displayed on the
-- relevant profile's "Activity History" section.

create table if not exists public.profile_change_log (
  id uuid primary key default gen_random_uuid(),
  profile_uid uuid not null,
  action text not null,
  summary text not null,
  source_of_info text not null default '',
  actor_name text not null,
  actor_role text,
  created_at timestamptz not null default now()
);

create index if not exists profile_change_log_profile_uid_idx
  on public.profile_change_log (profile_uid, created_at desc);

alter table public.profile_change_log enable row level security;

drop policy if exists "profile_change_log_insert" on public.profile_change_log;
create policy "profile_change_log_insert"
on public.profile_change_log
for insert
to authenticated
with check (public.akt_is_staff());

drop policy if exists "profile_change_log_read" on public.profile_change_log;
create policy "profile_change_log_read"
on public.profile_change_log
for select
to authenticated
using (public.akt_is_visitor());
