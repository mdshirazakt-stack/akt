-- Controlled access gate for Apno Ki Talash.
-- Run this in the AKT Supabase project used by apnonkitalash.com:
-- https://fusairoeiabmqvsbxhfi.supabase.co
--
-- Existing visitor rows are marked approved so current known access is not
-- accidentally locked out. New visitors created through index.html default to
-- pending and require admin approval from admin.html.

alter table public.visitors
  add column if not exists mobile text,
  add column if not exists family_reference text,
  add column if not exists access_reason text,
  add column if not exists access_status text default 'approved',
  add column if not exists admin_notes text,
  add column if not exists approved_at timestamptz,
  add column if not exists rejected_at timestamptz,
  add column if not exists updated_at timestamptz default now();

alter table public.visitors
  drop constraint if exists visitors_access_status_check;

alter table public.visitors
  add constraint visitors_access_status_check
  check (access_status in ('pending', 'approved', 'rejected', 'blocked'));

update public.visitors
set access_status = 'approved',
    approved_at = coalesce(approved_at, now()),
    updated_at = now()
where access_status is null;

create index if not exists idx_visitors_mobile
  on public.visitors(mobile);

create index if not exists idx_visitors_access_status
  on public.visitors(access_status, updated_at desc);
