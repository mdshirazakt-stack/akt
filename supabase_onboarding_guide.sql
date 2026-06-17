-- Tracks which approved visitors have read and acknowledged the
-- post-approval membership guide.  Primary key on visitor_id enforces
-- the one-per-lifetime rule: once a row exists the guide is never shown
-- again, even across sign-outs.

create table if not exists public.visitor_onboarding_acknowledgements (
  visitor_id      uuid primary key references public.visitors(id) on delete cascade,
  acknowledged_at timestamptz not null default now(),
  language_viewed text not null default 'en'   -- 'en' | 'hi'
);

alter table public.visitor_onboarding_acknowledgements enable row level security;

-- Visitor inserts their own row (email fallback covers users whose
-- auth_user_id was null at the time of the RLS check).
create policy "guide_ack_self_insert"
on public.visitor_onboarding_acknowledgements
for insert to authenticated
with check (
  visitor_id = (
    select id from public.visitors
    where auth_user_id = auth.uid()
       or lower(email) = lower(
            coalesce(
              (select email from auth.users where id = auth.uid() limit 1),
              ''
            )
          )
    limit 1
  )
);

-- Visitor can read their own row (so auth-flow.js can check on re-login).
create policy "guide_ack_self_read"
on public.visitor_onboarding_acknowledgements
for select to authenticated
using (
  visitor_id = (
    select id from public.visitors
    where auth_user_id = auth.uid()
       or lower(email) = lower(
            coalesce(
              (select email from auth.users where id = auth.uid() limit 1),
              ''
            )
          )
    limit 1
  )
);

-- Admins and above can read all rows (for the Users tab indicator).
create policy "guide_ack_admin_read"
on public.visitor_onboarding_acknowledgements
for select to authenticated
using (public.akt_is_admin());

create index if not exists idx_visitor_onboarding_acks_visitor_id
  on public.visitor_onboarding_acknowledgements (visitor_id);
