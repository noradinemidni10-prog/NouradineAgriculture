-- Nouradine Agriculture: initial Supabase schema
-- Run in Supabase SQL Editor. Safe to re-run (idempotent policies/indexes).

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  phone text,
  preferred_language text not null default 'ar',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.farms (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  location text,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.fields (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  farm_id uuid references public.farms(id) on delete set null,
  name text not null,
  crop text,
  area_hectares numeric(12,3) check (area_hectares is null or area_hectares >= 0),
  soil_type text,
  created_at timestamptz not null default now()
);

create table if not exists public.farm_tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  field_id uuid references public.fields(id) on delete set null,
  title text not null,
  details text,
  due_date date,
  status text not null default 'pending' check (status in ('pending','done','cancelled')),
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

create table if not exists public.soil_tests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  field_id uuid references public.fields(id) on delete set null,
  ph numeric(4,2) check (ph is null or (ph >= 0 and ph <= 14)),
  ec numeric(10,3) check (ec is null or ec >= 0),
  soil_type text,
  test_date date not null default current_date,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.crop_notes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  field_id uuid references public.fields(id) on delete set null,
  crop text not null,
  note_type text not null default 'general',
  content text not null,
  observed_at date not null default current_date,
  created_at timestamptz not null default now()
);

create index if not exists farms_user_id_idx on public.farms(user_id);
create index if not exists fields_user_id_idx on public.fields(user_id);
create index if not exists farm_tasks_user_due_idx on public.farm_tasks(user_id, due_date);
create index if not exists soil_tests_user_date_idx on public.soil_tests(user_id, test_date desc);
create index if not exists crop_notes_user_date_idx on public.crop_notes(user_id, observed_at desc);

alter table public.profiles enable row level security;
alter table public.farms enable row level security;
alter table public.fields enable row level security;
alter table public.farm_tasks enable row level security;
alter table public.soil_tests enable row level security;
alter table public.crop_notes enable row level security;

drop policy if exists "Profiles: read own" on public.profiles;
create policy "Profiles: read own" on public.profiles for select to authenticated using (id = auth.uid());
drop policy if exists "Profiles: insert own" on public.profiles;
create policy "Profiles: insert own" on public.profiles for insert to authenticated with check (id = auth.uid());
drop policy if exists "Profiles: update own" on public.profiles;
create policy "Profiles: update own" on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists "Farms: users manage own" on public.farms;
create policy "Farms: users manage own" on public.farms for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "Fields: users manage own" on public.fields;
create policy "Fields: users manage own" on public.fields for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "Tasks: users manage own" on public.farm_tasks;
create policy "Tasks: users manage own" on public.farm_tasks for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "Soil tests: users manage own" on public.soil_tests;
create policy "Soil tests: users manage own" on public.soil_tests for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "Crop notes: users manage own" on public.crop_notes;
create policy "Crop notes: users manage own" on public.crop_notes for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', ''))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
