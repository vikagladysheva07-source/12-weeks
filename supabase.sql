-- 12 недель · личные кабинеты
-- Выполнить один раз: Supabase → SQL Editor → New query → вставить → Run

create table if not exists public.tw_state (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  data       jsonb not null,
  updated_at timestamptz not null default now(),
  constraint tw_state_size check (pg_column_size(data) < 2000000)
);

alter table public.tw_state enable row level security;

-- каждый пользователь видит и меняет только свою строку
drop policy if exists "tw own select" on public.tw_state;
drop policy if exists "tw own insert" on public.tw_state;
drop policy if exists "tw own update" on public.tw_state;
drop policy if exists "tw own delete" on public.tw_state;

create policy "tw own select" on public.tw_state for select to authenticated using (auth.uid() = user_id);
create policy "tw own insert" on public.tw_state for insert to authenticated with check (auth.uid() = user_id);
create policy "tw own update" on public.tw_state for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "tw own delete" on public.tw_state for delete to authenticated using (auth.uid() = user_id);

revoke all on public.tw_state from anon;
grant select, insert, update, delete on public.tw_state to authenticated;
