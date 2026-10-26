-- 우리집 가계부 — Supabase 스키마
-- Supabase 대시보드 → SQL Editor 에 통째로 붙여넣고 Run 하세요. (한 번만)

-- ───────── 테이블 ─────────
create table if not exists public.households (
  id          uuid primary key default gen_random_uuid(),
  name        text not null default '우리집',
  invite_code text not null unique default upper(substr(md5(random()::text), 1, 6)),
  created_at  timestamptz not null default now()
);

create table if not exists public.members (
  household_id uuid not null references public.households(id) on delete cascade,
  user_id      uuid not null references auth.users(id) on delete cascade,
  display_name text not null default '나',
  joined_at    timestamptz not null default now(),
  primary key (household_id, user_id)
);

create table if not exists public.categories (
  id           uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  name         text not null check (length(name) between 1 and 30),
  color        text not null default '#8E8C99',
  is_fixed     boolean not null default false,
  sort_order   int not null default 0,
  created_at   timestamptz not null default now()
);

create table if not exists public.entries (
  id           uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  category_id  uuid not null references public.categories(id) on delete cascade,
  month        text not null check (month ~ '^\d{4}-\d{2}$'),   -- 'YYYY-MM'
  amount       bigint not null check (amount >= 0),             -- 원 단위
  memo         text not null default '',
  spent_on     date,                                             -- 선택
  created_by   uuid references auth.users(id) default auth.uid(),
  created_at   timestamptz not null default now()
);

create index if not exists entries_household_month on public.entries (household_id, month);
create index if not exists categories_household on public.categories (household_id, sort_order);
create index if not exists members_user on public.members (user_id);

-- ───────── 권한 체크 함수 ─────────
create or replace function public.is_member(h uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.members where household_id = h and user_id = auth.uid());
$$;

-- ───────── RLS: 같은 가계부 구성원만 읽고 쓰기 ─────────
alter table public.households enable row level security;
alter table public.members    enable row level security;
alter table public.categories enable row level security;
alter table public.entries    enable row level security;

drop policy if exists hh_select on public.households;
drop policy if exists hh_update on public.households;
create policy hh_select on public.households for select using (public.is_member(id));
create policy hh_update on public.households for update using (public.is_member(id)) with check (public.is_member(id));

drop policy if exists mem_select on public.members;
create policy mem_select on public.members for select using (user_id = auth.uid() or public.is_member(household_id));

drop policy if exists cat_all on public.categories;
create policy cat_all on public.categories for all
  using (public.is_member(household_id)) with check (public.is_member(household_id));

drop policy if exists ent_all on public.entries;
create policy ent_all on public.entries for all
  using (public.is_member(household_id)) with check (public.is_member(household_id));

-- ───────── 가계부 만들기 / 초대코드로 참여 ─────────
create or replace function public.create_household(p_name text, p_display text)
returns uuid language plpgsql security definer set search_path = public as $$
declare h uuid;
begin
  if auth.uid() is null then raise exception '로그인이 필요해요'; end if;
  insert into households (name) values (coalesce(nullif(trim(p_name), ''), '우리집')) returning id into h;
  insert into members (household_id, user_id, display_name) values (h, auth.uid(), coalesce(nullif(trim(p_display), ''), '나'));
  insert into categories (household_id, name, color, is_fixed, sort_order) values
    (h, '고정지출',  '#3E63DD', true,  0),
    (h, '교통비',    '#12A594', false, 1),
    (h, '유류비',    '#F76B15', false, 2),
    (h, '식비',      '#E5484D', false, 3),
    (h, '기타 소비', '#8E8C99', false, 4);
  return h;
end $$;

create or replace function public.join_household(p_code text, p_display text)
returns uuid language plpgsql security definer set search_path = public as $$
declare h uuid;
begin
  if auth.uid() is null then raise exception '로그인이 필요해요'; end if;
  select id into h from households where invite_code = upper(trim(p_code));
  if h is null then raise exception '초대코드를 찾을 수 없어요'; end if;
  insert into members (household_id, user_id, display_name)
    values (h, auth.uid(), coalesce(nullif(trim(p_display), ''), '나'))
    on conflict (household_id, user_id) do nothing;
  return h;
end $$;

revoke all on function public.create_household(text, text) from public, anon;
revoke all on function public.join_household(text, text)   from public, anon;
grant execute on function public.create_household(text, text) to authenticated;
grant execute on function public.join_household(text, text)   to authenticated;

-- ───────── 실시간 동기화 (한 명이 입력하면 다른 폰에 바로 반영) ─────────
do $$ begin
  begin alter publication supabase_realtime add table public.entries;    exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.categories; exception when duplicate_object then null; end;
end $$;
