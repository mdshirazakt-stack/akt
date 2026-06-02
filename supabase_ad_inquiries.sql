-- Ad inquiry / interest form submissions from advertise.html
-- Run once in the AKT Supabase project (fusairoeiabmqvsbxhfi.supabase.co)

CREATE TABLE IF NOT EXISTS public.ad_inquiries (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  advertiser_name   text        NOT NULL,
  mobile            text        NOT NULL,
  business_detail   text        NOT NULL,
  ad_concept        text,       -- what they wish to show
  impression_target int,        -- how many impressions they want
  website_url       text,
  status            text        NOT NULL DEFAULT 'new'
                    CHECK (status IN ('new', 'contacted', 'converted', 'declined')),
  admin_notes       text,
  created_at        timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.ad_inquiries ENABLE ROW LEVEL SECURITY;

-- Anyone (including unauthenticated) can submit an inquiry
CREATE POLICY "ad_inquiries_public_insert"
ON public.ad_inquiries FOR INSERT TO anon, authenticated
WITH CHECK (true);

-- Only admins can read and update inquiries
CREATE POLICY "ad_inquiries_admin_read"
ON public.ad_inquiries FOR SELECT TO authenticated
USING (EXISTS (
  SELECT 1 FROM public.visitors v
  WHERE v.auth_user_id = auth.uid()
    AND v.access_role IN ('admin','superadmin')
    AND coalesce(v.is_blocked, false) = false
));

CREATE POLICY "ad_inquiries_admin_update"
ON public.ad_inquiries FOR UPDATE TO authenticated
USING (EXISTS (
  SELECT 1 FROM public.visitors v
  WHERE v.auth_user_id = auth.uid()
    AND v.access_role IN ('admin','superadmin')
    AND coalesce(v.is_blocked, false) = false
))
WITH CHECK (true);
