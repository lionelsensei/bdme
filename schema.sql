create extension if not exists "uuid-ossp";

create table if not exists bdme_users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  display_name text,
  role text not null default 'user' check (role in ('user', 'admin')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists bdme_books (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references bdme_users(id) on delete cascade,
  bdgest_id text,
  title text not null,
  series text,
  tome integer,
  author text,
  illustrator text,
  publisher text,
  year integer,
  genre text,
  ean text,
  cover_url text,
  synopsis text,
  read_status text not null default 'unread' check (read_status in ('unread', 'reading', 'read')),
  added_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists bdme_books_user_id_idx on bdme_books(user_id);
create index if not exists bdme_books_bdgest_id_idx on bdme_books(bdgest_id);

create table if not exists bdme_wishlist (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references bdme_users(id) on delete cascade,
  bdgest_id text,
  title text not null,
  series text,
  tome integer,
  author text,
  illustrator text,
  publisher text,
  year integer,
  cover_url text,
  added_at timestamptz not null default now()
);

create index if not exists bdme_wishlist_user_id_idx on bdme_wishlist(user_id);

create table if not exists bdme_api_keys (
  id uuid primary key default uuid_generate_v4(),
  service text not null default 'bdgest',
  label text not null,
  encrypted_login text,
  encrypted_password text,
  created_by uuid references bdme_users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table bdme_users enable row level security;
create policy "users_read_own" on bdme_users for select using (auth.uid() = id);
create policy "admin_read_all" on bdme_users for select using (exists (select 1 from bdme_users u where u.id = auth.uid() and u.role = 'admin'));
create policy "admin_update_all" on bdme_users for update using (exists (select 1 from bdme_users u where u.id = auth.uid() and u.role = 'admin'));
create policy "users_update_own" on bdme_users for update using (auth.uid() = id);

alter table bdme_books enable row level security;
create policy "books_user_crud" on bdme_books for all using (auth.uid() = user_id);

alter table bdme_wishlist enable row level security;
create policy "wishlist_user_crud" on bdme_wishlist for all using (auth.uid() = user_id);

alter table bdme_api_keys enable row level security;
create policy "api_keys_admin_only" on bdme_api_keys for all using (exists (select 1 from bdme_users u where u.id = auth.uid() and u.role = 'admin'));

create or replace function update_updated_at() returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end; $$;

create trigger bdme_users_updated_at before update on bdme_users for each row execute function update_updated_at();
create trigger bdme_books_updated_at before update on bdme_books for each row execute function update_updated_at();
create trigger bdme_api_keys_updated_at before update on bdme_api_keys for each row execute function update_updated_at();

create or replace function handle_new_user() returns trigger language plpgsql security definer as $$
begin
  insert into bdme_users (id, email, display_name, role)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email,'@',1)), coalesce(new.raw_user_meta_data->>'role','user'));
  return new;
end; $$;

create trigger on_auth_user_created after insert on auth.users for each row execute function handle_new_user();
