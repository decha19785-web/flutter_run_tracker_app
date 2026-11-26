-- Run this if you already applied the earlier schema that used image_url.
alter table public.run_tb
  add column if not exists image_path text;
