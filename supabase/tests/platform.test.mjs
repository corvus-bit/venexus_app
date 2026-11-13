// Testes das migrations em um Postgres real embutido (PGlite), sem Docker.
//
//   cd supabase/tests && npm install && npm test
//
// O que é simulado: o schema `auth` (auth.users, auth.uid()), os papéis da API e os privilégios
// padrão do Supabase. O que NÃO passa por aqui: o serviço de Auth, o PostgREST e a Edge Function.

import { readdirSync, readFileSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';
import { pgcrypto } from '@electric-sql/pglite/contrib/pgcrypto';

const migrationsDir = new URL('../migrations/', import.meta.url);
const migrations = readdirSync(migrationsDir).filter((name) => name.endsWith('.sql')).sort();
const [BASELINE, IDENTITY, ISOLATION, CLEANUP] = migrations;

const SUPABASE_STUB = `
  create role anon nologin;
  create role authenticated nologin;
  create role service_role nologin bypassrls;
  create role supabase_auth_admin nologin;

  create schema auth;
  create table auth.users (
    id uuid primary key default gen_random_uuid(),
    email text unique,
    phone text,
    raw_user_meta_data jsonb,
    email_confirmed_at timestamptz,
    created_at timestamptz not null default now()
  );
  create function auth.uid() returns uuid language sql stable as $$
    select nullif(nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub', '')::uuid
  $$;
  grant usage on schema auth to anon, authenticated, service_role, supabase_auth_admin;
  grant all on auth.users to supabase_auth_admin;

  grant usage on schema public to anon, authenticated, service_role;
  alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
  alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;
  alter default privileges in schema public grant all on functions to anon, authenticated, service_role;

  create publication supabase_realtime;
`;

let passed = 0;
const failures = [];

async function test(name, fn) {
  try {
    await fn();
    passed++;
    console.log(`  ok    ${name}`);
  } catch (error) {
    failures.push(name);
    console.log(`  FAIL  ${name}\n        ${error.message}`);
  }
}

function equal(actual, expected, label = 'valor') {
  const a = JSON.stringify(actual);
  const e = JSON.stringify(expected);
  if (a !== e) throw new Error(`${label}: esperado ${e}, veio ${a}`);
}

async function rejects(promise, pattern, label = 'operação') {
  try {
    await promise;
  } catch (error) {
    if (pattern && !pattern.test(error.message)) throw new Error(`${label}: erro inesperado: ${error.message}`);
    return;
  }
  throw new Error(`${label}: deveria ter sido recusada`);
}

async function createDatabase() {
  const db = await PGlite.create({ extensions: { pgcrypto } });
  await db.exec(SUPABASE_STUB);
  return db;
}

const migrate = (db, file) => db.exec(readFileSync(new URL(file, migrationsDir), 'utf8'));

/** Executa `fn` como uma requisição da API: papel + claims do JWT, em uma transação. */
async function request(db, role, userId, fn) {
  await db.exec('begin');
  try {
    const claims = JSON.stringify({ role, ...(userId ? { sub: userId } : {}) });
    await db.query(`select set_config('request.jwt.claims', $1, true)`, [claims]);
    await db.exec(`set local role ${role}`);
    const result = await fn((text, params) => db.query(text, params).then((r) => r.rows));
    await db.exec('commit');
    return result;
  } catch (error) {
    await db.exec('rollback');
    throw error;
  }
}

const asUser = (db, userId, fn) => request(db, 'authenticated', userId, fn);
const asAnon = (db, fn) => request(db, 'anon', null, fn);
const asService = (db, fn) => request(db, 'service_role', null, fn);
const rows = (db, text, params) => db.query(text, params).then((r) => r.rows);

/** Cadastro como o serviço de Auth faz: insert em auth.users pelo papel supabase_auth_admin. */
async function signUp(db, { email, meta, confirmed = true, rawMeta }) {
  await db.exec('begin');
  try {
    await db.exec('set local role supabase_auth_admin');
    const result = await db.query(
      `insert into auth.users (email, raw_user_meta_data, email_confirmed_at)
       values ($1, $2::jsonb, case when $3 then now() end) returning id`,
      [email, rawMeta ?? (meta === undefined ? null : JSON.stringify(meta)), confirmed],
    );
    await db.exec('commit');
    return result.rows[0].id;
  } catch (error) {
    await db.exec('rollback');
    throw error;
  }
}

const venexusMeta = (overrides = {}) => ({
  name: 'Pessoa',
  address: 'Pato Branco - PR',
  language: 'pt-BR',
  lgpd_accepted_at: '2026-01-01T12:00:00.000Z',
  lgpd_version: 'VENEXUS-LGPD-1.0',
  ...overrides,
});

const membership = (db, app, userId) =>
  rows(db, `select role, status from platform.app_memberships where app_slug = $1 and user_id = $2`, [app, userId]).then((r) => r[0] ?? null);

const profile = (db, userId) => rows(db, `select * from public.profiles where id = $1`, [userId]).then((r) => r[0] ?? null);

const insertPost = (q, authorId, extra = {}) =>
  q(
    `insert into public.posts (title, body, author_id, author_name, author_role)
     values ($1, 'Corpo', $2, $3, $4) returning id, author_id, author_name, author_role`,
    [extra.title ?? 'Título', authorId, extra.authorName ?? 'x', extra.authorRole ?? 'reader'],
  ).then((r) => r[0]);

// ---------------------------------------------------------------------------
// Cenário 1: banco existente do Venexus recebendo as migrations
// ---------------------------------------------------------------------------

async function upgradeScenario() {
  const db = await createDatabase();
  await migrate(db, BASELINE);

  console.log('\nEstado anterior (baseline)');
  const ana = await signUp(db, { email: 'ana@example.com', meta: venexusMeta({ name: 'Ana', phone: '46999990000' }) });
  const staff = await signUp(db, { email: 'equipe@sistemafiep.org.br', meta: venexusMeta({ name: 'Equipe', phone: '46999991111' }) });
  const staffUnconfirmed = await signUp(db, { email: 'novo@sistemafiep.org.br', confirmed: false, meta: venexusMeta({ name: 'Novo', phone: '46999992222' }) });
  const carla = await signUp(db, { email: 'carla@example.com', meta: venexusMeta({ name: 'Carla', phone: '46988887777' }) });
  const beto = await signUp(db, { email: 'beto@example.com', meta: { name: 'Beto' } });

  await test('baseline: o segundo cadastro sem telefone falha (defeito que a migração corrige)', async () => {
    await rejects(signUp(db, { email: 'semfone@example.com', meta: { name: 'Sem Fone' } }), /duplicate key/);
  });

  // Dados herdados fora do padrão: telefone com máscara e e-mail do perfil desatualizado.
  await db.exec(`update public.profiles set phone = '(46) 98888-7777' where id = '${carla}'`);
  await db.exec(`update auth.users set email = 'carla.nova@example.com' where id = '${carla}'`);

  const anaPost = await asUser(db, ana, (q) => insertPost(q, ana, { title: 'Post da Ana' }));
  const staffPost = await asUser(db, staff, (q) => insertPost(q, staff, { title: 'Aviso da equipe' }));
  const anaComment = await asUser(db, ana, (q) =>
    q(`insert into public.comments (post_id, author_id, author_name, text) values ($1, $2, 'x', 'Oi') returning id`, [staffPost.id, ana]),
  ).then((r) => r[0]);
  const contentBefore = await rows(db, `select id, author_id, author_name, author_role from public.posts order by id`);
  const commentsBefore = await rows(db, `select id, author_id, author_name, author_role from public.comments order by id`);

  // -------------------------------------------------------------------------
  console.log('\nEtapa 1 — identidade e vínculos (APK antigo ainda em uso)');
  await migrate(db, IDENTITY);

  await test('usuários antigos viram participantes do Venexus com o papel que já tinham', async () => {
    equal(await membership(db, 'venexus', ana), { role: 'reader', status: 'active' }, 'ana');
    equal(await membership(db, 'venexus', staff), { role: 'admin', status: 'active' }, 'equipe');
    equal(await membership(db, 'venexus', staffUnconfirmed), { role: 'reader', status: 'active' }, 'equipe sem e-mail confirmado');
    equal(await membership(db, 'venexus', beto), { role: 'reader', status: 'active' }, 'beto');
  });

  await test('ninguém vira administrador global na migração', async () => {
    equal(await rows(db, `select count(*)::int as n from platform.platform_admins`), [{ n: 0 }]);
  });

  await test('perfis antigos: telefone vazio vira NULL, máscara sai, e-mail acompanha o Auth', async () => {
    equal((await profile(db, beto)).phone, null, 'telefone do beto');
    equal((await profile(db, carla)).phone, '46988887777', 'telefone da carla');
    equal((await profile(db, carla)).email, 'carla.nova@example.com', 'e-mail da carla');
    equal((await profile(db, ana)).phone, '46999990000', 'telefone da ana');
  });

  await test('transição: as RPCs antigas continuam respondendo ao APK antigo', async () => {
    const result = await asAnon(db, (q) => q(`select public.login_email_for_phone('46999990000') as email`));
    equal(result, [{ email: 'ana@example.com' }]);
  });

  let legacySignup;
  await test('transição: cadastro pelo APK antigo (sem signup_app) recebe perfil e vínculo', async () => {
    legacySignup = await signUp(db, { email: 'dani@example.com', meta: venexusMeta({ name: 'Dani', phone: '(46) 97777-0000' }) });
    equal(await rows(db, `select count(*)::int as n from public.profiles where id = $1`, [legacySignup]), [{ n: 1 }], 'perfis');
    const saved = await profile(db, legacySignup);
    equal([saved.phone, saved.address, saved.lgpd_version], ['46977770000', 'Pato Branco - PR', 'VENEXUS-LGPD-1.0']);
    equal(await membership(db, 'venexus', legacySignup), { role: 'reader', status: 'active' });
  });

  let outsiderOne;
  let outsiderTwo;
  await test('duas pessoas se cadastram sem telefone (por outro aplicativo)', async () => {
    outsiderOne = await signUp(db, { email: 'fora1@example.com', meta: { name: 'Fora Um' } });
    outsiderTwo = await signUp(db, { email: 'fora2@example.com' });
    equal((await profile(db, outsiderOne)).phone, null);
    equal((await profile(db, outsiderTwo)).name, 'Usuário');
  });

  await test('cadastro por outro aplicativo não entra no Venexus nem aceita o termo do Venexus', async () => {
    equal(await membership(db, 'venexus', outsiderOne), null, 'vínculo');
    const saved = await profile(db, outsiderOne);
    equal([saved.lgpd_accepted_at, saved.lgpd_version, saved.address], [null, null, null]);
  });

  await test('metadata malformado não derruba o cadastro', async () => {
    const weird = await signUp(db, {
      email: 'estranho@example.com',
      meta: { name: { a: 1 }, phone: [1, 2], address: 5, language: 'xx', lgpd_accepted_at: 'ontem', lgpd_version: { v: 1 }, signup_app: 123 },
    });
    const saved = await profile(db, weird);
    equal([saved.name, saved.phone, saved.language, saved.lgpd_accepted_at], ['Usuário', null, 'pt-BR', null]);
    const scalar = await signUp(db, { email: 'escalar@example.com', rawMeta: '"texto"' });
    equal((await profile(db, scalar)).name, 'Usuário');
    const huge = await signUp(db, { email: 'grande@example.com', meta: { name: 'n'.repeat(5000), phone: '9'.repeat(400) } });
    equal([(await profile(db, huge)).name.length, (await profile(db, huge)).phone], [120, null]);
  });

  await test('metadata não concede papel: role/admin enviados pelo cliente são ignorados', async () => {
    const sneaky = await signUp(db, {
      email: 'esperto@example.com',
      meta: venexusMeta({ signup_app: 'venexus', role: 'admin', is_admin: true, phone: '46911110000' }),
    });
    equal(await membership(db, 'venexus', sneaky), { role: 'reader', status: 'active' });
  });

  await test('signup_app de aplicativo inexistente não cria vínculo', async () => {
    const lost = await signUp(db, { email: 'perdido@example.com', meta: { signup_app: 'nao_existe' } });
    equal(await rows(db, `select count(*)::int as n from platform.app_memberships where user_id = $1`, [lost]), [{ n: 0 }]);
  });

  await test('telefone já usado por outra conta recusa o cadastro', async () => {
    await rejects(signUp(db, { email: 'copia@example.com', meta: venexusMeta({ signup_app: 'venexus', phone: '(46) 99999-0000' }) }), /phone_already_registered/);
    equal(await rows(db, `select count(*)::int as n from auth.users where email = 'copia@example.com'`), [{ n: 0 }], 'conta criada');
  });

  let newStaff;
  await test('equipe (@sistemafiep.org.br) só vira admin do Venexus depois de confirmar o e-mail', async () => {
    newStaff = await signUp(db, { email: 'prof@sistemafiep.org.br', confirmed: false, meta: venexusMeta({ signup_app: 'venexus', phone: '46922220000' }) });
    equal((await membership(db, 'venexus', newStaff)).role, 'reader', 'antes de confirmar');
    await db.exec(`update auth.users set email_confirmed_at = now() where id = '${newStaff}'`);
    equal((await membership(db, 'venexus', newStaff)).role, 'admin', 'depois de confirmar');
    equal(await rows(db, `select count(*)::int as n from platform.platform_admins`), [{ n: 0 }], 'admins globais');
  });

  await test('troca de e-mail confirmada no Auth: perfil acompanha e o papel é reavaliado', async () => {
    await db.exec(`update auth.users set email = 'Prof.Pessoal@Example.com' where id = '${newStaff}'`);
    equal((await profile(db, newStaff)).email, 'prof.pessoal@example.com', 'e-mail do perfil');
    equal((await membership(db, 'venexus', newStaff)).role, 'reader', 'papel');
  });

  // -------------------------------------------------------------------------
  console.log('\nEtapa 2 — isolamento por aplicativo');
  await migrate(db, ISOLATION);

  // Dois aplicativos de teste (não são os projetos da feira; só validam o isolamento).
  await db.exec(`
    insert into platform.apps (slug, name, join_policy, default_role) values
      ('app_a', 'Aplicativo A', 'open', 'student'),
      ('app_b', 'Aplicativo B', 'invite', 'student');
    insert into platform.app_roles (app_slug, role, can_manage_members) values
      ('app_a', 'student', false), ('app_a', 'teacher', true),
      ('app_b', 'student', false), ('app_b', 'teacher', true);

    create schema app_a;
    create table app_a.notes (id bigint generated always as identity primary key, owner_id uuid not null default auth.uid(), body text not null);
    alter table app_a.notes enable row level security;
    grant usage on schema app_a to authenticated;
    grant select, insert on app_a.notes to authenticated;
    create policy notes_member on app_a.notes for all to authenticated
      using ((select public.has_app_access('app_a'))) with check ((select public.has_app_access('app_a')) and owner_id = (select auth.uid()));

    create schema app_b;
    create table app_b.notes (id bigint generated always as identity primary key, owner_id uuid not null default auth.uid(), body text not null);
    alter table app_b.notes enable row level security;
    grant usage on schema app_b to authenticated;
    grant select, insert on app_b.notes to authenticated;
    create policy notes_member on app_b.notes for all to authenticated
      using ((select public.has_app_access('app_b'))) with check ((select public.has_app_access('app_b')) and owner_id = (select auth.uid()));
  `);

  const root = await signUp(db, { email: 'root@example.com', meta: { name: 'Root' } });
  const teacherA = await signUp(db, { email: 'profa@example.com', meta: { name: 'Professora A', signup_app: 'app_a' } });
  const studentA = await signUp(db, { email: 'alunoa@example.com', meta: { name: 'Aluno A', signup_app: 'app_a' } });
  const studentB = await signUp(db, { email: 'alunob@example.com', meta: { name: 'Aluno B', signup_app: 'app_b' } });

  await test('participante do Venexus continua lendo e publicando', async () => {
    const seen = await asUser(db, ana, (q) => q(`select count(*)::int as n from public.posts`));
    equal(seen, [{ n: 2 }], 'posts visíveis');
    const courses = await asUser(db, ana, (q) => q(`select count(*)::int as n from public.senai_courses`));
    equal(courses, [{ n: 3 }], 'cursos visíveis');
  });

  await test('autoria não é falsificável: autor, nome e papel vêm do banco', async () => {
    const forged = await asUser(db, ana, (q) => insertPost(q, staff, { title: 'Forjado', authorName: 'Equipe SENAI', authorRole: 'admin' }));
    equal([forged.author_id, forged.author_name, forged.author_role], [ana, 'Ana', 'reader']);
    const official = await asUser(db, staff, (q) => insertPost(q, staff, { title: 'Oficial' }));
    equal(official.author_role, 'admin', 'papel da equipe');
  });

  await test('posts, comentários e autoria anteriores ficam intactos', async () => {
    const posts = await rows(db, `select id, author_id, author_name, author_role from public.posts where id = any($1) order by id`, [contentBefore.map((p) => p.id)]);
    equal(posts, contentBefore, 'posts');
    equal(await rows(db, `select id, author_id, author_name, author_role from public.comments order by id`), commentsBefore, 'comentários');
  });

  await test('usuário de outro aplicativo não lê nem grava no Venexus', async () => {
    equal(await membership(db, 'app_a', studentA), { role: 'student', status: 'active' }, 'vínculo em A');
    for (const table of ['posts', 'comments', 'senai_courses', 'cartilha_contents', 'notification_reads']) {
      equal(await asUser(db, studentA, (q) => q(`select count(*)::int as n from public.${table}`)), [{ n: 0 }], table);
    }
    await rejects(asUser(db, studentA, (q) => insertPost(q, studentA)), /row-level security/, 'post');
    await rejects(
      asUser(db, studentA, (q) => q(`insert into public.comments (post_id, author_id, author_name, text) values ($1, $2, 'x', 'Oi')`, [anaPost.id, studentA])),
      /row-level security/,
      'comentário',
    );
    equal(await asUser(db, studentA, (q) => q(`delete from public.posts where id = $1 returning id`, [anaPost.id])), [], 'delete');
  });

  await test('usuário sem nenhum vínculo não acessa conteúdo restrito', async () => {
    equal(await asUser(db, outsiderTwo, (q) => q(`select count(*)::int as n from public.posts`)), [{ n: 0 }], 'venexus');
    equal(await asUser(db, outsiderTwo, (q) => q(`select count(*)::int as n from app_a.notes`)), [{ n: 0 }], 'app_a');
    equal(await asUser(db, outsiderTwo, (q) => q(`select * from public.my_app_memberships()`)), [], 'vínculos');
  });

  await test('participante de A não acessa B (e vice-versa)', async () => {
    await asUser(db, studentA, (q) => q(`insert into app_a.notes (body) values ('nota de A')`));
    await db.exec(`insert into platform.app_memberships (app_slug, user_id, role) values ('app_b', '${studentB}', 'student')`);
    await asUser(db, studentB, (q) => q(`insert into app_b.notes (body) values ('nota de B')`));

    equal(await asUser(db, studentA, (q) => q(`select body from app_a.notes`)), [{ body: 'nota de A' }], 'A lê A');
    equal(await asUser(db, studentA, (q) => q(`select body from app_b.notes`)), [], 'A lê B');
    equal(await asUser(db, studentB, (q) => q(`select body from app_a.notes`)), [], 'B lê A');
    await rejects(asUser(db, studentA, (q) => q(`insert into app_b.notes (body) values ('invasão')`)), /row-level security/, 'A grava em B');
    equal(await asUser(db, ana, (q) => q(`select body from app_a.notes`)), [], 'Venexus lê A');
  });

  await test('política de entrada: aberta entra, convite não, e signup_app não fura o convite', async () => {
    equal(await membership(db, 'app_b', teacherA), null, 'sem vínculo em B');
    await rejects(asUser(db, studentA, (q) => q(`select public.join_app('app_b')`)), /convidados/, 'join em app por convite');
    equal(await asUser(db, outsiderOne, (q) => q(`select public.join_app('app_a') as status`)), [{ status: 'active' }], 'join em app aberto');
    equal(await membership(db, 'app_a', outsiderOne), { role: 'student', status: 'active' });
    const invited = await signUp(db, { email: 'penetra@example.com', meta: { signup_app: 'app_b' } });
    equal(await membership(db, 'app_b', invited), null, 'cadastro com signup_app de app por convite');
  });

  await test('perfis: cada um vê e edita só o próprio; telefone, endereço e e-mail não vazam', async () => {
    equal(await asUser(db, studentA, (q) => q(`select id from public.profiles`)), [{ id: studentA }], 'outro aplicativo');
    equal(await asUser(db, beto, (q) => q(`select id from public.profiles`)), [{ id: beto }], 'mesmo aplicativo');
    await asUser(db, ana, (q) => q(`update public.profiles set name = 'Ana Maria', phone = '(46) 99999-0001' where id = $1`, [ana]));
    equal([(await profile(db, ana)).name, (await profile(db, ana)).phone], ['Ana Maria', '46999990001']);
    equal(await asUser(db, ana, (q) => q(`update public.profiles set name = 'Invadido' where id = $1 returning id`, [beto])), [], 'perfil alheio');
    await rejects(asAnon(db, (q) => q(`select id from public.profiles`)), /permission denied/, 'anon');
  });

  await test('ninguém altera o próprio papel, e-mail, vínculo ou status', async () => {
    await rejects(asUser(db, ana, (q) => q(`update public.profiles set role = 'admin' where id = $1`, [ana])), /permission denied/, 'profiles.role');
    await rejects(asUser(db, ana, (q) => q(`update public.profiles set email = 'x@sistemafiep.org.br' where id = $1`, [ana])), /permission denied/, 'profiles.email');
    await rejects(asUser(db, ana, (q) => q(`select public.set_app_membership('venexus', $1, 'admin')`, [ana])), /próprio vínculo/, 'RPC em si mesma');
    await rejects(asUser(db, ana, (q) => q(`update platform.app_memberships set role = 'admin' where user_id = $1`, [ana])), /permission denied/, 'tabela de vínculos');
    await rejects(asUser(db, ana, (q) => q(`insert into platform.platform_admins (user_id) values ($1)`, [ana])), /permission denied/, 'admins globais');
    await rejects(asUser(db, ana, (q) => q(`select platform.grant_platform_admin('ana@example.com')`)), /permission denied/, 'bootstrap pela API');
    equal(await membership(db, 'venexus', ana), { role: 'reader', status: 'active' });
  });

  await test('primeiro administrador global: procedimento explícito, só pelo dono do banco', async () => {
    await rejects(db.query(`select platform.grant_platform_admin('novo@sistemafiep.org.br')`), /confirmado/, 'e-mail não confirmado');
    await db.query(`select platform.grant_platform_admin('root@example.com')`);
    equal(await asUser(db, root, (q) => q(`select public.is_platform_admin() as ok`)), [{ ok: true }], 'root');
    equal(await asUser(db, staff, (q) => q(`select public.is_platform_admin() as ok`)), [{ ok: false }], 'admin do Venexus');
  });

  await test('administrador global gerencia vínculos de qualquer aplicativo', async () => {
    await asUser(db, root, (q) => q(`select public.set_app_membership('app_a', $1, 'teacher')`, [teacherA]));
    equal(await membership(db, 'app_a', teacherA), { role: 'teacher', status: 'active' });
  });

  await test('administrador local não executa ação global nem fora do próprio aplicativo', async () => {
    // Admin do Venexus: modera conteúdo, não administra vínculos.
    await rejects(asUser(db, staff, (q) => q(`select public.set_app_membership('venexus', $1, 'admin')`, [ana])), /Sem permissão/, 'admin do Venexus promovendo');
    await rejects(asUser(db, staff, (q) => q(`select public.set_app_membership('app_a', $1, 'student')`, [ana])), /Sem permissão/, 'admin do Venexus em A');
    // Professora de A: convida/revoga alunos de A, e só isso.
    await asUser(db, teacherA, (q) => q(`select public.set_app_membership('app_a', $1, 'student')`, [beto]));
    equal(await membership(db, 'app_a', beto), { role: 'student', status: 'active' }, 'convite em A');
    await rejects(asUser(db, teacherA, (q) => q(`select public.set_app_membership('app_b', $1, 'student')`, [beto])), /Sem permissão/, 'professora de A em B');
    await rejects(asUser(db, teacherA, (q) => q(`select public.set_app_membership('venexus', $1, 'reader', 'revoked')`, [ana])), /Sem permissão/, 'professora de A no Venexus');
    await rejects(asUser(db, teacherA, (q) => q(`select public.set_app_membership('app_a', $1, 'teacher')`, [beto])), /plataforma/, 'promover a professor');
    await rejects(asUser(db, teacherA, (q) => q(`select public.set_app_membership('app_a', $1, 'student', 'revoked')`, [teacherA])), /próprio vínculo/, 'alterar a si mesma');
    await rejects(asUser(db, teacherA, (q) => q(`delete from auth.users where id = $1`, [beto])), /permission denied/, 'excluir identidade global');
    equal(await asUser(db, teacherA, (q) => q(`select public.is_platform_admin() as ok`)), [{ ok: false }]);
  });

  await test('moderação do Venexus: admin apaga conteúdo alheio; leitor só o próprio', async () => {
    const target = await asUser(db, ana, (q) => insertPost(q, ana, { title: 'Para moderar' }));
    equal(await asUser(db, beto, (q) => q(`delete from public.posts where id = $1 returning id`, [target.id])), [], 'outro leitor');
    equal(await asUser(db, staff, (q) => q(`delete from public.posts where id = $1 returning id`, [target.id])), [{ id: target.id }], 'admin');
    await rejects(
      asUser(db, ana, (q) => q(`insert into public.senai_courses (name, description, institution_address, created_by_id) values ('x', 'y', 'z', $1)`, [ana])),
      /row-level security/,
      'leitor publicando curso',
    );
    await asUser(db, staff, (q) => q(`insert into public.senai_courses (name, description, institution_address, created_by_id) values ('Curso', 'y', 'z', $1)`, [staff]));
  });

  await test('respostas: só a quem comentou na mesma publicação', async () => {
    const reply = await asUser(db, staff, (q) =>
      q(
        `insert into public.comments (post_id, author_id, author_name, text, parent_id, reply_to_author_id, reply_to_name)
         values ($1, $2, 'x', 'Resposta', $3, $4, 'Nome Forjado') returning reply_to_name`,
        [staffPost.id, staff, anaComment.id, ana],
      ),
    );
    equal(reply, [{ reply_to_name: 'Ana' }], 'nome de quem foi respondido');
    await rejects(
      asUser(db, ana, (q) =>
        q(`insert into public.comments (post_id, author_id, author_name, text, reply_to_author_id) values ($1, $2, 'x', 'Oi', $3)`, [staffPost.id, ana, studentA]),
      ),
      /não pertence/,
      'sondar nome por id',
    );
  });

  await test('sem usuário não há autorização implícita; service_role continua administrando', async () => {
    await rejects(asAnon(db, (q) => insertPost(q, ana)), /permission denied/, 'anon');
    await rejects(request(db, 'authenticated', null, (q) => insertPost(q, ana)), /row-level security|Autenticação/, 'authenticated sem sub');
    const admin = await asService(db, (q) => insertPost(q, staff, { title: 'Importado', authorName: 'Equipe SENAI', authorRole: 'admin' }));
    equal([admin.author_id, admin.author_name], [staff, 'Equipe SENAI'], 'service_role');
  });

  await test('funções internas não são executáveis pela API', async () => {
    await rejects(asAnon(db, (q) => q(`select public.has_app_access('venexus')`)), /permission denied/, 'anon: has_app_access');
    await rejects(asAnon(db, (q) => q(`select * from public.my_app_memberships()`)), /permission denied/, 'anon: my_app_memberships');
    await rejects(asAnon(db, (q) => q(`select * from public.phone_auth_resolve('46999990001', '1.1.1.1', 'login')`)), /permission denied/, 'anon: phone_auth_resolve');
    await rejects(asUser(db, ana, (q) => q(`select * from public.phone_auth_resolve('46999990001', '1.1.1.1', 'login')`)), /permission denied/, 'authenticated: phone_auth_resolve');
    await rejects(asService(db, (q) => q(`select * from platform.app_memberships`)), /permission denied/, 'service_role no schema platform');
  });

  await test('login por telefone: e-mail só para a Edge Function, com limite por telefone + IP', async () => {
    const resolve = (phone, ip, action = 'login') => asService(db, (q) => q(`select * from public.phone_auth_resolve($1, $2, $3)`, [phone, ip, action]));
    equal(await resolve('(46) 99999-0001', '10.0.0.1'), [{ allowed: true, email: 'ana@example.com' }], 'telefone conhecido');
    equal(await resolve('46900000000', '10.0.0.1'), [{ allowed: true, email: null }], 'telefone desconhecido');
    equal(await resolve('abc', '10.0.0.1'), [{ allowed: true, email: null }], 'telefone inválido');
    // E-mail trocado no Auth: o login acompanha (antes vinha da cópia no perfil).
    equal(await resolve('46988887777', '10.0.0.1'), [{ allowed: true, email: 'carla.nova@example.com' }], 'e-mail atual do Auth');
    for (let i = 0; i < 9; i++) await resolve('46999990001', '10.0.0.1');
    equal(await resolve('46999990001', '10.0.0.1'), [{ allowed: false, email: null }], '11ª tentativa do mesmo telefone + IP');
    // Wi-Fi compartilhado: outra pessoa no mesmo IP não é bloqueada...
    equal((await resolve('46999991111', '10.0.0.1'))[0].allowed, true, 'outro telefone, mesmo IP');
    // ...e a dona do telefone, em outra rede, também não.
    equal((await resolve('46999990001', '10.0.0.2'))[0].allowed, true, 'mesmo telefone, outro IP');
    await rejects(resolve('46999990001', '10.0.0.1', 'drop'), /inválida/, 'ação desconhecida');
    equal(await rows(db, `select count(*)::int as n from platform.rate_limits where bucket like '%4699%'`), [{ n: 0 }], 'telefone em claro nos contadores');
  });

  await test('revogar o vínculo corta o acesso na hora, com a mesma sessão', async () => {
    equal(await asUser(db, beto, (q) => q(`select count(*)::int as n from public.posts`)).then((r) => r[0].n > 0), true, 'antes');
    await asUser(db, root, (q) => q(`select public.set_app_membership('venexus', $1, 'reader', 'revoked')`, [beto]));
    equal(await asUser(db, beto, (q) => q(`select count(*)::int as n from public.posts`)), [{ n: 0 }], 'leitura');
    await rejects(asUser(db, beto, (q) => insertPost(q, beto)), /row-level security/, 'gravação');
    equal(await asUser(db, beto, (q) => q(`select public.join_app('venexus') as status`)), [{ status: 'revoked' }], 'tentar entrar de novo');
    equal(await asUser(db, beto, (q) => q(`select count(*)::int as n from public.posts`)), [{ n: 0 }], 'depois do join');
    // Revogar um aplicativo não mexe nos outros nem na identidade.
    equal(await asUser(db, beto, (q) => q(`select body from app_a.notes`)), [{ body: 'nota de A' }], 'app_a');
    equal((await profile(db, beto)).id, beto, 'perfil');
  });

  // -------------------------------------------------------------------------
  console.log('\nEtapa 3 — remoção dos caminhos antigos');
  await migrate(db, CLEANUP);

  await test('RPCs antigas deixam de existir', async () => {
    await rejects(asAnon(db, (q) => q(`select public.login_email_for_phone('46999990001')`)), /does not exist/, 'login_email_for_phone');
    await rejects(asAnon(db, (q) => q(`select public.phone_in_use('46999990001')`)), /does not exist/, 'phone_in_use');
    await rejects(asUser(db, ana, (q) => q(`select public.email_in_use('ana@example.com')`)), /does not exist/, 'email_in_use');
  });

  await test('depois da limpeza: cadastro, perfil e publicação seguem funcionando', async () => {
    const eva = await signUp(db, { email: 'eva@example.com', meta: venexusMeta({ name: 'Eva', phone: '46933330000', signup_app: 'venexus' }) });
    equal(await rows(db, `select count(*)::int as n from public.profiles where id = $1`, [eva]), [{ n: 1 }], 'perfis');
    equal(await membership(db, 'venexus', eva), { role: 'reader', status: 'active' }, 'vínculo');
    await asUser(db, eva, (q) => q(`update public.profiles set address = 'Rua Nova' where id = $1`, [eva]));
    const post = await asUser(db, eva, (q) => insertPost(q, eva));
    equal([post.author_name, post.author_role], ['Eva', 'reader']);
    equal(await asUser(db, eva, (q) => q(`select role, status from public.my_app_memberships() where app_slug = 'venexus'`)), [{ role: 'reader', status: 'active' }]);
    equal('role' in (await profile(db, eva)), false, 'profiles.role');
  });

  await test('excluir a identidade global apaga perfil, vínculos e conteúdo do autor (cascade)', async () => {
    await db.exec(`delete from auth.users where id = '${ana}'`);
    equal(await profile(db, ana), null, 'perfil');
    equal(await rows(db, `select count(*)::int as n from platform.app_memberships where user_id = $1`, [ana]), [{ n: 0 }], 'vínculos');
    equal(await rows(db, `select count(*)::int as n from public.posts where author_id = $1`, [ana]), [{ n: 0 }], 'posts');
    equal(await rows(db, `select count(*)::int as n from public.comments where author_id = $1`, [ana]), [{ n: 0 }], 'comentários');
    equal(await rows(db, `select count(*)::int as n from public.posts where id = $1`, [staffPost.id]), [{ n: 1 }], 'posts de outras pessoas');
  });

  await db.close();
}

// ---------------------------------------------------------------------------
// Cenário 2: instalação nova (todas as migrations em um banco vazio)
// ---------------------------------------------------------------------------

async function freshInstallScenario() {
  console.log('\nInstalação nova');
  const db = await createDatabase();
  for (const file of migrations) await migrate(db, file);

  await test('instalação nova: cadastro do Venexus, equipe com e-mail já confirmado e dados iniciais', async () => {
    const staff = await signUp(db, { email: 'equipe@sistemafiep.org.br', meta: venexusMeta({ name: 'Equipe', phone: '46999991111', signup_app: 'venexus' }) });
    equal(await membership(db, 'venexus', staff), { role: 'admin', status: 'active' }, 'vínculo');
    equal(await asUser(db, staff, (q) => q(`select count(*)::int as n from public.cartilha_contents`)), [{ n: 5 }], 'cartilha');
    await asUser(db, staff, (q) =>
      q(`insert into public.cartilha_contents (type, title, text_pt, text_es, explanation, created_by_id) values ('rights', 't', 'p', 'e', 'x', $1)`, [staff]),
    );
    await asUser(db, staff, (q) => q(`insert into public.notification_reads (user_id, notification_id) values ($1, 'post-1') on conflict (user_id, notification_id) do nothing`, [staff]));
  });

  await test('instalação nova: nenhuma função de public fica executável por anon', async () => {
    const open = await rows(
      db,
      `select p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
       where n.nspname = 'public' and has_function_privilege('anon', p.oid, 'execute')
         -- No Supabase as extensões ficam no schema extensions; aqui o pgcrypto cai em public.
         and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')
       order by 1`,
    );
    equal(open, []);
  });

  await test('instalação nova: tabelas do Venexus sem privilégio para anon e com RLS', async () => {
    const tables = await rows(
      db,
      `select c.relname, c.relrowsecurity as rls,
              has_table_privilege('anon', c.oid, 'select,insert,update,delete,truncate') as anon
       from pg_class c join pg_namespace n on n.oid = c.relnamespace
       where n.nspname in ('public', 'platform') and c.relkind = 'r' order by 1`,
    );
    equal(tables.filter((t) => !t.rls || t.anon), []);
  });

  await db.close();
}

await upgradeScenario();
await freshInstallScenario();

console.log(`\n${passed} ok, ${failures.length} falha(s)`);
if (failures.length > 0) {
  for (const name of failures) console.log(`  - ${name}`);
  process.exit(1);
}
