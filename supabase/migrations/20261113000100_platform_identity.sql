-- Plataforma compartilhada — etapa 1/3: identidade única + acesso por aplicativo.
--
-- Esta migration só ACRESCENTA: o APK antigo do Venexus continua funcionando depois dela.
-- Execute o arquivo inteiro de uma vez (SQL Editor ou `supabase db push`).
--
-- Modelo:
--   auth.users            identidade canônica (uma por pessoa, para todos os aplicativos)
--   public.profiles       perfil compartilhado mínimo (+ colunas legadas do Venexus)
--   platform.apps         aplicativos da plataforma (≠ projeto Supabase: há um projeto só)
--   platform.app_roles    papéis válidos em cada aplicativo
--   platform.app_memberships  vínculo usuário × aplicativo, com papel e status
--   platform.platform_admins  administração global, separada dos papéis locais
--
-- O schema `platform` é interno: não deve entrar em "Exposed schemas" da API e nenhum papel
-- da API tem acesso direto a ele. O acesso passa pelas funções public.* definidas abaixo.

create schema if not exists platform;
revoke all on schema platform from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Tabelas
-- ---------------------------------------------------------------------------

create table if not exists platform.apps (
  slug text primary key check (slug ~ '^[a-z][a-z0-9_]{1,39}$'),
  name text not null,
  -- Política de entrada, sempre explícita:
  --   open     qualquer identidade autenticada entra sozinha, com default_role
  --   approval a pessoa pede (vínculo 'pending') e alguém com permissão ativa
  --   invite   só entra quem recebe o vínculo de quem administra
  join_policy text not null check (join_policy in ('open', 'invite', 'approval')),
  -- Papel de quem entra sozinho. Nunca deve ser um papel administrativo.
  default_role text not null,
  -- Registro das URLs de retorno do aplicativo. Quem FAZ VALER a lista é o Auth
  -- (Authentication > URL Configuration > Redirect URLs); mantenha os dois iguais.
  allowed_redirect_urls text[] not null default '{}',
  created_at timestamptz not null default now()
);

create table if not exists platform.app_roles (
  app_slug text not null references platform.apps(slug) on delete cascade,
  role text not null check (role ~ '^[a-z][a-z0-9_]{1,39}$'),
  -- Quem tem este papel pode administrar vínculos NÃO administrativos do próprio aplicativo.
  can_manage_members boolean not null default false,
  primary key (app_slug, role)
);

create table if not exists platform.app_memberships (
  app_slug text not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null,
  status text not null default 'active' check (status in ('pending', 'active', 'revoked')),
  granted_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (app_slug, user_id),
  foreign key (app_slug, role) references platform.app_roles(app_slug, role)
);

create index if not exists app_memberships_user_id_idx on platform.app_memberships(user_id);

create table if not exists platform.platform_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  granted_at timestamptz not null default now()
);

-- Contadores do controle de abuso do login por telefone. Ficam no banco porque a Edge Function
-- roda em várias instâncias: contador em memória não vale entre elas.
create table if not exists platform.rate_limits (
  bucket text primary key,
  window_start timestamptz not null,
  hits integer not null
);

-- RLS ligado e nenhuma policy: mesmo que alguém conceda acesso por engano, nada é lido.
alter table platform.apps enable row level security;
alter table platform.app_roles enable row level security;
alter table platform.app_memberships enable row level security;
alter table platform.platform_admins enable row level security;
alter table platform.rate_limits enable row level security;
revoke all on all tables in schema platform from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Perfil compartilhado
-- ---------------------------------------------------------------------------
-- Comuns a todos os aplicativos: id, name, email, phone, language, avatar_url, timestamps.
-- Específicos do Venexus (ficam onde estão para não quebrar o app): address, lgpd_*.
-- Outros aplicativos não exigem telefone/endereço; por isso deixam de ser obrigatórios aqui.
-- A exigência continua no cadastro do Venexus (formulário do app).

alter table public.profiles alter column phone drop not null;
alter table public.profiles alter column email drop not null;
alter table public.profiles alter column address drop not null;
-- Sem este default, um cadastro feito por outro aplicativo não ganha "aceite" do Venexus.
alter table public.profiles alter column lgpd_version drop default;

comment on table public.profiles is 'Perfil compartilhado da plataforma (1:1 com auth.users). Papéis e vínculos NÃO ficam aqui: ver platform.app_memberships.';
comment on column public.profiles.address is 'Específico do Venexus.';
comment on column public.profiles.lgpd_accepted_at is 'Aceite do termo do Venexus. Não vale como aceite de outros aplicativos.';
comment on column public.profiles.lgpd_version is 'Versão do termo do Venexus aceito. Não vale como aceite de outros aplicativos.';

-- Telefone ausente passa a ser NULL (o unique aceita vários NULL; várias strings vazias, não).
update public.profiles set phone = null where btrim(phone) = '';

-- Guarda só os dígitos, quando isso não colide com outro perfil.
update public.profiles p
set phone = regexp_replace(p.phone, '[^0-9]', '', 'g')
where p.phone ~ '[^0-9]'
  and regexp_replace(p.phone, '[^0-9]', '', 'g') <> ''
  and not exists (
    select 1 from public.profiles o
    where o.id <> p.id
      and regexp_replace(o.phone, '[^0-9]', '', 'g') = regexp_replace(p.phone, '[^0-9]', '', 'g')
  );

-- E-mail do perfil = e-mail do Auth. Em dois passos para não esbarrar no unique durante a troca.
update public.profiles p
set email = null
from auth.users u
where u.id = p.id and p.email is distinct from lower(u.email);

update public.profiles p
set email = lower(u.email)
from auth.users u
where u.id = p.id and u.email is not null and p.email is null;

-- Normalização que vale para qualquer gravação no perfil.
create or replace function public.normalize_profile()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.email = nullif(lower(btrim(new.email)), '');
  new.phone = nullif(regexp_replace(coalesce(new.phone, ''), '[^0-9]', '', 'g'), '');
  -- Só valida quando o telefone muda: perfis antigos fora do padrão continuam editáveis.
  if new.phone is not null
     and (tg_op = 'INSERT' or new.phone is distinct from old.phone)
     and new.phone !~ '^[0-9]{8,15}$' then
    raise exception 'Telefone inválido.' using errcode = '23514';
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_normalize on public.profiles;
create trigger profiles_normalize
before insert or update on public.profiles
for each row execute function public.normalize_profile();

-- ---------------------------------------------------------------------------
-- Venexus como aplicativo da plataforma
-- ---------------------------------------------------------------------------

insert into platform.apps (slug, name, join_policy, default_role)
values ('venexus', 'Venexus', 'open', 'reader')
on conflict (slug) do nothing;

-- 'admin' do Venexus modera conteúdo (como hoje). Não administra vínculos nem a plataforma.
insert into platform.app_roles (app_slug, role, can_manage_members)
values ('venexus', 'reader', false), ('venexus', 'admin', false)
on conflict (app_slug, role) do nothing;

-- Regra do Venexus, preservada como regra LOCAL: e-mail do Auth confirmado no domínio
-- @sistemafiep.org.br => papel 'admin' no aplicativo venexus. Não concede nada fora dele.
create or replace function platform.venexus_is_staff(p_user uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (
    select 1
    from auth.users u
    where u.id = p_user
      and u.email_confirmed_at is not null
      and lower(u.email) like '%@sistemafiep.org.br'
  );
$$;

-- Quem entra no Venexus como 'reader' e é da equipe (regra acima) entra como 'admin'.
create or replace function platform.venexus_membership_role()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.role = 'reader' and platform.venexus_is_staff(new.user_id) then
    new.role = 'admin';
  end if;
  return new;
end;
$$;

drop trigger if exists app_memberships_venexus_role on platform.app_memberships;
create trigger app_memberships_venexus_role
before insert on platform.app_memberships
for each row when (new.app_slug = 'venexus')
execute function platform.venexus_membership_role();

drop trigger if exists app_memberships_touch_updated_at on platform.app_memberships;
create trigger app_memberships_touch_updated_at
before update on platform.app_memberships
for each row execute function public.touch_updated_at();

-- Todo perfil existente é um participante do Venexus: ninguém perde acesso na migração.
-- O papel sai da mesma regra que public.is_admin() usava (e-mail confirmado + domínio),
-- aplicada pelo trigger acima.
insert into platform.app_memberships (app_slug, user_id, role, status)
select 'venexus', p.id, 'reader', 'active'
from public.profiles p
on conflict (app_slug, user_id) do nothing;

-- ---------------------------------------------------------------------------
-- Cadastro: perfil mínimo criado na mesma transação do Auth
-- ---------------------------------------------------------------------------

-- Lê um texto de raw_user_meta_data. O metadata vem do cliente: qualquer coisa que não seja
-- um texto dentro do limite vira NULL, em vez de derrubar o cadastro.
create or replace function platform.meta_text(p_meta jsonb, p_key text, p_max_length integer)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when jsonb_typeof(p_meta) = 'object' and jsonb_typeof(p_meta -> p_key) = 'string'
      then nullif(btrim(left(p_meta ->> p_key, p_max_length)), '')
  end;
$$;

-- SECURITY DEFINER: quem insere em auth.users é o serviço de Auth, que não tem acesso a
-- public.profiles nem ao schema platform. Sem chamadas HTTP nem e-mails aqui dentro.
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  v_app text := platform.meta_text(meta, 'signup_app', 40);
  v_phone text := regexp_replace(coalesce(platform.meta_text(meta, 'phone', 40), new.phone, ''), '[^0-9]', '', 'g');
  v_language text := platform.meta_text(meta, 'language', 10);
  v_lgpd_version text := platform.meta_text(meta, 'lgpd_version', 40);
  v_address text;
  v_policy text;
  v_default_role text;
begin
  if v_phone !~ '^[0-9]{8,15}$' then
    v_phone := null;
  end if;
  if v_language is null or v_language not in ('pt-BR', 'es') then
    v_language := 'pt-BR';
  end if;
  if v_lgpd_version is not null and v_lgpd_version !~ '^VENEXUS-[A-Za-z0-9.-]{1,30}$' then
    v_lgpd_version := null;
  end if;

  -- Transição: APKs do Venexus anteriores a esta mudança não enviam signup_app,
  -- mas sempre enviam a versão do termo do Venexus.
  if v_app is null and v_lgpd_version is not null then
    v_app := 'venexus';
  end if;

  -- Endereço e aceite do termo só são gravados em cadastros feitos pelo Venexus.
  if v_app = 'venexus' then
    v_address := platform.meta_text(meta, 'address', 300);
  else
    v_lgpd_version := null;
  end if;

  -- Um perfil com e-mail desatualizado não pode bloquear o cadastro do dono verdadeiro do e-mail.
  update public.profiles set email = null where email = lower(new.email);

  begin
    insert into public.profiles (id, name, phone, email, address, language, lgpd_accepted_at, lgpd_version, password_updated_at)
    values (
      new.id,
      coalesce(platform.meta_text(meta, 'name', 120), 'Usuário'),
      v_phone,
      -- E-mail vem só do Auth, nunca do metadata.
      nullif(lower(new.email), ''),
      v_address,
      v_language,
      -- Data do servidor: a data enviada pelo cliente não é confiável.
      case when v_lgpd_version is not null then now() end,
      v_lgpd_version,
      now()
    )
    on conflict (id) do nothing;
  exception when unique_violation then
    -- Telefone já usado por outra conta: o cadastro falha de propósito (o telefone é o login do Venexus).
    raise exception 'phone_already_registered' using errcode = '23505';
  end;

  -- O cadastro NÃO dá acesso a todos os aplicativos. signup_app é só um pedido de entrada no
  -- aplicativo de origem, atendido conforme a política dele; o papel é sempre o default_role.
  if v_app is not null then
    select a.join_policy, a.default_role into v_policy, v_default_role
    from platform.apps a
    where a.slug = v_app;

    if v_policy in ('open', 'approval') then
      insert into platform.app_memberships (app_slug, user_id, role, status)
      values (v_app, new.id, v_default_role, case when v_policy = 'open' then 'active' else 'pending' end)
      on conflict (app_slug, user_id) do nothing;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created_venexus_profile on auth.users;
drop trigger if exists on_auth_user_created_profile on auth.users;
create trigger on_auth_user_created_profile
after insert on auth.users
for each row execute function public.handle_new_auth_user();

drop function if exists public.handle_new_venexus_user();

-- E-mail trocado/confirmado no Auth: o perfil acompanha e a regra de papel do Venexus é reaplicada.
create or replace function public.handle_auth_user_email_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.email is distinct from old.email then
    -- Um perfil com e-mail desatualizado não pode bloquear o e-mail verdadeiro de outra pessoa.
    update public.profiles set email = null
    where email = lower(new.email) and id <> new.id;
    update public.profiles set email = nullif(lower(new.email), '')
    where id = new.id;
  end if;

  if platform.venexus_is_staff(new.id) then
    update platform.app_memberships set role = 'admin'
    where app_slug = 'venexus' and user_id = new.id and role <> 'admin';
  elsif lower(coalesce(old.email, '')) like '%@sistemafiep.org.br' then
    -- Era da equipe pela regra do domínio e deixou de ser.
    update platform.app_memberships set role = 'reader'
    where app_slug = 'venexus' and user_id = new.id and role <> 'reader';
  end if;

  return new;
end;
$$;

drop trigger if exists on_auth_user_email_changed on auth.users;
create trigger on_auth_user_email_changed
after update of email, email_confirmed_at on auth.users
for each row execute function public.handle_auth_user_email_change();

-- ---------------------------------------------------------------------------
-- Autorização: helpers usados pelas policies e pelo frontend
-- ---------------------------------------------------------------------------
-- SECURITY DEFINER porque leem platform.*, que os papéis da API não acessam. Só respondem
-- sobre auth.uid(): não aceitam user_id do cliente. Consultam a tabela a cada chamada, então
-- uma revogação vale na hora, mesmo com um JWT antigo ainda válido. Como as tabelas de
-- platform não têm policies que chamem estas funções, não há recursão.

create or replace function public.has_app_access(p_app text, p_roles text[] default null)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from platform.app_memberships m
    where m.user_id = (select auth.uid())
      and m.app_slug = p_app
      and m.status = 'active'
      and (p_roles is null or m.role = any (p_roles))
  );
$$;

create or replace function public.is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from platform.platform_admins a where a.user_id = (select auth.uid())
  );
$$;

-- Vínculos do próprio usuário (para o frontend decidir o que exibir; a autoridade é o RLS).
create or replace function public.my_app_memberships()
returns table (app_slug text, app_name text, role text, status text)
language sql
stable
security definer
set search_path = ''
as $$
  select m.app_slug, a.name, m.role, m.status
  from platform.app_memberships m
  join platform.apps a on a.slug = m.app_slug
  where m.user_id = (select auth.uid());
$$;

-- Entrada por conta própria, conforme a política do aplicativo. Nunca reativa um vínculo
-- revogado e nunca concede outro papel além do default_role.
create or replace function public.join_app(p_app text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_policy text;
  v_default_role text;
  v_status text;
begin
  if v_user is null then
    raise exception 'Autenticação necessária.' using errcode = '42501';
  end if;

  select m.status into v_status
  from platform.app_memberships m
  where m.app_slug = p_app and m.user_id = v_user;
  if found then
    return v_status;
  end if;

  select a.join_policy, a.default_role into v_policy, v_default_role
  from platform.apps a
  where a.slug = p_app;
  if not found then
    raise exception 'Aplicativo não encontrado.' using errcode = 'P0002';
  end if;
  if v_policy = 'invite' then
    raise exception 'Este aplicativo só aceita participantes convidados.' using errcode = '42501';
  end if;

  v_status := case when v_policy = 'open' then 'active' else 'pending' end;
  insert into platform.app_memberships (app_slug, user_id, role, status)
  values (p_app, v_user, v_default_role, v_status)
  on conflict (app_slug, user_id) do nothing;
  return v_status;
end;
$$;

-- Gestão de vínculos (convite, aprovação, troca de papel, revogação) em uma única transação.
--   administrador global: qualquer vínculo de qualquer aplicativo;
--   papel local com can_manage_members: só no próprio aplicativo, só vínculos de papéis
--     sem can_manage_members, e nunca o próprio vínculo.
create or replace function public.set_app_membership(p_app text, p_user uuid, p_role text, p_status text default 'active')
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_caller uuid := auth.uid();
  v_new_role_manages boolean;
  v_current_role_manages boolean;
begin
  if v_caller is null then
    raise exception 'Autenticação necessária.' using errcode = '42501';
  end if;
  if p_status is null or p_status not in ('pending', 'active', 'revoked') then
    raise exception 'Status inválido.' using errcode = '22023';
  end if;

  select r.can_manage_members into v_new_role_manages
  from platform.app_roles r
  where r.app_slug = p_app and r.role = p_role;
  if not found then
    raise exception 'Aplicativo ou papel inválido.' using errcode = '22023';
  end if;

  if not exists (select 1 from platform.platform_admins a where a.user_id = v_caller) then
    if p_user = v_caller then
      raise exception 'Ninguém altera o próprio vínculo.' using errcode = '42501';
    end if;

    if not exists (
      select 1
      from platform.app_memberships m
      join platform.app_roles r on r.app_slug = m.app_slug and r.role = m.role
      where m.app_slug = p_app and m.user_id = v_caller and m.status = 'active' and r.can_manage_members
    ) then
      raise exception 'Sem permissão para administrar participantes deste aplicativo.' using errcode = '42501';
    end if;

    select r.can_manage_members into v_current_role_manages
    from platform.app_memberships m
    join platform.app_roles r on r.app_slug = m.app_slug and r.role = m.role
    where m.app_slug = p_app and m.user_id = p_user;

    if v_new_role_manages or coalesce(v_current_role_manages, false) then
      raise exception 'Papéis administrativos só são alterados pela administração da plataforma.' using errcode = '42501';
    end if;
  end if;

  if not exists (select 1 from auth.users u where u.id = p_user) then
    raise exception 'Usuário não encontrado.' using errcode = 'P0002';
  end if;

  insert into platform.app_memberships (app_slug, user_id, role, status, granted_by)
  values (p_app, p_user, p_role, p_status, v_caller)
  on conflict (app_slug, user_id) do update
    set role = excluded.role, status = excluded.status, granted_by = excluded.granted_by;
end;
$$;

-- Administração global: só pelo SQL Editor (dono do banco). Não há caminho pela API.
--   select platform.grant_platform_admin('pessoa@exemplo.com');
create or replace function platform.grant_platform_admin(p_email text)
returns uuid
language plpgsql
set search_path = ''
as $$
declare
  v_user uuid;
begin
  select u.id into v_user
  from auth.users u
  where lower(u.email) = lower(btrim(p_email)) and u.email_confirmed_at is not null;
  if not found then
    raise exception 'Nenhuma conta com e-mail confirmado: %', p_email;
  end if;
  insert into platform.platform_admins (user_id) values (v_user)
  on conflict (user_id) do nothing;
  return v_user;
end;
$$;

create or replace function platform.revoke_platform_admin(p_email text)
returns void
language sql
set search_path = ''
as $$
  delete from platform.platform_admins a
  using auth.users u
  where u.id = a.user_id and lower(u.email) = lower(btrim(p_email));
$$;

-- ---------------------------------------------------------------------------
-- Login por telefone: apoio à Edge Function phone-auth
-- ---------------------------------------------------------------------------

-- Conta uma tentativa e diz se ainda está dentro do limite. Atômico: o upsert trava a linha.
create or replace function platform.rate_limit_hit(p_bucket text, p_max integer, p_window interval)
returns boolean
language plpgsql
set search_path = ''
as $$
declare
  v_key text := encode(sha256(convert_to(p_bucket, 'UTF8')), 'hex');
  v_hits integer;
begin
  insert into platform.rate_limits as r (bucket, window_start, hits)
  values (v_key, now(), 1)
  on conflict (bucket) do update
    set hits = case when r.window_start < now() - p_window then 1 else r.hits + 1 end,
        window_start = case when r.window_start < now() - p_window then now() else r.window_start end
  returning r.hits into v_hits;

  if random() < 0.01 then
    delete from platform.rate_limits where window_start < now() - interval '1 day';
  end if;

  return v_hits <= p_max;
end;
$$;

-- Resolve o e-mail do Auth para um telefone, depois de aplicar os limites. Só a Edge Function
-- (service_role) executa: o e-mail nunca volta para anon/authenticated.
--
-- Limites pensados para muita gente atrás do mesmo IP (Wi-Fi da feira): o limite apertado é
-- por telefone + IP; o limite só por IP é largo.
create or replace function public.phone_auth_resolve(p_phone text, p_ip text, p_action text)
returns table (allowed boolean, email text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_phone text := regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g');
  v_ip text := nullif(btrim(left(coalesce(p_ip, ''), 64)), '');
  v_pair_max integer;
  v_phone_max integer;
  v_ip_max integer;
  v_ok boolean := true;
begin
  if v_phone !~ '^[0-9]{8,15}$' then
    return query select true, null::text;
    return;
  end if;

  case p_action
    when 'login' then v_pair_max := 10; v_phone_max := 40; v_ip_max := 300;
    when 'verify' then v_pair_max := 10; v_phone_max := 30; v_ip_max := 300;
    when 'recover' then v_pair_max := 5; v_phone_max := 10; v_ip_max := 100;
    else raise exception 'Ação inválida.' using errcode = '22023';
  end case;

  -- Todos os contadores avançam, mesmo quando um já estourou.
  v_ok := platform.rate_limit_hit(p_action || '|phone|' || v_phone, v_phone_max, interval '15 minutes') and v_ok;
  if v_ip is not null then
    v_ok := platform.rate_limit_hit(p_action || '|pair|' || v_phone || '|' || v_ip, v_pair_max, interval '15 minutes') and v_ok;
    v_ok := platform.rate_limit_hit(p_action || '|ip|' || v_ip, v_ip_max, interval '15 minutes') and v_ok;
  end if;

  if not v_ok then
    return query select false, null::text;
    return;
  end if;

  -- O e-mail vem do Auth (fonte da verdade), não da cópia no perfil.
  return query
    select true, (
      select u.email::text
      from public.profiles p
      join auth.users u on u.id = p.id
      where regexp_replace(p.phone, '[^0-9]', '', 'g') = v_phone
      limit 1
    );
end;
$$;

-- ---------------------------------------------------------------------------
-- Quem pode executar o quê
-- ---------------------------------------------------------------------------
-- No Supabase, funções novas em public nascem executáveis por anon/authenticated/service_role.
-- Por isso cada uma é revogada e concedida explicitamente.

revoke all on all functions in schema platform from public, anon, authenticated, service_role;

revoke all on function public.normalize_profile() from public, anon, authenticated, service_role;
revoke all on function public.handle_new_auth_user() from public, anon, authenticated, service_role;
revoke all on function public.handle_auth_user_email_change() from public, anon, authenticated, service_role;

revoke all on function public.has_app_access(text, text[]) from public, anon;
revoke all on function public.is_platform_admin() from public, anon;
revoke all on function public.my_app_memberships() from public, anon;
revoke all on function public.join_app(text) from public, anon;
revoke all on function public.set_app_membership(text, uuid, text, text) from public, anon;
grant execute on function public.has_app_access(text, text[]) to authenticated;
grant execute on function public.is_platform_admin() to authenticated;
grant execute on function public.my_app_memberships() to authenticated;
grant execute on function public.join_app(text) to authenticated;
grant execute on function public.set_app_membership(text, uuid, text, text) to authenticated;

revoke all on function public.phone_auth_resolve(text, text, text) from public, anon, authenticated;
grant execute on function public.phone_auth_resolve(text, text, text) to service_role;

-- Atualiza o cache de schema da API (PostgREST).
notify pgrst, 'reload schema';
