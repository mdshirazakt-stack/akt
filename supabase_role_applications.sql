-- Moderator/admin role application queue.
-- Run this once in the Supabase SQL editor.

create table if not exists public.role_applications (
  id uuid primary key default gen_random_uuid(),
  visitor_id uuid,
  auth_user_id uuid,
  applicant_name text,
  applicant_email text,
  applicant_mobile text,
  applicant_profile_link text,
  current_access_role text not null default 'visitor',
  requested_role text not null check (requested_role in ('moderator', 'admin')),
  application_note text not null,
  status text not null default 'new' check (status in ('new', 'reviewing', 'approved', 'declined')),
  admin_notes text,
  reviewed_by text,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.role_applications
  add column if not exists applicant_profile_link text;

create index if not exists idx_role_applications_status
  on public.role_applications (status);

create index if not exists idx_role_applications_created_at
  on public.role_applications (created_at desc);

create index if not exists idx_role_applications_auth_user_id
  on public.role_applications (auth_user_id);

alter table public.role_applications enable row level security;

drop policy if exists "Allow role applications insert" on public.role_applications;
drop policy if exists "Allow role applications read" on public.role_applications;
drop policy if exists "Allow role applications update" on public.role_applications;

-- RLS policies are managed by supabase_security_hardening.sql.
