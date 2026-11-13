-- Cada participante pode alterar apenas o texto das próprias mensagens no Venexus.
-- O grant por coluna impede a troca de autor, papel, data, vínculo da resposta e imagens.
grant update (title, body) on public.posts to authenticated;
grant update (text) on public.comments to authenticated;

drop policy if exists "posts_update_own" on public.posts;
create policy "posts_update_own" on public.posts
for update to authenticated
using (author_id = (select auth.uid()) and (select public.has_app_access('venexus')))
with check (author_id = (select auth.uid()) and (select public.has_app_access('venexus')));

drop policy if exists "comments_update_own" on public.comments;
create policy "comments_update_own" on public.comments
for update to authenticated
using (author_id = (select auth.uid()) and (select public.has_app_access('venexus')))
with check (author_id = (select auth.uid()) and (select public.has_app_access('venexus')));
