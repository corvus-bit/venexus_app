-- Local de origem é opcional para contas antigas e visível apenas a membros ativos do Venexus.
-- Não inferir a origem a partir do endereço residencial.
alter table public.profiles
  add column origin_country text,
  add column origin_region text;

alter table public.profiles
  add constraint profiles_origin_country_length check (origin_country is null or char_length(btrim(origin_country)) between 1 and 80),
  add constraint profiles_origin_region_length check (origin_region is null or char_length(btrim(origin_region)) between 1 and 120);

comment on column public.profiles.origin_country is 'País de origem informado pela pessoa; visível a membros ativos do Venexus.';
comment on column public.profiles.origin_region is 'Estado ou província de origem informado pela pessoa; visível a membros ativos do Venexus.';

-- O Auth cria o perfil antes de haver sessão no cliente. Copiamos os campos do cadastro
-- para o perfil na mesma transação, apenas quando o cadastro veio do Venexus.
create or replace function public.set_signup_origin()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_meta jsonb;
begin
  select u.raw_user_meta_data into v_meta from auth.users u where u.id = new.id;
  if platform.meta_text(v_meta, 'signup_app', 40) = 'venexus' then
    new.origin_country := platform.meta_text(v_meta, 'origin_country', 80);
    new.origin_region := platform.meta_text(v_meta, 'origin_region', 120);
  end if;
  return new;
end;
$$;

create trigger profiles_set_signup_origin
before insert on public.profiles
for each row execute function public.set_signup_origin();

revoke all on function public.set_signup_origin() from public, anon, authenticated, service_role;
grant update (origin_country, origin_region) on public.profiles to authenticated;

-- Perfis completos continuam privados por RLS. Esta RPC expõe só campos escolhidos
-- e exige vínculo ativo dos dois lados. Um UUID arbitrário não dá acesso a outra conta.
create or replace function public.get_public_profile(p_user uuid)
returns table (id uuid, name text, avatar_url text, origin_country text, origin_region text)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, p.name, p.avatar_url, p.origin_country, p.origin_region
  from public.profiles p
  join platform.app_memberships m
    on m.user_id = p.id and m.app_slug = 'venexus' and m.status = 'active'
  where p.id = p_user
    and (select public.has_app_access('venexus'));
$$;

revoke all on function public.get_public_profile(uuid) from public, anon, authenticated, service_role;
grant execute on function public.get_public_profile(uuid) to authenticated;

notify pgrst, 'reload schema';
