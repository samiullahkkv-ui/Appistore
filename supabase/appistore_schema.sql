-- Appistore developer marketplace schema
-- Run this in Supabase SQL Editor after the project database is available.
create extension if not exists pgcrypto;

create table if not exists public.user_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'developer' check (role in ('admin','developer')),
  created_at timestamptz not null default now()
);
alter table public.user_roles enable row level security;

create or replace function public.appistore_new_user_role()
returns trigger language plpgsql security definer set search_path = public
as $appistore$
begin
  insert into public.user_roles (user_id, role) values (new.id, 'developer')
  on conflict (user_id) do nothing;
  return new;
end;
$appistore$;
drop trigger if exists appistore_auth_user_created on auth.users;
create trigger appistore_auth_user_created
after insert on auth.users for each row execute procedure public.appistore_new_user_role();


create or replace function public.is_appistore_admin()
returns boolean language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.user_roles
    where user_id = auth.uid() and role = 'admin'
  );
$$;
grant execute on function public.is_appistore_admin() to authenticated;

drop policy if exists "read own role" on public.user_roles;
create policy "read own role" on public.user_roles
for select to authenticated using (user_id = auth.uid() or public.is_appistore_admin());

create table if not exists public.apps (
  id uuid primary key default gen_random_uuid(),
  developer_id uuid not null references auth.users(id) on delete cascade,
  app_name text not null check (char_length(app_name) between 2 and 70),
  description text not null check (char_length(description) between 20 and 3000),
  category text not null default 'Other',
  icon_path text not null,
  screenshot_paths text[] not null,
  apk_url text not null check (apk_url ~ '^https://'),
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  rejection_reason text,
  is_pinned boolean not null default false,
  pinned_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint exactly_four_screenshots check (cardinality(screenshot_paths) = 4)
);
create index if not exists apps_public_order_idx on public.apps(status, is_pinned desc, pinned_at desc, created_at desc);
create index if not exists apps_developer_order_idx on public.apps(developer_id, created_at desc);
alter table public.apps enable row level security;

drop policy if exists "public sees approved apps" on public.apps;
create policy "public sees approved apps" on public.apps
for select to anon, authenticated using (status = 'approved');
drop policy if exists "developers see own apps" on public.apps;
create policy "developers see own apps" on public.apps
for select to authenticated using (developer_id = auth.uid());
drop policy if exists "admins see all apps" on public.apps;
create policy "admins see all apps" on public.apps
for select to authenticated using (public.is_appistore_admin());
drop policy if exists "developers submit pending apps" on public.apps;
create policy "developers submit pending apps" on public.apps
for insert to authenticated with check (
  developer_id = auth.uid() and status = 'pending' and is_pinned = false
);
drop policy if exists "developers edit own pending or rejected apps" on public.apps;
create policy "developers edit own pending or rejected apps" on public.apps
for update to authenticated using (
  developer_id = auth.uid() and status in ('pending','rejected')
) with check (
  developer_id = auth.uid() and status = 'pending' and is_pinned = false
);
drop policy if exists "admins moderate and pin apps" on public.apps;
create policy "admins moderate and pin apps" on public.apps
for update to authenticated using (public.is_appistore_admin())
with check (public.is_appistore_admin());

grant select on public.apps to anon, authenticated;
grant insert, update on public.apps to authenticated;
grant select on public.user_roles to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('appistore-assets','appistore-assets',true,5242880,array['image/png','image/jpeg','image/webp'])
on conflict (id) do update set public = true, file_size_limit = 5242880, allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "public read appistore assets" on storage.objects;
create policy "public read appistore assets" on storage.objects
for select to anon, authenticated using (bucket_id = 'appistore-assets');
drop policy if exists "developers upload own appistore assets" on storage.objects;
create policy "developers upload own appistore assets" on storage.objects
for insert to authenticated with check (
  bucket_id = 'appistore-assets' and (storage.foldername(name))[1] = auth.uid()::text
);
drop policy if exists "developers update own appistore assets" on storage.objects;
create policy "developers update own appistore assets" on storage.objects
for update to authenticated using (
  bucket_id = 'appistore-assets' and (storage.foldername(name))[1] = auth.uid()::text
) with check (
  bucket_id = 'appistore-assets' and (storage.foldername(name))[1] = auth.uid()::text
);
drop policy if exists "developers delete own appistore assets" on storage.objects;
create policy "developers delete own appistore assets" on storage.objects
for delete to authenticated using (
  bucket_id = 'appistore-assets' and (storage.foldername(name))[1] = auth.uid()::text
);

-- After creating your own account, promote only your email to admin:
-- insert into public.user_roles (user_id, role)
-- select id, 'admin' from auth.users where email = 'YOUR-ADMIN-EMAIL'
-- on conflict (user_id) do update set role = 'admin';
