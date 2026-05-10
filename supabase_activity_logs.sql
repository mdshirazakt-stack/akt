-- Activity feed support for apnonkitalash.com admin.html
-- Run this once in Supabase SQL Editor.

create table if not exists public.activity_logs (
  id uuid primary key default gen_random_uuid(),
  visitor_name text not null,
  action text not null,
  target text,
  details jsonb not null default '{}'::jsonb,
  device text,
  timezone text,
  location_hint text,
  created_at timestamptz not null default now()
);

alter table public.activity_logs
  add column if not exists location_hint text;

create index if not exists activity_logs_created_at_idx
  on public.activity_logs (created_at desc);

create index if not exists activity_logs_visitor_name_idx
  on public.activity_logs (visitor_name);

alter table public.activity_logs enable row level security;

drop policy if exists "Allow public activity insert" on public.activity_logs;
create policy "Allow public activity insert"
  on public.activity_logs
  for insert
  to anon
  with check (true);

drop policy if exists "Allow public activity read" on public.activity_logs;
create policy "Allow public activity read"
  on public.activity_logs
  for select
  to anon
  using (true);
