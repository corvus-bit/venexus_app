-- Venexus - Supabase schema
-- Execute este arquivo no SQL Editor do Supabase depois de criar o projeto.
-- Não coloque service_role key, database password ou qualquer segredo no frontend/mobile.
-- O Venexus não usa Supabase Phone Auth/Twilio: a interface usa telefone, mas o Auth usa o e-mail real cadastrado + senha.

create extension if not exists pgcrypto;

create or replace function public.venexus_role_from_email(email text)
returns text
language sql
immutable
as $$
  select case
    when lower(coalesce(email, '')) like '%@sistemafiep.org.br' then 'admin'
    else 'reader'
  end;
$$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null,
  phone text not null unique,
  email text not null unique,
  address text not null,
  role text not null default 'reader' check (role in ('admin', 'reader')),
  language text not null default 'pt-BR' check (language in ('pt-BR', 'es')),
  avatar_url text,
  lgpd_accepted_at timestamptz,
  lgpd_version text default 'VENEXUS-LGPD-1.0',
  password_updated_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null,
  author_id uuid not null references public.profiles(id) on delete cascade,
  author_name text not null,
  author_role text not null default 'reader' check (author_role in ('admin', 'reader')),
  images text[] not null default '{}',
  created_at timestamptz not null default now()
);

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  author_name text not null,
  author_role text not null default 'reader' check (author_role in ('admin', 'reader')),
  text text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.senai_courses (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text not null,
  institution_address text not null,
  created_by_id uuid references public.profiles(id) on delete set null,
  created_by_name text,
  created_at timestamptz not null default now()
);

create table if not exists public.cartilha_contents (
  id uuid primary key default gen_random_uuid(),
  type text not null check (type in ('rights', 'expressions')),
  title text not null,
  text_pt text not null,
  text_es text not null,
  explanation text not null,
  created_by_id uuid references public.profiles(id) on delete set null,
  created_by_name text,
  created_at timestamptz not null default now()
);

create table if not exists public.notification_reads (
  user_id uuid not null references public.profiles(id) on delete cascade,
  notification_id text not null,
  read_at timestamptz not null default now(),
  primary key (user_id, notification_id)
);

create index if not exists posts_created_at_idx on public.posts(created_at desc);
create index if not exists comments_post_id_created_at_idx on public.comments(post_id, created_at asc);
create index if not exists senai_courses_created_at_idx on public.senai_courses(created_at desc);
create index if not exists cartilha_contents_created_at_idx on public.cartilha_contents(created_at desc);

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_touch_updated_at on public.profiles;
create trigger profiles_touch_updated_at
before update on public.profiles
for each row execute function public.touch_updated_at();

create or replace function public.normalize_profile_role()
returns trigger
language plpgsql
as $$
begin
  new.email = lower(trim(new.email));
  new.role = public.venexus_role_from_email(new.email);
  return new;
end;
$$;

drop trigger if exists profiles_normalize_role on public.profiles;
create trigger profiles_normalize_role
before insert or update of email on public.profiles
for each row execute function public.normalize_profile_role();

create or replace function public.handle_new_venexus_user()
returns trigger
security definer
set search_path = public
language plpgsql
as $$
begin
  insert into public.profiles (
    id,
    name,
    phone,
    email,
    address,
    role,
    language,
    lgpd_accepted_at,
    lgpd_version,
    password_updated_at
  ) values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', 'Usuário Venexus'),
    coalesce(new.raw_user_meta_data->>'phone', new.phone, ''),
    lower(coalesce(new.raw_user_meta_data->>'email', new.email, '')),
    coalesce(new.raw_user_meta_data->>'address', ''),
    public.venexus_role_from_email(coalesce(new.raw_user_meta_data->>'email', new.email, '')),
    coalesce(new.raw_user_meta_data->>'language', 'pt-BR'),
    nullif(new.raw_user_meta_data->>'lgpd_accepted_at', '')::timestamptz,
    coalesce(new.raw_user_meta_data->>'lgpd_version', 'VENEXUS-LGPD-1.0'),
    now()
  )
  on conflict (id) do update set
    name = excluded.name,
    phone = excluded.phone,
    email = excluded.email,
    address = excluded.address,
    role = excluded.role,
    language = excluded.language,
    lgpd_accepted_at = excluded.lgpd_accepted_at,
    lgpd_version = excluded.lgpd_version,
    updated_at = now();

  return new;
end;
$$;

drop trigger if exists on_auth_user_created_venexus_profile on auth.users;
create trigger on_auth_user_created_venexus_profile
after insert on auth.users
for each row execute function public.handle_new_venexus_user();

create or replace function public.find_profile_by_phone(profile_phone text)
returns table (
  id uuid,
  name text,
  phone text,
  email text,
  address text,
  role text,
  language text,
  avatar_url text,
  lgpd_accepted_at timestamptz,
  lgpd_version text,
  password_updated_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz
)
security definer
set search_path = public
language sql
stable
as $$
  select p.id, p.name, p.phone, p.email, p.address, p.role, p.language, p.avatar_url,
         p.lgpd_accepted_at, p.lgpd_version, p.password_updated_at, p.created_at, p.updated_at
  from public.profiles p
  where regexp_replace(p.phone, '[^0-9]', '', 'g') = regexp_replace(coalesce(profile_phone, ''), '[^0-9]', '', 'g')
  limit 1;
$$;

create or replace function public.find_profile_by_email(profile_email text)
returns table (
  id uuid,
  name text,
  phone text,
  email text,
  address text,
  role text,
  language text,
  avatar_url text,
  lgpd_accepted_at timestamptz,
  lgpd_version text,
  password_updated_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz
)
security definer
set search_path = public
language sql
stable
as $$
  select p.id, p.name, p.phone, p.email, p.address, p.role, p.language, p.avatar_url,
         p.lgpd_accepted_at, p.lgpd_version, p.password_updated_at, p.created_at, p.updated_at
  from public.profiles p
  where p.email = lower(trim(coalesce(profile_email, '')))
  limit 1;
$$;

alter table public.profiles enable row level security;
alter table public.posts enable row level security;
alter table public.comments enable row level security;
alter table public.senai_courses enable row level security;
alter table public.cartilha_contents enable row level security;
alter table public.notification_reads enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own" on public.profiles
for select to authenticated
using (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
for update to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles
for insert to authenticated
with check (auth.uid() = id);

drop policy if exists "posts_select_authenticated" on public.posts;
create policy "posts_select_authenticated" on public.posts
for select to authenticated
using (true);

drop policy if exists "posts_insert_admin" on public.posts;
drop policy if exists "posts_insert_authenticated" on public.posts;
create policy "posts_insert_authenticated" on public.posts
for insert to authenticated
with check (author_id = auth.uid());

drop policy if exists "comments_select_authenticated" on public.comments;
create policy "comments_select_authenticated" on public.comments
for select to authenticated
using (true);

drop policy if exists "comments_insert_authenticated" on public.comments;
create policy "comments_insert_authenticated" on public.comments
for insert to authenticated
with check (author_id = auth.uid());

drop policy if exists "senai_courses_select_authenticated" on public.senai_courses;
create policy "senai_courses_select_authenticated" on public.senai_courses
for select to authenticated
using (true);

drop policy if exists "senai_courses_insert_admin" on public.senai_courses;
create policy "senai_courses_insert_admin" on public.senai_courses
for insert to authenticated
with check (public.venexus_role_from_email((select email from public.profiles where id = auth.uid())) = 'admin' and created_by_id = auth.uid());

drop policy if exists "cartilha_contents_select_authenticated" on public.cartilha_contents;
create policy "cartilha_contents_select_authenticated" on public.cartilha_contents
for select to authenticated
using (true);

drop policy if exists "cartilha_contents_insert_admin" on public.cartilha_contents;
create policy "cartilha_contents_insert_admin" on public.cartilha_contents
for insert to authenticated
with check (public.venexus_role_from_email((select email from public.profiles where id = auth.uid())) = 'admin' and created_by_id = auth.uid());

drop policy if exists "notification_reads_select_own" on public.notification_reads;
create policy "notification_reads_select_own" on public.notification_reads
for select to authenticated
using (user_id = auth.uid());

drop policy if exists "notification_reads_insert_own" on public.notification_reads;
create policy "notification_reads_insert_own" on public.notification_reads
for insert to authenticated
with check (user_id = auth.uid());

drop policy if exists "notification_reads_delete_own" on public.notification_reads;
create policy "notification_reads_delete_own" on public.notification_reads
for delete to authenticated
using (user_id = auth.uid());

-- Realtime. No Dashboard, confirme também Database > Replication/Reatime se necessário.
do $$
begin
  alter publication supabase_realtime add table public.posts;
exception when duplicate_object then null;
end $$;
do $$
begin
  alter publication supabase_realtime add table public.comments;
exception when duplicate_object then null;
end $$;
do $$
begin
  alter publication supabase_realtime add table public.senai_courses;
exception when duplicate_object then null;
end $$;
do $$
begin
  alter publication supabase_realtime add table public.cartilha_contents;
exception when duplicate_object then null;
end $$;

-- Dados iniciais públicos para novos projetos.
insert into public.senai_courses (id, name, description, institution_address, created_by_name)
values
  ('00000000-0000-0000-0000-000000000101', 'Operador de Empilhadeira', 'Capacitação para operação segura e eficiente de empilhadeiras, seguindo as normas de segurança do trabalho.', 'Rua Xingu, 833 - Amadori, Pato Branco - PR', 'Equipe SENAI'),
  ('00000000-0000-0000-0000-000000000102', 'Auxiliar de Linha de Produção', 'Noções básicas sobre o funcionamento e organização do setor produtivo industrial.', 'Rua Xingu, 833 - Amadori, Pato Branco - PR', 'Equipe SENAI'),
  ('00000000-0000-0000-0000-000000000103', 'Segurança no Trabalho (NR-12 Básica)', 'Orientação importante sobre segurança no manuseio de máquinas e equipamentos industriais.', 'Rua Xingu, 833 - Amadori, Pato Branco - PR', 'Equipe SENAI')
on conflict (id) do nothing;

insert into public.cartilha_contents (id, type, title, text_pt, text_es, explanation, created_by_name)
values
  ('00000000-0000-0000-0000-000000000201', 'rights', 'Jornada de Trabalho e Horas Extras', 'No Brasil, a jornada de trabalho normal é de 8 horas diárias e 44 horas semanais. Horas trabalhadas além desse limite devem ser pagas com acréscimo de no mínimo 50%.', 'En Brasil, la jornada laboral normal es de 8 horas diarias y 44 horas semanales. Las horas trabajadas más allá de este límite deben pagarse con un recargo de al menos el 50%.', 'Saber seus horários evita o trabalho excessivo não remunerado.', 'Equipe SENAI'),
  ('00000000-0000-0000-0000-000000000202', 'rights', 'Equipamento de Proteção Individual (EPI)', 'O empregador é obrigado a fornecer gratuitamente equipamentos de proteção como botas, luvas e capacetes adequados ao risco da função. É obrigação do funcionário utilizá-los e zelar por eles.', 'El empleador está obligado a proporcionar gratuitamente equipos de protección como botas, guantes y cascos adecuados al riesgo de la función. Es obligación del empleado usarlos y cuidarlos.', 'Sua segurança é o mais importante e é garantida por lei.', 'Equipe SENAI'),
  ('00000000-0000-0000-0000-000000000203', 'rights', 'Férias Remuneradas', 'Após 12 meses de trabalho, o trabalhador tem direito a 30 dias de férias remuneradas, com acréscimo de um terço (1/3) do salário normal.', 'Después de 12 meses de trabajo, el trabajador tiene derecho a 30 días de vacaciones remuneradas, con un recargo de un tercio (1/3) del salario normal.', 'O descanso é essencial e pago, ajudando na recuperação física e mental.', 'Equipe SENAI'),
  ('00000000-0000-0000-0000-000000000204', 'expressions', 'Bater o ponto', 'Expressão utilizada para registrar o horário de chegada e saída do trabalho eletronicamente ou no relógio de ponto.', 'Expresión utilizada para registrar electrónicamente o en el reloj de fichar la hora de llegada y salida del trabajo.', 'É importante não esquecer para garantir o pagamento das suas horas.', null),
  ('00000000-0000-0000-0000-000000000205', 'expressions', 'Contra-cheque ou Holerite', 'Documento mensal recebido do empregador que detalha o seu salário, bônus, além dos descontos permitidos em lei.', 'Documento mensual recibido del empleador que detalla su salario, bonos, además de los descuentos permitidos por la ley (recibo de sueldo).', 'Sempre confira os valores do seu contra-cheque e guarde-o com você.', null)
on conflict (id) do nothing;
