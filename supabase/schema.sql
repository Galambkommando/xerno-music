-- Xerno Music sync schema.
-- Paste this entire file into the Supabase SQL Editor and run it once.
-- Quick device sync uses public.sync_rooms. The room code is the shared secret.
-- Account sync uses public.user_libraries and auth.users.

create extension if not exists pgcrypto;

create table if not exists public.sync_rooms (
  code text primary key,
  payload jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.user_libraries (
  user_id uuid primary key references auth.users (id) on delete cascade,
  payload jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.sync_rooms enable row level security;
alter table public.user_libraries enable row level security;

drop policy if exists sync_rooms_select on public.sync_rooms;
create policy sync_rooms_select on public.sync_rooms
  for select to anon, authenticated
  using (true);

drop policy if exists sync_rooms_insert on public.sync_rooms;
create policy sync_rooms_insert on public.sync_rooms
  for insert to anon, authenticated
  with check (true);

drop policy if exists sync_rooms_update on public.sync_rooms;
create policy sync_rooms_update on public.sync_rooms
  for update to anon, authenticated
  using (true)
  with check (true);

drop policy if exists user_libraries_all on public.user_libraries;
create policy user_libraries_all on public.user_libraries
  for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

grant select, insert, update on public.sync_rooms to anon, authenticated;
grant select, insert, update, delete on public.user_libraries to authenticated;

do $$
begin
  alter publication supabase_realtime add table public.sync_rooms;
exception
  when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.user_libraries;
exception
  when duplicate_object then null;
end $$;

-- Optional public audio bucket. A project without storage configured still keeps the tables above.
do $$
begin
  insert into storage.buckets (id, name, public)
  values ('xerno-audio', 'xerno-audio', true)
  on conflict (id) do nothing;

  drop policy if exists xerno_audio_read on storage.objects;
  create policy xerno_audio_read on storage.objects
    for select to anon, authenticated
    using (bucket_id = 'xerno-audio');

  drop policy if exists xerno_audio_insert on storage.objects;
  create policy xerno_audio_insert on storage.objects
    for insert to authenticated
    with check (bucket_id = 'xerno-audio');
exception
  when others then
    raise notice 'Storage policies were skipped: %', sqlerrm;
end $$;
