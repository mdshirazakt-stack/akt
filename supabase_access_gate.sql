-- Controlled access gate for Apno Ki Talash.
-- Run this in the AKT Supabase project used by apnonkitalash.com:
-- https://fusairoeiabmqvsbxhfi.supabase.co
--
-- Existing visitor rows are marked approved so current known access is not
-- accidentally locked out. New authenticated visitors now default to visitor
-- access after completing the onboarding and consent form. Admins can block or
-- change roles from admin.html.

alter table public.visitors
  add column if not exists auth_user_id uuid,
  add column if not exists email text,
  add column if not exists mobile text,
  add column if not exists family_reference text,
  add column if not exists access_reason text,
  add column if not exists access_status text default 'approved',
  add column if not exists access_role text default 'visitor',
  add column if not exists father_name text,
  add column if not exists root_place text,
  add column if not exists current_place text,
  add column if not exists current_address text,
  add column if not exists oldest_ancestor text,
  add column if not exists heard_from_source text,
  add column if not exists heard_from_relative_name text,
  add column if not exists heard_from_relative_place text,
  add column if not exists heard_from_details text,
  add column if not exists visitor_form_completed boolean default false,
  add column if not exists visitor_form_completed_at timestamptz,
  add column if not exists consent_terms_accepted boolean default false,
  add column if not exists consent_sections text[],
  add column if not exists consent_version text,
  add column if not exists consent_accepted_at timestamptz,
  add column if not exists consent_ip_hint text,
  add column if not exists consent_user_agent text,
  add column if not exists admin_notes text,
  add column if not exists approved_at timestamptz,
  add column if not exists rejected_at timestamptz,
  add column if not exists updated_at timestamptz default now();

alter table public.visitors
  drop constraint if exists visitors_access_status_check;

alter table public.visitors
  add constraint visitors_access_status_check
  check (access_status in ('pending', 'approved', 'rejected', 'blocked'));

alter table public.visitors
  drop constraint if exists visitors_access_role_check;

alter table public.visitors
  add constraint visitors_access_role_check
  check (access_role in ('visitor', 'moderator', 'admin', 'superadmin'));

update public.visitors
set access_status = 'approved',
    access_role = coalesce(access_role, 'visitor'),
    approved_at = coalesce(approved_at, now()),
    updated_at = now()
where access_status is null;

update public.visitors
set access_role = 'visitor',
    updated_at = now()
where access_role is null;

create index if not exists idx_visitors_mobile
  on public.visitors(mobile);

create index if not exists idx_visitors_auth_user_id
  on public.visitors(auth_user_id);

create index if not exists idx_visitors_email
  on public.visitors(lower(email));

create index if not exists idx_visitors_access_status
  on public.visitors(access_status, updated_at desc);

create index if not exists idx_visitors_access_role
  on public.visitors(access_role);

create table if not exists public.visitor_consent_records (
  id uuid primary key default gen_random_uuid(),
  visitor_id uuid references public.visitors(id) on delete set null,
  auth_user_id uuid,
  email text,
  consent_version text not null,
  accepted_sections text[] not null,
  form_snapshot jsonb not null default '{}'::jsonb,
  ip_hint text,
  user_agent text,
  created_at timestamptz not null default now()
);

create index if not exists idx_visitor_consent_records_visitor
  on public.visitor_consent_records(visitor_id, created_at desc);

create index if not exists idx_visitor_consent_records_auth_user
  on public.visitor_consent_records(auth_user_id, created_at desc);
