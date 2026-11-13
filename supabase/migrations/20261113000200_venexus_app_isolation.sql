-- Plataforma compartilhada — etapa 2/3: isolamento dos dados do Venexus.
--
-- Com o Auth compartilhado, `to authenticated using (true)` passaria a incluir quem se cadastrou
-- por outros aplicativos. A partir daqui o conteúdo do Venexus exige vínculo ATIVO no aplicativo
-- 'venexus' (platform.app_memberships), consultado a cada operação.
--
-- Pode ser aplicada antes de atualizar o app: todos os perfis existentes já têm vínculo (etapa 1)
-- e os cadastros feitos pelo APK antigo também recebem o deles.
--
-- Classificação dos dados:
--   privado do próprio usuário ........ profiles, notification_reads
--   exige participação no Venexus ..... posts, comments, senai_courses, cartilha_contents (leitura)
--                                       posts, comments (publicar e apagar o que é seu)
--   exige papel 'admin' no Venexus .... senai_courses, cartilha_contents (publicar e apagar),
--                                       posts, comments (apagar o de outra pessoa)
--   qualquer autenticado da plataforma  nada do Venexus

-- ---------------------------------------------------------------------------
-- Funções
-- ---------------------------------------------------------------------------

-- Admin LOCAL do Venexus. Não é administração da plataforma (ver public.is_platform_admin).
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.has_app_access('venexus', array['admin']);
$$;

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- Gravação sem usuário (auth.uid() nulo) só é legítima fora da API de dados: SQL Editor,
-- migrations ou service_role. Uma requisição anon/authenticated sem usuário nunca é autorização.
create or replace function platform.is_privileged_session()
returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce(current_setting('role', true), '') not in ('anon', 'authenticated')
     and coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role', '') not in ('anon', 'authenticated');
$$;

-- Nome e papel do autor vêm do banco, não do cliente. SECURITY DEFINER porque o papel é lido
-- de platform.app_memberships, que os papéis da API não acessam.
create or replace function public.set_post_author()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_name text;
begin
  if v_user is null then
    if not platform.is_privileged_session() then
      raise exception 'Autenticação necessária.' using errcode = '42501';
    end if;
    return new;
  end if;

  select p.name into v_name from public.profiles p where p.id = v_user;
  if not found then
    raise exception 'Perfil não encontrado.';
  end if;
  new.author_id = v_user;
  new.author_name = v_name;
  new.author_role = case when public.has_app_access('venexus', array['admin']) then 'admin' else 'reader' end;
  return new;
end;
$$;

create or replace function public.set_comment_author()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_name text;
  v_parent_post uuid;
begin
  if v_user is null then
    if not platform.is_privileged_session() then
      raise exception 'Autenticação necessária.' using errcode = '42501';
    end if;
    return new;
  end if;

  select p.name into v_name from public.profiles p where p.id = v_user;
  if not found then
    raise exception 'Perfil não encontrado.';
  end if;
  new.author_id = v_user;
  new.author_name = v_name;
  new.author_role = case when public.has_app_access('venexus', array['admin']) then 'admin' else 'reader' end;

  if new.parent_id is not null then
    select c.post_id into v_parent_post from public.comments c where c.id = new.parent_id;
    if not found or v_parent_post <> new.post_id then
      raise exception 'Comentário respondido não pertence a esta publicação.';
    end if;
  end if;

  if new.reply_to_author_id is null then
    new.reply_to_name = null;
  else
    -- Só dá para responder a quem comentou nesta publicação: reply_to_author_id não serve
    -- para descobrir o nome de um usuário qualquer a partir do id.
    select c.author_name into new.reply_to_name
    from public.comments c
    where c.post_id = new.post_id and c.author_id = new.reply_to_author_id
    order by c.created_at desc
    limit 1;
    if not found then
      raise exception 'Comentário respondido não pertence a esta publicação.';
    end if;
  end if;
  return new;
end;
$$;

revoke all on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;
revoke all on function platform.is_privileged_session() from public, anon, authenticated, service_role;
-- Funções de trigger não são chamadas pela API.
revoke all on function public.touch_updated_at() from public, anon, authenticated, service_role;
revoke all on function public.set_post_author() from public, anon, authenticated, service_role;
revoke all on function public.set_comment_author() from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Privilégios nas tabelas: só o que o app usa
-- ---------------------------------------------------------------------------
-- O padrão do Supabase concede tudo (inclusive truncate) a anon/authenticated em public.

revoke all on public.profiles, public.posts, public.comments, public.senai_courses,
  public.cartilha_contents, public.notification_reads from anon, authenticated;

grant select on public.profiles to authenticated;
-- Só dados pessoais. E-mail, papel, vínculos e status não entram numa atualização de perfil.
grant update (name, phone, address, language, avatar_url, lgpd_accepted_at, lgpd_version, password_updated_at)
  on public.profiles to authenticated;
grant select, insert, delete on public.posts, public.comments, public.senai_courses,
  public.cartilha_contents, public.notification_reads to authenticated;

-- Objetos futuros em public deixam de nascer abertos: cada tabela/função nova precisa de
-- grant explícito (e de RLS). Vale para objetos criados pelo papel que roda esta migration.
alter default privileges in schema public revoke all on tables from anon, authenticated;
alter default privileges in schema public revoke all on sequences from anon, authenticated;
alter default privileges in schema public revoke all on functions from anon, authenticated;
alter default privileges revoke execute on functions from public;

-- ---------------------------------------------------------------------------
-- Policies
-- ---------------------------------------------------------------------------
-- (select ...) em volta das funções: o Postgres avalia uma vez por comando, não por linha.

-- profiles: só o próprio perfil (sem mudança). Telefone, endereço e e-mail não são legíveis
-- por outros usuários; o nome público vai copiado em author_name.

drop policy if exists "posts_select_authenticated" on public.posts;
drop policy if exists "posts_select_member" on public.posts;
create policy "posts_select_member" on public.posts
for select to authenticated
using ((select public.has_app_access('venexus')));

drop policy if exists "posts_insert_authenticated" on public.posts;
drop policy if exists "posts_insert_member" on public.posts;
create policy "posts_insert_member" on public.posts
for insert to authenticated
with check (author_id = (select auth.uid()) and (select public.has_app_access('venexus')));

drop policy if exists "posts_delete_own_or_admin" on public.posts;
create policy "posts_delete_own_or_admin" on public.posts
for delete to authenticated
using (
  (select public.has_app_access('venexus'))
  and (author_id = (select auth.uid()) or (select public.is_admin()))
);

drop policy if exists "comments_select_authenticated" on public.comments;
drop policy if exists "comments_select_member" on public.comments;
create policy "comments_select_member" on public.comments
for select to authenticated
using ((select public.has_app_access('venexus')));

drop policy if exists "comments_insert_authenticated" on public.comments;
drop policy if exists "comments_insert_member" on public.comments;
create policy "comments_insert_member" on public.comments
for insert to authenticated
with check (author_id = (select auth.uid()) and (select public.has_app_access('venexus')));

drop policy if exists "comments_delete_own_or_admin" on public.comments;
create policy "comments_delete_own_or_admin" on public.comments
for delete to authenticated
using (
  (select public.has_app_access('venexus'))
  and (author_id = (select auth.uid()) or (select public.is_admin()))
);

drop policy if exists "senai_courses_select_authenticated" on public.senai_courses;
drop policy if exists "senai_courses_select_member" on public.senai_courses;
create policy "senai_courses_select_member" on public.senai_courses
for select to authenticated
using ((select public.has_app_access('venexus')));

drop policy if exists "senai_courses_insert_admin" on public.senai_courses;
create policy "senai_courses_insert_admin" on public.senai_courses
for insert to authenticated
with check ((select public.is_admin()) and created_by_id = (select auth.uid()));

drop policy if exists "senai_courses_delete_admin" on public.senai_courses;
create policy "senai_courses_delete_admin" on public.senai_courses
for delete to authenticated
using ((select public.is_admin()));

drop policy if exists "cartilha_contents_select_authenticated" on public.cartilha_contents;
drop policy if exists "cartilha_contents_select_member" on public.cartilha_contents;
create policy "cartilha_contents_select_member" on public.cartilha_contents
for select to authenticated
using ((select public.has_app_access('venexus')));

drop policy if exists "cartilha_contents_insert_admin" on public.cartilha_contents;
create policy "cartilha_contents_insert_admin" on public.cartilha_contents
for insert to authenticated
with check ((select public.is_admin()) and created_by_id = (select auth.uid()));

drop policy if exists "cartilha_contents_delete_admin" on public.cartilha_contents;
create policy "cartilha_contents_delete_admin" on public.cartilha_contents
for delete to authenticated
using ((select public.is_admin()));

drop policy if exists "notification_reads_select_own" on public.notification_reads;
create policy "notification_reads_select_own" on public.notification_reads
for select to authenticated
using (user_id = (select auth.uid()) and (select public.has_app_access('venexus')));

drop policy if exists "notification_reads_insert_own" on public.notification_reads;
create policy "notification_reads_insert_own" on public.notification_reads
for insert to authenticated
with check (user_id = (select auth.uid()) and (select public.has_app_access('venexus')));

drop policy if exists "notification_reads_delete_own" on public.notification_reads;
create policy "notification_reads_delete_own" on public.notification_reads
for delete to authenticated
using (user_id = (select auth.uid()) and (select public.has_app_access('venexus')));

-- Atualiza o cache de schema da API (PostgREST).
notify pgrst, 'reload schema';
