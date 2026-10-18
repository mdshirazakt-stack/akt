-- Real duplicate-profile merge (2026-10-18).
--
-- WHY: the same person often exists twice — once in their own family's
-- GEDCOM (with parents/children) and once in their spouse's GEDCOM (with only
-- the marriage). person_identity_groups / merge.html only add an "Also
-- recorded as" note; the tree never follows those links, so each copy shows
-- only half the family. This merges the two records into ONE person node, so
-- the family is reachable from both sides of the tree.
--
-- HOW: akt_merge_people(p_pairs, p_actor) — admin only, one transaction, so
-- a failure merges nothing. For each {keep, drop, fields} pair:
--   1. chosen field values are written onto the kept profile,
--   2. every reference to the dropped uid is moved onto the kept uid
--      (families, family_members and the 8 other tables that store person
--      uids — duplicates that would collide are dropped, see below),
--   3. a redirect old_uid → kept uid is recorded (person_redirects), and
--   4. the dropped row is deleted from people.
-- Then any families that now have the SAME husband AND wife (e.g. the two
-- "Abid + Zeba" families once both Abids and both Zebas are merged) are
-- combined into one: children are moved into the family with the most
-- children, blank marriage fields are filled from the other, and the empty
-- family is deleted.
--
-- "Hidden and redirected": the dropped profile no longer exists in people, so
-- every existing search, count and list is automatically correct with no
-- per-query filtering; person.html / edit.html look up person_redirects when
-- a uid isn't found and redirect to the merged profile.
--
-- DATA IS NEVER SILENTLY DROPPED (2026-10-18 follow-up): any field blank on
-- the kept profile is filled from the duplicate (edit.html sends it), the
-- GEDCOM name parts (given_name/surname) are included, two different notes
-- can be kept together, and two sets of approved corrections
-- (person_profile_overrides) are combined field by field instead of the
-- duplicate's being discarded.
--
-- UNDO: person_merge_log.snapshot holds every affected row exactly as it was
-- before the merge (both people, their families, family_members, and rows in
-- the other tables), so a mistaken merge can be reconstructed.
--
-- Re-importing a GEDCOM can't resurrect a merged profile: each import gets a
-- new gedcom_uploads id and namespaces every uid with it (admin.html nsUid).

-- ── Tables ──────────────────────────────────────────────────────────────────
create table if not exists public.person_merge_log (
  id           uuid primary key default gen_random_uuid(),
  pairs        jsonb not null,          -- [{keep, drop, fields}] as requested
  snapshot     jsonb not null,          -- every affected row, before the merge
  result       jsonb,                   -- what the function did
  merged_by    text,
  created_at   timestamptz not null default now()
);
alter table public.person_merge_log enable row level security;
drop policy if exists person_merge_log_admin_read on public.person_merge_log;
create policy person_merge_log_admin_read on public.person_merge_log
  for select to authenticated using (public.akt_is_admin());
-- No insert/update/delete policies: written only by akt_merge_people().

create table if not exists public.person_redirects (
  old_uid      text primary key,
  new_uid      text not null,
  merge_log_id uuid references public.person_merge_log(id) on delete set null,
  created_at   timestamptz not null default now()
);
create index if not exists person_redirects_new_uid_idx on public.person_redirects(new_uid);
alter table public.person_redirects enable row level security;
drop policy if exists person_redirects_visitor_read on public.person_redirects;
create policy person_redirects_visitor_read on public.person_redirects
  for select to authenticated using (public.akt_is_visitor() or public.akt_is_admin());
-- No write policies: written only by akt_merge_people().

-- ── Merge function ──────────────────────────────────────────────────────────
create or replace function public.akt_merge_people(p_pairs jsonb, p_actor text default null)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  pair        jsonb;
  k           text;      -- kept uid
  d           text;      -- dropped uid
  f           jsonb;     -- chosen field values for the kept profile
  kp          public.people%rowtype;
  dp          public.people%rowtype;
  all_uids    text[] := '{}';
  keepers     text[] := '{}';
  drops       text[] := '{}';
  snap        jsonb;
  log_id      uuid;
  fam         record;
  keep_fam    text;
  other_fam   text;
  combined    jsonb := '[]'::jsonb;
  merged      jsonb := '[]'::jsonb;
  is_uuid_re  constant text := '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
begin
  if not public.akt_is_admin() then
    raise exception 'Only admins can merge profiles';
  end if;
  if jsonb_typeof(p_pairs) <> 'array' or jsonb_array_length(p_pairs) = 0 then
    raise exception 'No profiles to merge';
  end if;

  -- ── Validate every pair before touching anything ──
  for pair in select * from jsonb_array_elements(p_pairs) loop
    k := pair->>'keep';  d := pair->>'drop';
    if k is null or d is null or k = d then
      raise exception 'Each merge needs two different profiles';
    end if;
    if d = any(all_uids) or k = any(drops) then
      raise exception 'A profile appears in more than one merge pair';
    end if;
    select * into kp from public.people where uid = k;
    if not found then raise exception 'Profile % not found', k; end if;
    select * into dp from public.people where uid = d;
    if not found then raise exception 'Profile % not found', d; end if;
    if nullif(kp.sex, '') is not null and nullif(dp.sex, '') is not null and kp.sex <> dp.sex then
      raise exception '"%" and "%" have different genders — not the same person', kp.name, dp.name;
    end if;
    if exists (select 1 from public.families x
               where (x.husband_uid = k and x.wife_uid = d) or (x.husband_uid = d and x.wife_uid = k)) then
      raise exception '"%" and "%" are recorded as married to each other', kp.name, dp.name;
    end if;
    if exists (select 1 from public.family_members m join public.families x on x.uid = m.family_uid
               where m.role = 'child'
                 and ((m.person_uid = k and d in (x.husband_uid, x.wife_uid))
                   or (m.person_uid = d and k in (x.husband_uid, x.wife_uid)))) then
      raise exception '"%" and "%" are recorded as parent and child', kp.name, dp.name;
    end if;
    if exists (select 1 from public.profile_claims where person_uid = k)
       and exists (select 1 from public.profile_claims where person_uid = d) then
      raise exception 'Both "%" and "%" have been claimed by users — resolve the claims first', kp.name, dp.name;
    end if;
    all_uids := all_uids || k || d;
    keepers  := keepers || k;
    drops    := drops || d;
  end loop;

  -- ── Snapshot every row this merge can touch ──
  snap := jsonb_build_object(
    'people', (select coalesce(jsonb_agg(to_jsonb(p)), '[]') from public.people p where p.uid = any(all_uids)),
    'families', (select coalesce(jsonb_agg(to_jsonb(x)), '[]') from public.families x
                 where x.husband_uid = any(all_uids) or x.wife_uid = any(all_uids)),
    'family_members', (select coalesce(jsonb_agg(to_jsonb(m)), '[]') from public.family_members m
                       where m.person_uid = any(all_uids)
                          or m.family_uid in (select x.uid from public.families x
                                              where x.husband_uid = any(all_uids) or x.wife_uid = any(all_uids))),
    'profile_claims', (select coalesce(jsonb_agg(to_jsonb(r)), '[]') from public.profile_claims r where r.person_uid = any(drops)),
    'correction_requests', (select coalesce(jsonb_agg(to_jsonb(r)), '[]') from public.correction_requests r
                            where r.person_uid = any(drops) or r.duplicate_profile_uid = any(drops)),
    'person_profile_overrides', (select coalesce(jsonb_agg(to_jsonb(r)), '[]') from public.person_profile_overrides r where r.person_uid = any(all_uids)),
    'person_identity_members', (select coalesce(jsonb_agg(to_jsonb(r)), '[]') from public.person_identity_members r where r.person_uid = any(all_uids)),
    'person_identity_groups', (select coalesce(jsonb_agg(to_jsonb(r)), '[]') from public.person_identity_groups r where r.canonical_person_uid = any(drops)),
    'relationship_overrides', (select coalesce(jsonb_agg(to_jsonb(r)), '[]') from public.relationship_overrides r
                               where r.source_person_uid = any(drops) or r.related_person_uid = any(drops)),
    'canonical_family_groups', (select coalesce(jsonb_agg(to_jsonb(r)), '[]') from public.canonical_family_groups r
                                where r.primary_person_uid = any(drops) or r.spouse_person_uid = any(drops)),
    'canonical_family_children', (select coalesce(jsonb_agg(to_jsonb(r)), '[]') from public.canonical_family_children r where r.child_person_uid = any(drops)),
    'profile_change_log', (select coalesce(jsonb_agg(to_jsonb(r)), '[]') from public.profile_change_log r where r.profile_uid::text = any(drops))
  );

  insert into public.person_merge_log (pairs, snapshot, merged_by)
  values (p_pairs, snap, p_actor)
  returning id into log_id;

  -- ── Merge each pair ──
  for pair in select * from jsonb_array_elements(p_pairs) loop
    k := pair->>'keep';  d := pair->>'drop';
    f := coalesce(pair->'fields', '{}'::jsonb);

    -- 1. Chosen values onto the kept profile (only known, editable columns).
    update public.people set
      name               = case when f ? 'name'               then f->>'name'               else name end,
      given_name         = case when f ? 'given_name'         then f->>'given_name'         else given_name end,
      surname            = case when f ? 'surname'            then f->>'surname'            else surname end,
      nickname           = case when f ? 'nickname'           then f->>'nickname'           else nickname end,
      birth_date         = case when f ? 'birth_date'         then f->>'birth_date'         else birth_date end,
      birth_place        = case when f ? 'birth_place'        then f->>'birth_place'        else birth_place end,
      death_flag         = case when f ? 'death_flag'         then (f->>'death_flag')::boolean else death_flag end,
      death_date         = case when f ? 'death_date'         then f->>'death_date'         else death_date end,
      death_place        = case when f ? 'death_place'        then f->>'death_place'        else death_place end,
      root_place         = case when f ? 'root_place'         then f->>'root_place'         else root_place end,
      current_place      = case when f ? 'current_place'      then f->>'current_place'      else current_place end,
      occupation         = case when f ? 'occupation'         then f->>'occupation'         else occupation end,
      contact_address    = case when f ? 'contact_address'    then f->>'contact_address'    else contact_address end,
      mobile             = case when f ? 'mobile'             then f->>'mobile'             else mobile end,
      email              = case when f ? 'email'              then f->>'email'              else email end,
      notes              = case when f ? 'notes'              then f->>'notes'              else notes end,
      community_role     = case when f ? 'community_role'     then f->>'community_role'     else community_role end,
      is_contributor     = case when f ? 'is_contributor'     then (f->>'is_contributor')::boolean else is_contributor end,
      joined_by_marriage = case when f ? 'joined_by_marriage' then (f->>'joined_by_marriage')::boolean else joined_by_marriage end,
      sex                = coalesce(nullif(sex, ''), (select nullif(sex, '') from public.people where uid = d)),
      updated_at         = now()
    where uid = k;

    -- 2a. Marriages.
    update public.families set husband_uid = k where husband_uid = d;
    update public.families set wife_uid    = k where wife_uid    = d;

    -- 2b. Family membership (child-of / member rows). Drop d's row where k is
    --     already in that same family (unique family_uid, person_uid).
    delete from public.family_members m
     where m.person_uid = d
       and exists (select 1 from public.family_members m2 where m2.family_uid = m.family_uid and m2.person_uid = k);
    update public.family_members set person_uid = k where person_uid = d;

    -- 2c. Profile claims (unique person_uid; both-claimed was rejected above).
    update public.profile_claims set person_uid = k where person_uid = d;

    -- 2d. Corrections.
    update public.correction_requests set person_uid = k where person_uid = d;
    update public.correction_requests set duplicate_profile_uid = k where duplicate_profile_uid = d;

    -- 2e. Approved corrections (PK person_uid). If both have a row, fill every
    --     blank on k's row from d's, join two different profile notes, then
    --     drop d's row — so no approved correction is lost.
    if exists (select 1 from public.person_profile_overrides where person_uid = k) then
      update public.person_profile_overrides ko set
        corrected_name    = coalesce(nullif(ko.corrected_name, ''),    nullif(dv.corrected_name, '')),
        is_deceased       = coalesce(ko.is_deceased, dv.is_deceased),
        birth_date_text   = coalesce(nullif(ko.birth_date_text, ''),   nullif(dv.birth_date_text, '')),
        death_date_text   = coalesce(nullif(ko.death_date_text, ''),   nullif(dv.death_date_text, '')),
        mobile_number     = coalesce(nullif(ko.mobile_number, ''),     nullif(dv.mobile_number, '')),
        root_location     = coalesce(nullif(ko.root_location, ''),     nullif(dv.root_location, '')),
        birth_location    = coalesce(nullif(ko.birth_location, ''),    nullif(dv.birth_location, '')),
        current_location  = coalesce(nullif(ko.current_location, ''),  nullif(dv.current_location, '')),
        death_location    = coalesce(nullif(ko.death_location, ''),    nullif(dv.death_location, '')),
        birth_order_text  = coalesce(nullif(ko.birth_order_text, ''),  nullif(dv.birth_order_text, '')),
        corrected_gender  = coalesce(nullif(ko.corrected_gender, ''),  nullif(dv.corrected_gender, '')),
        email             = coalesce(nullif(ko.email, ''),             nullif(dv.email, '')),
        profile_note      = case
                              when nullif(trim(dv.profile_note), '') is null then ko.profile_note
                              when nullif(trim(ko.profile_note), '') is null then dv.profile_note
                              when trim(ko.profile_note) = trim(dv.profile_note) then ko.profile_note
                              else ko.profile_note || E'\n\n— From merged duplicate profile —\n' || dv.profile_note
                            end,
        updated_at        = now()
        from public.person_profile_overrides dv
       where ko.person_uid = k and dv.person_uid = d;
      delete from public.person_profile_overrides where person_uid = d;
    else
      update public.person_profile_overrides set person_uid = k where person_uid = d;
    end if;

    -- 2f. "Also recorded as" identity links (unique group_id, person_uid).
    delete from public.person_identity_members m
     where m.person_uid = d
       and exists (select 1 from public.person_identity_members m2 where m2.group_id = m.group_id and m2.person_uid = k);
    update public.person_identity_members set person_uid = k where person_uid = d;
    update public.person_identity_groups  set canonical_person_uid = k where canonical_person_uid = d;

    -- 2g. Relationship overrides; drop any that would now point at itself.
    update public.relationship_overrides set source_person_uid  = k where source_person_uid  = d;
    update public.relationship_overrides set related_person_uid = k where related_person_uid = d;
    delete from public.relationship_overrides where source_person_uid = k and related_person_uid = k;

    -- 2h. Community family overlay.
    update public.canonical_family_groups   set primary_person_uid = k where primary_person_uid = d;
    update public.canonical_family_groups   set spouse_person_uid  = k where spouse_person_uid  = d;
    update public.canonical_family_children set child_person_uid   = k where child_person_uid   = d;

    -- 2i. Activity history (uuid column): only movable when k is uuid-shaped;
    --     otherwise it stays under d and the redirect still resolves it.
    if k ~* is_uuid_re and d ~* is_uuid_re then
      update public.profile_change_log set profile_uid = k::uuid where profile_uid = d::uuid;
    end if;

    -- 3. Redirect (and re-point any older redirects that landed on d).
    update public.person_redirects set new_uid = k where new_uid = d;
    insert into public.person_redirects (old_uid, new_uid, merge_log_id)
    values (d, k, log_id)
    on conflict (old_uid) do update set new_uid = excluded.new_uid, merge_log_id = excluded.merge_log_id, created_at = now();

    -- 4. Remove the duplicate.
    select * into dp from public.people where uid = d;
    delete from public.people where uid = d;
    merged := merged || jsonb_build_object('keep', k, 'drop', d, 'drop_name', dp.name);
  end loop;

  -- ── Combine families that now have the same husband AND wife ──
  for fam in
    select x.husband_uid, x.wife_uid,
           array_agg(x.uid order by (select count(*) from public.family_members m
                                     where m.family_uid = x.uid and m.role = 'child') desc, x.uid) as fams
      from public.families x
     where x.husband_uid is not null and x.wife_uid is not null
       and (x.husband_uid = any(keepers) or x.wife_uid = any(keepers))
     group by x.husband_uid, x.wife_uid
    having count(*) > 1
  loop
    keep_fam := fam.fams[1];
    foreach other_fam in array fam.fams[2:array_length(fam.fams, 1)] loop
      insert into public.family_members (family_uid, person_uid, role, birth_order, custody_parent)
      select keep_fam, m.person_uid, m.role, m.birth_order, m.custody_parent
        from public.family_members m
       where m.family_uid = other_fam
      on conflict (family_uid, person_uid) do nothing;

      update public.families kf set
        marr_date            = coalesce(nullif(kf.marr_date, ''),   nullif(o.marr_date, '')),
        marr_place           = coalesce(nullif(kf.marr_place, ''),  nullif(o.marr_place, '')),
        marr_status          = coalesce(nullif(kf.marr_status, ''), nullif(o.marr_status, '')),
        marr_notes           = coalesce(nullif(kf.marr_notes, ''),  nullif(o.marr_notes, '')),
        husband_marriage_seq = coalesce(kf.husband_marriage_seq, o.husband_marriage_seq),
        wife_marriage_seq    = coalesce(kf.wife_marriage_seq, o.wife_marriage_seq)
        from public.families o
       where kf.uid = keep_fam and o.uid = other_fam;

      delete from public.families where uid = other_fam;   -- cascades its family_members
      combined := combined || jsonb_build_object('kept_family', keep_fam, 'removed_family', other_fam);
    end loop;
  end loop;

  update public.person_merge_log
     set result = jsonb_build_object('merged', merged, 'families_combined', combined)
   where id = log_id;

  return jsonb_build_object('log_id', log_id, 'merged', merged, 'families_combined', combined);
end;
$$;

revoke all on function public.akt_merge_people(jsonb, text) from public, anon;
grant execute on function public.akt_merge_people(jsonb, text) to authenticated;
