-- 002: 프로필(내 이름) 변경 기능
-- Supabase SQL Editor에 붙여넣고 Run 하세요. 여러 번 실행해도 괜찮아요.
create or replace function public.update_my_name(p_household uuid, p_name text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception '로그인이 필요해요'; end if;
  if coalesce(trim(p_name), '') = '' then raise exception '이름을 입력하세요'; end if;
  update members set display_name = left(trim(p_name), 20)
   where household_id = p_household and user_id = auth.uid();
  if not found then raise exception '가계부 구성원이 아니에요'; end if;
end $$;

revoke all on function public.update_my_name(uuid, text) from public, anon;
grant execute on function public.update_my_name(uuid, text) to authenticated;
