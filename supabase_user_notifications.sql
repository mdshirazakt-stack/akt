-- User notification inbox for in-app messages on next login.
-- Run once in the AKT Supabase project (fusairoeiabmqvsbxhfi.supabase.co)

CREATE TABLE IF NOT EXISTS public.user_notifications (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Recipient matching — any of these can be used to find the right visitor
  recipient_mobile   text,
  recipient_email    text,
  recipient_auth_uid uuid,
  -- Message content
  title         text        NOT NULL,
  message       text        NOT NULL,
  -- Source reference
  source_type   text,        -- e.g. 'correction', 'suggestion'
  source_id     uuid,
  -- Lifecycle
  shown_at        timestamptz, -- set when the banner is displayed on login
  acknowledged_at timestamptz, -- set when the user clicks "Got it"
  created_at      timestamptz  NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_notifications_mobile
  ON public.user_notifications (recipient_mobile)
  WHERE shown_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_user_notifications_email
  ON public.user_notifications (recipient_email)
  WHERE shown_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_user_notifications_auth_uid
  ON public.user_notifications (recipient_auth_uid)
  WHERE shown_at IS NULL;

ALTER TABLE public.user_notifications ENABLE ROW LEVEL SECURITY;

-- Admins can insert notifications
CREATE POLICY "user_notifications_admin_insert"
ON public.user_notifications FOR INSERT TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.visitors v
    WHERE v.auth_user_id = auth.uid()
      AND v.access_role IN ('admin', 'superadmin')
      AND coalesce(v.is_blocked, false) = false
  )
);

-- Users can read their own notifications (matched by auth_uid, email, or mobile)
CREATE POLICY "user_notifications_self_read"
ON public.user_notifications FOR SELECT TO authenticated
USING (
  recipient_auth_uid = auth.uid()
  OR EXISTS (
    SELECT 1 FROM public.visitors v
    WHERE v.auth_user_id = auth.uid()
      AND (
        (recipient_email  IS NOT NULL AND lower(v.email)  = lower(recipient_email))
        OR (recipient_mobile IS NOT NULL AND regexp_replace(v.mobile, '[^0-9]','','g')
                                          = regexp_replace(recipient_mobile, '[^0-9]','','g'))
      )
  )
);

-- Users can mark their own notifications as shown
CREATE POLICY "user_notifications_self_update"
ON public.user_notifications FOR UPDATE TO authenticated
USING (
  recipient_auth_uid = auth.uid()
  OR EXISTS (
    SELECT 1 FROM public.visitors v
    WHERE v.auth_user_id = auth.uid()
      AND (
        (recipient_email  IS NOT NULL AND lower(v.email)  = lower(recipient_email))
        OR (recipient_mobile IS NOT NULL AND regexp_replace(v.mobile, '[^0-9]','','g')
                                          = regexp_replace(recipient_mobile, '[^0-9]','','g'))
      )
  )
)
WITH CHECK (true);
