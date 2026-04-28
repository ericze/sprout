begin;

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email)
  values (new.id, coalesce(new.email, ''))
  on conflict (id) do update
    set email = excluded.email,
        updated_at = now();
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert or update of email on auth.users
for each row execute function public.handle_new_user();

create table if not exists public.baby_profiles (
  id uuid primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  birth_date timestamptz not null,
  gender text,
  avatar_storage_path text,
  is_active boolean not null default true,
  has_completed_onboarding boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1,
  deleted_at timestamptz
);

create index if not exists idx_baby_profiles_user_id on public.baby_profiles(user_id);
create index if not exists idx_baby_profiles_updated_at on public.baby_profiles(updated_at);

create table if not exists public.record_items (
  id uuid primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  baby_id uuid not null references public.baby_profiles(id) on delete cascade,
  type text not null,
  timestamp timestamptz not null,
  value double precision,
  left_nursing_seconds integer not null default 0,
  right_nursing_seconds integer not null default 0,
  sub_type text,
  image_storage_path text,
  ai_summary text,
  tags jsonb,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1,
  deleted_at timestamptz
);

create index if not exists idx_record_items_user_id on public.record_items(user_id);
create index if not exists idx_record_items_baby_id on public.record_items(baby_id);
create index if not exists idx_record_items_timestamp on public.record_items(timestamp desc);
create index if not exists idx_record_items_updated_at on public.record_items(updated_at);

create table if not exists public.memory_entries (
  id uuid primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  baby_id uuid not null references public.baby_profiles(id) on delete cascade,
  created_at timestamptz not null,
  age_in_days integer,
  image_storage_paths jsonb not null default '[]'::jsonb,
  note text,
  is_milestone boolean not null default false,
  updated_at timestamptz not null default now(),
  version bigint not null default 1,
  deleted_at timestamptz
);

create index if not exists idx_memory_entries_user_id on public.memory_entries(user_id);
create index if not exists idx_memory_entries_baby_id on public.memory_entries(baby_id);
create index if not exists idx_memory_entries_updated_at on public.memory_entries(updated_at);

alter table public.profiles enable row level security;
alter table public.baby_profiles enable row level security;
alter table public.record_items enable row level security;
alter table public.memory_entries enable row level security;

drop policy if exists "profiles select own" on public.profiles;
create policy "profiles select own"
on public.profiles for select
to authenticated
using (id = auth.uid());

drop policy if exists "baby profiles own select" on public.baby_profiles;
create policy "baby profiles own select"
on public.baby_profiles for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "baby profiles own insert" on public.baby_profiles;
create policy "baby profiles own insert"
on public.baby_profiles for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "baby profiles own update" on public.baby_profiles;
create policy "baby profiles own update"
on public.baby_profiles for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "record items own select" on public.record_items;
create policy "record items own select"
on public.record_items for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "record items own insert" on public.record_items;
create policy "record items own insert"
on public.record_items for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "record items own update" on public.record_items;
create policy "record items own update"
on public.record_items for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "memory entries own select" on public.memory_entries;
create policy "memory entries own select"
on public.memory_entries for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "memory entries own insert" on public.memory_entries;
create policy "memory entries own insert"
on public.memory_entries for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "memory entries own update" on public.memory_entries;
create policy "memory entries own update"
on public.memory_entries for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create or replace function public.server_now()
returns timestamptz
language sql
stable
as $$
  select now();
$$;

create or replace function public.assert_payload_owner(payload jsonb)
returns uuid
language plpgsql
stable
as $$
declare
  payload_user_id uuid;
begin
  payload_user_id := (payload->>'user_id')::uuid;
  if payload_user_id is null or payload_user_id <> auth.uid() then
    raise exception 'payload user_id must match authenticated user' using errcode = '42501';
  end if;
  return payload_user_id;
end;
$$;

create or replace function public.upsert_baby_profile(payload jsonb, expected_version bigint default null)
returns public.baby_profiles
language plpgsql
security invoker
as $$
declare
  row_id uuid := (payload->>'id')::uuid;
  current_row public.baby_profiles;
  saved_row public.baby_profiles;
begin
  perform public.assert_payload_owner(payload);

  select * into current_row
  from public.baby_profiles
  where id = row_id
  for update;

  if found then
    if expected_version is null or current_row.version <> expected_version then
      raise exception 'version conflict for baby_profiles row %', row_id using errcode = '40001';
    end if;

    update public.baby_profiles
    set name = payload->>'name',
        birth_date = (payload->>'birth_date')::timestamptz,
        gender = nullif(payload->>'gender', ''),
        avatar_storage_path = nullif(payload->>'avatar_storage_path', ''),
        is_active = coalesce((payload->>'is_active')::boolean, true),
        has_completed_onboarding = coalesce((payload->>'has_completed_onboarding')::boolean, false),
        deleted_at = case when payload ? 'deleted_at' then nullif(payload->>'deleted_at', '')::timestamptz else deleted_at end,
        updated_at = now(),
        version = version + 1
    where id = row_id
    returning * into saved_row;
  else
    if expected_version is not null then
      raise exception 'version conflict for missing baby_profiles row %', row_id using errcode = '40001';
    end if;

    insert into public.baby_profiles (
      id, user_id, name, birth_date, gender, avatar_storage_path,
      is_active, has_completed_onboarding, created_at, updated_at, version, deleted_at
    )
    values (
      row_id,
      (payload->>'user_id')::uuid,
      payload->>'name',
      (payload->>'birth_date')::timestamptz,
      nullif(payload->>'gender', ''),
      nullif(payload->>'avatar_storage_path', ''),
      coalesce((payload->>'is_active')::boolean, true),
      coalesce((payload->>'has_completed_onboarding')::boolean, false),
      coalesce((payload->>'created_at')::timestamptz, now()),
      now(),
      1,
      nullif(payload->>'deleted_at', '')::timestamptz
    )
    returning * into saved_row;
  end if;

  return saved_row;
end;
$$;

create or replace function public.upsert_record_item(payload jsonb, expected_version bigint default null)
returns public.record_items
language plpgsql
security invoker
as $$
declare
  row_id uuid := (payload->>'id')::uuid;
  current_row public.record_items;
  saved_row public.record_items;
begin
  perform public.assert_payload_owner(payload);

  select * into current_row
  from public.record_items
  where id = row_id
  for update;

  if found then
    if expected_version is null or current_row.version <> expected_version then
      raise exception 'version conflict for record_items row %', row_id using errcode = '40001';
    end if;

    update public.record_items
    set baby_id = (payload->>'baby_id')::uuid,
        type = payload->>'type',
        timestamp = (payload->>'timestamp')::timestamptz,
        value = nullif(payload->>'value', '')::double precision,
        left_nursing_seconds = coalesce((payload->>'left_nursing_seconds')::integer, 0),
        right_nursing_seconds = coalesce((payload->>'right_nursing_seconds')::integer, 0),
        sub_type = nullif(payload->>'sub_type', ''),
        image_storage_path = nullif(payload->>'image_storage_path', ''),
        ai_summary = nullif(payload->>'ai_summary', ''),
        tags = payload->'tags',
        note = nullif(payload->>'note', ''),
        deleted_at = case when payload ? 'deleted_at' then nullif(payload->>'deleted_at', '')::timestamptz else deleted_at end,
        updated_at = now(),
        version = version + 1
    where id = row_id
    returning * into saved_row;
  else
    if expected_version is not null then
      raise exception 'version conflict for missing record_items row %', row_id using errcode = '40001';
    end if;

    insert into public.record_items (
      id, user_id, baby_id, type, timestamp, value, left_nursing_seconds,
      right_nursing_seconds, sub_type, image_storage_path, ai_summary, tags,
      note, created_at, updated_at, version, deleted_at
    )
    values (
      row_id,
      (payload->>'user_id')::uuid,
      (payload->>'baby_id')::uuid,
      payload->>'type',
      (payload->>'timestamp')::timestamptz,
      nullif(payload->>'value', '')::double precision,
      coalesce((payload->>'left_nursing_seconds')::integer, 0),
      coalesce((payload->>'right_nursing_seconds')::integer, 0),
      nullif(payload->>'sub_type', ''),
      nullif(payload->>'image_storage_path', ''),
      nullif(payload->>'ai_summary', ''),
      payload->'tags',
      nullif(payload->>'note', ''),
      now(),
      now(),
      1,
      nullif(payload->>'deleted_at', '')::timestamptz
    )
    returning * into saved_row;
  end if;

  return saved_row;
end;
$$;

create or replace function public.upsert_memory_entry(payload jsonb, expected_version bigint default null)
returns public.memory_entries
language plpgsql
security invoker
as $$
declare
  row_id uuid := (payload->>'id')::uuid;
  current_row public.memory_entries;
  saved_row public.memory_entries;
begin
  perform public.assert_payload_owner(payload);

  select * into current_row
  from public.memory_entries
  where id = row_id
  for update;

  if found then
    if expected_version is null or current_row.version <> expected_version then
      raise exception 'version conflict for memory_entries row %', row_id using errcode = '40001';
    end if;

    update public.memory_entries
    set baby_id = (payload->>'baby_id')::uuid,
        created_at = (payload->>'created_at')::timestamptz,
        age_in_days = nullif(payload->>'age_in_days', '')::integer,
        image_storage_paths = coalesce(payload->'image_storage_paths', '[]'::jsonb),
        note = nullif(payload->>'note', ''),
        is_milestone = coalesce((payload->>'is_milestone')::boolean, false),
        deleted_at = case when payload ? 'deleted_at' then nullif(payload->>'deleted_at', '')::timestamptz else deleted_at end,
        updated_at = now(),
        version = version + 1
    where id = row_id
    returning * into saved_row;
  else
    if expected_version is not null then
      raise exception 'version conflict for missing memory_entries row %', row_id using errcode = '40001';
    end if;

    insert into public.memory_entries (
      id, user_id, baby_id, created_at, age_in_days, image_storage_paths,
      note, is_milestone, updated_at, version, deleted_at
    )
    values (
      row_id,
      (payload->>'user_id')::uuid,
      (payload->>'baby_id')::uuid,
      (payload->>'created_at')::timestamptz,
      nullif(payload->>'age_in_days', '')::integer,
      coalesce(payload->'image_storage_paths', '[]'::jsonb),
      nullif(payload->>'note', ''),
      coalesce((payload->>'is_milestone')::boolean, false),
      now(),
      1,
      nullif(payload->>'deleted_at', '')::timestamptz
    )
    returning * into saved_row;
  end if;

  return saved_row;
end;
$$;

create or replace function public.soft_delete_row(table_name text, row_id uuid, expected_version bigint default null)
returns void
language plpgsql
security invoker
as $$
declare
  current_version bigint;
  current_user_id uuid;
begin
  if table_name not in ('baby_profiles', 'record_items', 'memory_entries') then
    raise exception 'unsupported table %', table_name using errcode = '42804';
  end if;

  execute format('select version, user_id from public.%I where id = $1 for update', table_name)
  into current_version, current_user_id
  using row_id;

  if current_user_id is null then
    return;
  end if;

  if current_user_id <> auth.uid() then
    raise exception 'row does not belong to authenticated user' using errcode = '42501';
  end if;

  if expected_version is not null and current_version <> expected_version then
    raise exception 'version conflict for % row %', table_name, row_id using errcode = '40001';
  end if;

  execute format('update public.%I set deleted_at = now(), updated_at = now(), version = version + 1 where id = $1', table_name)
  using row_id;
end;
$$;

insert into storage.buckets (id, name, public)
values
  ('food-photos', 'food-photos', false),
  ('treasure-photos', 'treasure-photos', false),
  ('baby-avatars', 'baby-avatars', false)
on conflict (id) do update set public = excluded.public;

drop policy if exists "users can select own storage objects" on storage.objects;
create policy "users can select own storage objects"
on storage.objects for select
to authenticated
using (
  bucket_id in ('food-photos', 'treasure-photos', 'baby-avatars')
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "users can insert own storage objects" on storage.objects;
create policy "users can insert own storage objects"
on storage.objects for insert
to authenticated
with check (
  bucket_id in ('food-photos', 'treasure-photos', 'baby-avatars')
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "users can update own storage objects" on storage.objects;
create policy "users can update own storage objects"
on storage.objects for update
to authenticated
using (
  bucket_id in ('food-photos', 'treasure-photos', 'baby-avatars')
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id in ('food-photos', 'treasure-photos', 'baby-avatars')
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "users can delete own storage objects" on storage.objects;
create policy "users can delete own storage objects"
on storage.objects for delete
to authenticated
using (
  bucket_id in ('food-photos', 'treasure-photos', 'baby-avatars')
  and (storage.foldername(name))[1] = auth.uid()::text
);

commit;
