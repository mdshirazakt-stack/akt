-- Staff/admin action audit log for admin.html.
-- Run this once in the Supabase SQL editor.

create table if not exists public.staff_activity_logs (
  id uuid primary key default gen_random_uuid(),
  actor_name text,
  actor_role text,
  action text not null,
  target text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_staff_activity_logs_created_at
  on public.staff_activity_logs (created_at desc);

create index if not exists idx_staff_activity_logs_actor_role
  on public.staff_activity_logs (actor_role);

create index if not exists idx_staff_activity_logs_action
  on public.staff_activity_logs (action);

alter table public.staff_activity_logs enable row level security;

drop policy if exists "Allow staff activity insert" on public.staff_activity_logs;
create policy "Allow staff activity insert"
  on public.staff_activity_logs
  for insert
  to anon
  with check (true);

drop policy if exists "Allow staff activity read" on public.staff_activity_logs;
create policy "Allow staff activity read"
  on public.staff_activity_logs
  for select
  to anon
  using (true);
