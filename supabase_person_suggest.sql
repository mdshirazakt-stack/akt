-- Name suggestions for the profile page's Connection finder (2026-11-10)
-- Run once in the AKT Supabase project (fusairoeiabmqvsbxhfi.supabase.co)
--
-- akt_name_skeleton(text): a spelling-tolerant key for a name. Lower-cases,
-- treats sound-alike spellings as one (z/j, q/k, ph/f, w/v, sh/s, kh/k, th/t,
-- dh/d, bh/b, gh/g, ck/k), collapses doubled letters, then keeps each word's
-- first letter plus its consonants. So Zeeshan / Zeshan / Jeshan -> "jsn",
-- Ahmad / Ahmed -> "hmd" after the first letter, Seraj / Siraj -> "srj".
--
-- akt_person_suggest(q, limit) returns up to `limit` people whose name matches
-- every typed word: exact substring matches first, then spelling-tolerant
-- (skeleton) matches. Each row carries the father's name (from the person's
-- parent family) and a place, so same-named people can be told apart.
-- Duplicate records linked in person_identity_members come back once.
-- Privacy: same fields the normal search shows; no birth date, age, mobile
-- or email.
--
-- Speed: each person's key is stored once in person_name_keys (kept current by
-- a trigger on people) and searched through a trigram index, so a lookup
-- doesn't recompute 27k keys on every keystroke.

create or replace function public.akt_name_skeleton(p text)
returns text
language sql
immutable
set search_path to 'public'
as $$
  select string_agg(
           left(w, 1) || regexp_replace(substr(w, 2), '[aeiouy]', '', 'g'),
           ' ' order by i)
    from (
      select w, i
        from regexp_split_to_table(
               regexp_replace(
                 regexp_replace(
                   regexp_replace(
                     regexp_replace(lower(coalesce(p, '')), '[^a-z ]', ' ', 'g'),
                   'ph', 'f', 'g'),
                 '([kstdbg])h', '\1', 'g'),
               'ck', 'k', 'g'),
             '\s+') with ordinality t(w, i)
       where w <> ''
    ) words;
$$;

-- The letter unification above is done in a wrapper so the regex chain stays readable.
create or replace function public.akt_name_key(p text)
returns text
language sql
immutable
set search_path to 'public'
as $$
  select coalesce(regexp_replace(
           translate(public.akt_name_skeleton(p), 'zqw', 'jkv'),
           '([a-z])\1+', '\1', 'g'), '');
$$;

create extension if not exists pg_trgm with schema extensions;

create table if not exists public.person_name_keys (
  uid text primary key references public.people(uid) on delete cascade on update cascade,
  key text not null          -- ' ' || akt_name_key(name || ' ' || nickname)
);
-- (re)attach the link so it follows people.uid on delete AND on update
alter table public.person_name_keys drop constraint if exists person_name_keys_uid_fkey;
alter table public.person_name_keys add constraint person_name_keys_uid_fkey
  foreign key (uid) references public.people(uid) on delete cascade on update cascade;
alter table public.person_name_keys enable row level security;
drop policy if exists person_name_keys_visitor_read on public.person_name_keys;
create policy person_name_keys_visitor_read on public.person_name_keys
  for select using (akt_is_visitor());
create index if not exists person_name_keys_key_trgm
  on public.person_name_keys using gin (key extensions.gin_trgm_ops);

create or replace function public.akt__sync_person_name_key()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  insert into public.person_name_keys (uid, key)
  values (new.uid, ' ' || public.akt_name_key(coalesce(new.name, '') || ' ' || coalesce(new.nickname, '')))
  on conflict (uid) do update set key = excluded.key;
  return null;
end;
$$;
revoke all on function public.akt__sync_person_name_key() from public, anon, authenticated;

drop trigger if exists people_sync_name_key on public.people;
create trigger people_sync_name_key
  after insert or update of name, nickname on public.people
  for each row execute function public.akt__sync_person_name_key();

-- backfill / refresh every key
insert into public.person_name_keys (uid, key)
select uid, ' ' || public.akt_name_key(coalesce(name, '') || ' ' || coalesce(nickname, ''))
  from public.people
on conflict (uid) do update set key = excluded.key;

create or replace function public.akt_person_suggest(p_q text, p_limit int default 8)
returns table (uid text, name text, sex text, father_name text, mother_name text, place text)
language sql
stable
security invoker
set search_path to 'public'
as $$
  with q as (
    select array_agg(t) filter (where length(t) >= 2) as toks,
           array_agg(public.akt_name_key(t)) filter (where length(t) >= 2) as keys
      from regexp_split_to_table(lower(trim(coalesce(p_q, ''))), '\s+') t
  ),
  cand as (
    select pe.uid, pe.name, pe.sex, pe.root_place, pe.current_place, pe.birth_place,
           case when not exists (
                  select 1 from unnest(q.toks) tok
                   where lower(pe.name || ' ' || coalesce(pe.nickname, '')) not like '%' || tok || '%')
                then 0 else 1 end as rank_exact
      from q
      join public.person_name_keys nk
        on nk.key like all (select '% ' || k || '%' from unnest(q.keys) k where k <> '')
      join public.people pe on pe.uid = nk.uid
     where q.toks is not null
       and pe.name is not null and pe.name <> ''
       and pe.name not like '(%' and pe.name not like '[%' and pe.name not like ',%'
       and pe.name not like ';%' and pe.name not like '-%' and pe.name not like '+%'
  ),
  with_parents as (
    select c.*,
           fa.name as father_name, mo.name as mother_name,
           coalesce((select min(m.group_id::text) from public.person_identity_members m where m.person_uid = c.uid), c.uid) as canon
      from cand c
      left join lateral (
        select f.husband_uid, f.wife_uid
          from public.family_members fm
          join public.families f on f.uid = fm.family_uid
         where fm.person_uid = c.uid and fm.role = 'child'
         order by fm.birth_order nulls last, fm.family_uid
         limit 1
      ) pf on true
      left join public.people fa on fa.uid = pf.husband_uid
      left join public.people mo on mo.uid = pf.wife_uid
  ),
  one_per_person as (
    select distinct on (canon) *
      from with_parents
     order by canon, (father_name is null), rank_exact, length(name)
  )
  select uid, name, sex, father_name, mother_name,
         nullif(trim(coalesce(nullif(trim(root_place), ''), nullif(trim(current_place), ''), birth_place)), '') as place
    from one_per_person
   order by rank_exact, (father_name is null), length(name), name
   limit least(greatest(coalesce(p_limit, 8), 1), 20);
$$;

revoke all on function public.akt_person_suggest(text, int) from public, anon;
grant execute on function public.akt_person_suggest(text, int) to authenticated;
