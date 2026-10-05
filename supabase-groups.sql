-- 12 недель · группы с общим счётом недели
-- Выполнить один раз: Supabase → SQL Editor → Run

create table if not exists public.tw_group (
  code       text primary key,
  name       text not null,
  owner      uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
create table if not exists public.tw_group_member (
  code       text not null references public.tw_group(code) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  name       text not null default '',
  scores     jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  primary key (code, user_id)
);
alter table public.tw_group enable row level security;
alter table public.tw_group_member enable row level security;
revoke all on public.tw_group from anon, authenticated;
revoke all on public.tw_group_member from anon, authenticated;
-- прямого доступа к таблицам нет, только через функции ниже

create or replace function public.tw_group_create(p_name text, p_me text)
returns text language plpgsql security definer set search_path = public as $$
declare c text; i int := 0;
begin
  if auth.uid() is null then raise exception 'auth'; end if;
  if (select count(*) from public.tw_group where owner = auth.uid()) >= 5 then raise exception 'limit'; end if;
  loop
    c := upper(substr(translate(md5(random()::text || clock_timestamp()::text),'0o1il','ZQWXY'),1,6));
    exit when not exists (select 1 from public.tw_group where code = c);
    i := i + 1; if i > 20 then raise exception 'code'; end if;
  end loop;
  insert into public.tw_group(code,name,owner) values (c, left(coalesce(p_name,'Группа'),40), auth.uid());
  insert into public.tw_group_member(code,user_id,name) values (c, auth.uid(), left(coalesce(p_me,''),40));
  return c;
end $$;

create or replace function public.tw_group_join(p_code text, p_me text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare g public.tw_group;
begin
  if auth.uid() is null then raise exception 'auth'; end if;
  select * into g from public.tw_group where code = upper(trim(p_code));
  if not found then raise exception 'not_found'; end if;
  if (select count(*) from public.tw_group_member m where m.code = g.code) >= 12
     and not exists (select 1 from public.tw_group_member m where m.code = g.code and m.user_id = auth.uid()) then
    raise exception 'full';
  end if;
  insert into public.tw_group_member(code,user_id,name) values (g.code, auth.uid(), left(coalesce(p_me,''),40))
  on conflict (code,user_id) do update set name = excluded.name, updated_at = now();
  return jsonb_build_object('code', g.code, 'name', g.name);
end $$;

create or replace function public.tw_group_leave(p_code text)
returns void language plpgsql security definer set search_path = public as $$
begin
  delete from public.tw_group_member where code = upper(trim(p_code)) and user_id = auth.uid();
  delete from public.tw_group g where g.code = upper(trim(p_code)) and not exists (select 1 from public.tw_group_member m where m.code = g.code);
end $$;

create or replace function public.tw_group_score(p_code text, p_me text, p_scores jsonb)
returns void language plpgsql security definer set search_path = public as $$
begin
  if pg_column_size(p_scores) > 20000 then raise exception 'too_large'; end if;
  update public.tw_group_member set scores = p_scores, name = coalesce(nullif(left(p_me,40),''), name), updated_at = now()
  where code = upper(trim(p_code)) and user_id = auth.uid();
end $$;

create or replace function public.tw_group_board(p_code text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare g public.tw_group;
begin
  select * into g from public.tw_group where code = upper(trim(p_code));
  if not found then raise exception 'not_found'; end if;
  if not exists (select 1 from public.tw_group_member m where m.code = g.code and m.user_id = auth.uid()) then raise exception 'forbidden'; end if;
  return jsonb_build_object('code', g.code, 'name', g.name, 'owner', g.owner,
    'members', (select coalesce(jsonb_agg(jsonb_build_object('id', m.user_id, 'name', m.name, 'scores', m.scores, 'updated_at', m.updated_at) order by m.updated_at), '[]'::jsonb)
                from public.tw_group_member m where m.code = g.code));
end $$;

create or replace function public.tw_my_groups()
returns jsonb language sql security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('code', g.code, 'name', g.name) order by g.created_at), '[]'::jsonb)
  from public.tw_group g join public.tw_group_member m on m.code = g.code where m.user_id = auth.uid();
$$;

grant execute on function public.tw_group_create(text,text), public.tw_group_join(text,text), public.tw_group_leave(text),
  public.tw_group_score(text,text,jsonb), public.tw_group_board(text), public.tw_my_groups() to authenticated;
