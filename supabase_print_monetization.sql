-- Print Tree monetization controls
-- Run once in the AKT Supabase project (fusairoeiabmqvsbxhfi.supabase.co)

-- Global on/off toggle stored in admin_config
INSERT INTO public.admin_config (key, value)
VALUES ('print_monetization', 'enabled')
ON CONFLICT (key) DO NOTHING;

-- Custom price (in INR) stored in admin_config
INSERT INTO public.admin_config (key, value)
VALUES ('print_price', '49')
ON CONFLICT (key) DO NOTHING;

-- Per-user free printing flag
ALTER TABLE public.visitors
  ADD COLUMN IF NOT EXISTS print_free boolean DEFAULT false;
