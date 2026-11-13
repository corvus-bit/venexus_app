// deno test --allow-env supabase/functions/phone-auth/
//
// O Auth e o PostgREST são simulados por um fetch falso: o que se testa aqui é o contrato da
// função (o que ela devolve e o que ela NÃO devolve), não o Supabase.

import { handler } from './handler.ts';

const SECRET = 'sb_secret_test';
const ACCOUNT = { phone: '46999990000', email: 'ana@example.com', password: 'senha-correta', confirmed: true };

interface Call {
  path: string;
  headers: Headers;
  body: Record<string, unknown>;
}

function assertEquals(actual: unknown, expected: unknown, label = 'valor') {
  const a = JSON.stringify(actual);
  const e = JSON.stringify(expected);
  if (a !== e) throw new Error(`${label}: esperado ${e}, veio ${a}`);
}

/** Substitui o fetch global por um Supabase de mentira e devolve as chamadas recebidas. */
function fakeSupabase(options: { allowed?: boolean; authStatus?: number } = {}): Call[] {
  const calls: Call[] = [];
  Deno.env.set('SUPABASE_URL', 'https://projeto.supabase.co');
  Deno.env.set('SUPABASE_SECRET_KEYS', JSON.stringify({ default: SECRET }));

  globalThis.fetch = ((input: string | URL | Request, init?: RequestInit) => {
    const url = new URL(String(input));
    const body = JSON.parse(String(init?.body ?? '{}'));
    calls.push({ path: url.pathname + url.search, headers: new Headers(init?.headers), body });
    const json = (status: number, data: unknown) => Promise.resolve(new Response(JSON.stringify(data), { status }));

    if (url.pathname === '/rest/v1/rpc/phone_auth_resolve') {
      const known = body.p_phone === ACCOUNT.phone;
      return json(200, [{ allowed: options.allowed ?? true, email: (options.allowed ?? true) && known ? ACCOUNT.email : null }]);
    }
    if (options.authStatus) return json(options.authStatus, { error_code: 'over_request_rate_limit' });
    if (url.pathname === '/auth/v1/token') {
      if (body.email !== ACCOUNT.email || body.password !== ACCOUNT.password) return json(400, { error_code: 'invalid_credentials' });
      if (!ACCOUNT.confirmed) return json(400, { error_code: 'email_not_confirmed' });
      return json(200, { access_token: 'access', refresh_token: 'refresh', user: { email: ACCOUNT.email } });
    }
    if (url.pathname === '/auth/v1/verify') {
      if (body.email === ACCOUNT.email && body.token === '12345678') {
        return json(200, { access_token: 'recovery-access', refresh_token: 'recovery-refresh', user: { email: ACCOUNT.email } });
      }
      return json(403, { error_code: 'otp_expired' });
    }
    return json(200, {});
  }) as typeof fetch;

  return calls;
}

async function call(body: unknown, init: { method?: string; headers?: Record<string, string> } = {}) {
  const response = await handler(
    new Request('https://projeto.supabase.co/functions/v1/phone-auth', {
      method: init.method ?? 'POST',
      headers: { 'x-forwarded-for': '203.0.113.7, 10.0.0.1', ...init.headers },
      body: init.method === 'OPTIONS' || init.method === 'GET' ? undefined : typeof body === 'string' ? body : JSON.stringify(body),
    }),
  );
  const text = await response.text();
  return { status: response.status, text, json: text ? JSON.parse(text) : null };
}

Deno.test('login correto devolve só os tokens da sessão', async () => {
  const calls = fakeSupabase();
  const result = await call({ action: 'login', phone: '(46) 99999-0000', password: ACCOUNT.password });
  assertEquals(result.status, 200);
  assertEquals(result.json, { status: 'signed_in', access_token: 'access', refresh_token: 'refresh' });
  assertEquals(calls[0].body, { p_phone: ACCOUNT.phone, p_ip: '203.0.113.7', p_action: 'login' }, 'RPC');
});

Deno.test('telefone inexistente e senha errada são indistinguíveis e não trazem e-mail', async () => {
  const calls = fakeSupabase();
  const wrongPassword = await call({ action: 'login', phone: ACCOUNT.phone, password: 'errada' });
  const unknownPhone = await call({ action: 'login', phone: '46900000000', password: 'errada' });
  assertEquals(wrongPassword.status, 401);
  assertEquals([unknownPhone.status, unknownPhone.text], [wrongPassword.status, wrongPassword.text]);
  assertEquals(wrongPassword.text.includes('@'), false, 'e-mail na resposta');
  // O telefone desconhecido também passa pelo Auth, para o tempo de resposta ser parecido.
  assertEquals(calls.filter((c) => c.path.startsWith('/auth/v1/token')).length, 2, 'chamadas ao Auth');
});

Deno.test('a senha é conferida pelo Auth, com a chave no cabeçalho e o IP de origem repassado', async () => {
  const calls = fakeSupabase();
  await call({ action: 'login', phone: ACCOUNT.phone, password: ACCOUNT.password });
  const token = calls.find((c) => c.path.startsWith('/auth/v1/token'))!;
  assertEquals(token.path, '/auth/v1/token?grant_type=password');
  assertEquals(token.body, { email: ACCOUNT.email, password: ACCOUNT.password });
  assertEquals([token.headers.get('apikey'), token.headers.get('authorization')], [SECRET, null]);
  assertEquals(token.headers.get('sb-forwarded-for'), '203.0.113.7');
  assertEquals(calls.some((c) => c.path.includes('/admin/')), false, 'API administrativa');
});

Deno.test('conta sem e-mail confirmado: só quem acertou a senha recebe o e-mail', async () => {
  ACCOUNT.confirmed = false;
  try {
    const calls = fakeSupabase();
    const owner = await call({ action: 'login', phone: ACCOUNT.phone, password: ACCOUNT.password });
    assertEquals(owner.json, { status: 'confirmation_required', email: ACCOUNT.email });
    assertEquals(calls.at(-1)!.body, { type: 'signup', email: ACCOUNT.email }, 'reenvio do código');
    const stranger = await call({ action: 'login', phone: ACCOUNT.phone, password: 'errada' });
    assertEquals([stranger.status, stranger.json], [401, { error: 'invalid_credentials' }]);
  } finally {
    ACCOUNT.confirmed = true;
  }
});

Deno.test('recuperação responde igual com ou sem conta', async () => {
  const calls = fakeSupabase();
  const known = await call({ action: 'recover', phone: ACCOUNT.phone });
  const unknown = await call({ action: 'recover', phone: '46900000000' });
  assertEquals([known.status, known.text], [200, '{"status":"ok"}']);
  assertEquals([unknown.status, unknown.text], [known.status, known.text]);
  assertEquals(calls.filter((c) => c.path === '/auth/v1/recover').map((c) => c.body), [{ email: ACCOUNT.email }], 'e-mails enviados');
});

Deno.test('recuperação não denuncia a conta nem quando o Auth recusa o envio', async () => {
  fakeSupabase({ authStatus: 429 });
  const known = await call({ action: 'recover', phone: ACCOUNT.phone });
  assertEquals([known.status, known.text], [200, '{"status":"ok"}']);
});

Deno.test('código de recuperação: certo abre a sessão, errado ou de telefone desconhecido é genérico', async () => {
  fakeSupabase();
  const ok = await call({ action: 'verify_recovery', phone: ACCOUNT.phone, code: '12345678' });
  assertEquals(ok.json, { status: 'signed_in', access_token: 'recovery-access', refresh_token: 'recovery-refresh' });
  const wrong = await call({ action: 'verify_recovery', phone: ACCOUNT.phone, code: '00000000' });
  const unknown = await call({ action: 'verify_recovery', phone: '46900000000', code: '12345678' });
  assertEquals([wrong.status, wrong.json], [401, { error: 'invalid_code' }]);
  assertEquals([unknown.status, unknown.text], [wrong.status, wrong.text]);
});

Deno.test('limite estourado no banco ou no Auth vira 429 sem chamar o Auth à toa', async () => {
  const calls = fakeSupabase({ allowed: false });
  const blocked = await call({ action: 'login', phone: ACCOUNT.phone, password: ACCOUNT.password });
  assertEquals([blocked.status, blocked.json], [429, { error: 'rate_limited' }]);
  assertEquals(calls.length, 1, 'só a RPC');
  fakeSupabase({ authStatus: 429 });
  const throttled = await call({ action: 'login', phone: ACCOUNT.phone, password: ACCOUNT.password });
  assertEquals(throttled.status, 429);
});

Deno.test('payload inválido ou grande demais é recusado antes de qualquer chamada', async () => {
  const calls = fakeSupabase();
  const cases: unknown[] = [
    'isto não é json',
    [],
    { action: 'login', phone: '123', password: 'x' },
    { action: 'login', phone: ACCOUNT.phone },
    { action: 'login', phone: ACCOUNT.phone, password: 'x'.repeat(257) },
    { action: 'login', phone: { $ne: null }, password: 'x' },
    { action: 'verify_recovery', phone: ACCOUNT.phone, code: 'abc' },
    { action: 'sql', phone: ACCOUNT.phone, query: 'select 1' },
  ];
  for (const body of cases) assertEquals((await call(body)).status, 400, JSON.stringify(body));
  assertEquals((await call({ action: 'login', phone: ACCOUNT.phone, password: 'x', pad: 'x'.repeat(3000) })).status, 413, 'corpo grande');
  assertEquals((await call(null, { method: 'GET' })).status, 405, 'GET');
  assertEquals((await call(null, { method: 'OPTIONS' })).status, 204, 'preflight');
  assertEquals(calls.length, 0, 'chamadas ao Supabase');
});

Deno.test('falha interna não vaza detalhes', async () => {
  fakeSupabase();
  globalThis.fetch = (() => Promise.reject(new Error('connect ECONNREFUSED https://projeto.supabase.co secret'))) as typeof fetch;
  const result = await call({ action: 'login', phone: ACCOUNT.phone, password: ACCOUNT.password });
  assertEquals([result.status, result.json], [503, { error: 'unavailable' }]);
});

Deno.test('sem chave secreta configurada a função falha fechada', async () => {
  fakeSupabase();
  Deno.env.delete('SUPABASE_SECRET_KEYS');
  const result = await call({ action: 'login', phone: ACCOUNT.phone, password: ACCOUNT.password });
  assertEquals(result.status, 503);
});
