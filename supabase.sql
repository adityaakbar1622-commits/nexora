-- Jalankan di Supabase SQL Editor. Profiles hanya menyimpan profil dan role akun.
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  role text not null default 'user' check (role in ('user','admin','guru')),
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- Trigger membuat profil baru secara otomatis; role default selalu user.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  insert into public.profiles(id, display_name, role)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name',''), 'user');
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();

-- Pengguna hanya dapat membaca profilnya sendiri. Tidak ada policy untuk mengubah role.
drop policy if exists "profile_select_own" on public.profiles;
create policy "profile_select_own" on public.profiles
for select to authenticated using (auth.uid() = id);
