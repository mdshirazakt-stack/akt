-- Signup and first-time registration drop-off tracking.
-- Run this once in Supabase SQL Editor before using Admin > Signup drop-offs.

create extension if not exists pgcrypto;

create table if not exists public.signup_events (
  id uuid primary key default gen_random_uuid(),
  email text,
  auth_user_id uuid,
  visitor_id uuid references public.visitors(id) on delete set null,
  event_name text not null,
  stage text,
  step integer,
  form_snapshot jsonb not null default '{}'::jsonb,
  details jsonb not null default '{}'::jsonb,
  ip_hint text,
  user_agent text,
  created_at timestamptz not null default now()
);

create index if not exists signup_events_created_at_idx on public.signup_events (created_at desc);
create index if not exists signup_events_email_idx on public.signup_events (lower(email));
create index if not exists signup_events_auth_user_id_idx on public.signup_events (auth_user_id);
create index if not exists signup_events_event_name_idx on public.signup_events (event_name);
create index if not exists signup_events_session_idx on public.signup_events ((details->>'signup_session_id'));

alter table public.signup_events enable row level security;

drop policy if exists "signup_events_insert_from_site" on public.signup_events;
drop policy if exists "signup_events_admin_read" on public.signup_events;

create policy "signup_events_insert_from_site"
on public.signup_events
for insert
to anon, authenticated
with check (true);

-- The current admin.html dashboard reads through the public Supabase client.
-- Tighten this to admin-only JWT claims when the admin API is moved behind server-side auth.
create policy "signup_events_admin_read"
on public.signup_events
for select
to anon, authenticated
using (true);
