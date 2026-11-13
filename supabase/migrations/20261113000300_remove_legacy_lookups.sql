-- Plataforma compartilhada — etapa 3/3: remoção dos caminhos antigos.
--
-- APLIQUE SÓ DEPOIS de publicar a Edge Function phone-auth e a versão do app que a usa.
-- A partir daqui, APKs anteriores deixam de conseguir entrar (eles dependem das RPCs abaixo).

-- Devolvia o e-mail de qualquer telefone para quem tivesse a chave pública.
drop function if exists public.login_email_for_phone(text);
-- Respondiam "esta conta existe?" para qualquer pessoa.
drop function if exists public.phone_in_use(text);
drop function if exists public.email_in_use(text);

-- profiles.role era recalculado do domínio do e-mail a cada gravação. O papel agora vive em
-- platform.app_memberships (por aplicativo); manter uma cópia aqui só criaria uma segunda verdade.
drop trigger if exists profiles_normalize_role on public.profiles;
drop function if exists public.normalize_profile_role();
alter table public.profiles drop column if exists role;

-- A regra do domínio continua valendo só dentro do Venexus (platform.venexus_is_staff).
drop function if exists public.venexus_role_from_email(text);

-- Atualiza o cache de schema da API (PostgREST).
notify pgrst, 'reload schema';
