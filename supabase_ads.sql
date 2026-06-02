-- Community ad system for apnonkitalash.com
-- Run once in the AKT Supabase project (fusairoeiabmqvsbxhfi.supabase.co)
--
-- One active ad at a time. Others sit in queue (pending).
-- Impression = unique logged-in user who was shown the ad (counted once, on first show).
-- Dismissed = user clicked the close button (subset of shown).

CREATE TABLE IF NOT EXISTS public.ads (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  advertiser_name   text        NOT NULL,
  image_url         text        NOT NULL,   -- URL to the ad creative
  link_url          text,                   -- optional click-through URL
  status            text        NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'active', 'paused', 'completed')),
  target_impressions int        NOT NULL DEFAULT 100,
  notes             text,                   -- internal admin notes
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ad_impressions (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  ad_id        uuid        NOT NULL REFERENCES public.ads(id) ON DELETE CASCADE,
  visitor_id   uuid        NOT NULL REFERENCES public.visitors(id) ON DELETE CASCADE,
  shown_at     timestamptz NOT NULL DEFAULT now(),   -- when popup was displayed
  dismissed_at timestamptz,                          -- null = seen but not dismissed yet
  UNIQUE (ad_id, visitor_id)                         -- one row per user per ad
);

CREATE INDEX IF NOT EXISTS idx_ad_impressions_ad_id
  ON public.ad_impressions (ad_id);

CREATE INDEX IF NOT EXISTS idx_ad_impressions_visitor_id
  ON public.ad_impressions (visitor_id);

ALTER TABLE public.ads            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ad_impressions ENABLE ROW LEVEL SECURITY;

-- Admins can do everything on ads
CREATE POLICY "ads_admin_all" ON public.ads FOR ALL TO authenticated
USING (EXISTS (
  SELECT 1 FROM public.visitors v
  WHERE v.auth_user_id = auth.uid()
    AND v.access_role IN ('admin','superadmin')
    AND coalesce(v.is_blocked, false) = false
));

-- Authenticated visitors can read active ads
CREATE POLICY "ads_visitor_read" ON public.ads FOR SELECT TO authenticated
USING (status = 'active');

-- Admins can read all impressions
CREATE POLICY "ad_impressions_admin_read" ON public.ad_impressions FOR SELECT TO authenticated
USING (EXISTS (
  SELECT 1 FROM public.visitors v
  WHERE v.auth_user_id = auth.uid()
    AND v.access_role IN ('admin','superadmin')
    AND coalesce(v.is_blocked, false) = false
));

-- Authenticated visitors can insert/update their own impression rows
CREATE POLICY "ad_impressions_self_insert" ON public.ad_impressions FOR INSERT TO authenticated
WITH CHECK (
  visitor_id IN (
    SELECT id FROM public.visitors WHERE auth_user_id = auth.uid()
  )
);

CREATE POLICY "ad_impressions_self_update" ON public.ad_impressions FOR UPDATE TO authenticated
USING (
  visitor_id IN (
    SELECT id FROM public.visitors WHERE auth_user_id = auth.uid()
  )
)
WITH CHECK (true);
