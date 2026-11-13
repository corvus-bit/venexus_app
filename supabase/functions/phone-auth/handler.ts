// Login e recuperação de senha por telefone, sem revelar o e-mail da conta.
//
// O Supabase Auth autentica por e-mail + senha; o Venexus mostra telefone + senha. Antes, o app
// perguntava o e-mail a uma RPC pública. Agora o e-mail é resolvido aqui dentro e nunca volta
// para quem não provou a senha.
//
// Este endpoint é público por natureza (roda antes do login), então:
//   - a senha é sempre verificada pelo Auth (grant_type=password); nada de API administrativa;
//   - as respostas de falha são genéricas: telefone inexistente e senha errada são iguais;
//   - o controle de abuso fica no banco (public.phone_auth_resolve), porque a função roda em
//     várias instâncias;
//   - CORS só libera o navegador; não é autorização.
//
// Nunca registre telefone, senha, código, e-mail ou tokens nos logs.

type Json = Record<string, unknown>;

const MAX_BODY_BYTES = 2048;
const UPSTREAM_TIMEOUT_MS = 10_000;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function reply(status: number, body: Json): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json', 'Cache-Control': 'no-store' },
  });
}

/** Chave secreta do projeto. Só sai daqui para o PostgREST e para o Auth do próprio projeto. */
function secretKey(): string {
  const override = Deno.env.get('PHONE_AUTH_SECRET_KEY');
  if (override) return override;
  try {
    const named = JSON.parse(Deno.env.get('SUPABASE_SECRET_KEYS') ?? 'null');
    if (named && typeof named === 'object') {
      const key = named.default ?? Object.values(named)[0];
      if (typeof key === 'string' && key) return key;
    }
  } catch {
    // Formato inesperado: cai nas variáveis abaixo.
  }
  return Deno.env.get('SUPABASE_SECRET_KEY') ?? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
}

/** IP de quem chamou, como o gateway do Supabase informa. Usado só para limitar abuso. */
function clientIp(req: Request): string | null {
  const first = (req.headers.get('x-forwarded-for') ?? '').split(',')[0].trim();
  return /^[0-9a-fA-F:.]{3,45}$/.test(first) ? first : null;
}

function keyHeaders(key: string): Record<string, string> {
  // As chaves novas (sb_secret_...) vão só em apikey; as antigas (JWT) também em Authorization.
  return key.startsWith('eyJ') ? { apikey: key, Authorization: `Bearer ${key}` } : { apikey: key };
}

async function post(url: string, headers: Record<string, string>, body: Json): Promise<{ status: number; data: Json }> {
  const response = await fetch(url, {
    method: 'POST',
    headers: { ...headers, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(UPSTREAM_TIMEOUT_MS),
  });
  let data: unknown = null;
  try {
    data = await response.json();
  } catch {
    // Resposta sem corpo JSON.
  }
  return { status: response.status, data: data && typeof data === 'object' ? (data as Json) : {} };
}

interface Context {
  url: string;
  key: string;
  ip: string | null;
}

/** Chamada ao Auth do projeto, repassando o IP de origem para os limites do próprio Auth. */
function auth(ctx: Context, path: string, body: Json) {
  const headers = keyHeaders(ctx.key);
  // Só vale com chave sb_secret_ e com "IP Address Forwarding" ligado em Authentication > Rate Limits.
  // Sem isso o Auth conta todas as pessoas como um IP só (o desta função).
  if (ctx.ip) headers['Sb-Forwarded-For'] = ctx.ip;
  return post(`${ctx.url}/auth/v1/${path}`, headers, body);
}

/** Aplica os limites e resolve o e-mail no banco, em uma única chamada. */
async function resolve(ctx: Context, phone: string, action: string): Promise<{ allowed: boolean; email: string | null }> {
  const { status, data } = await post(`${ctx.url}/rest/v1/rpc/phone_auth_resolve`, keyHeaders(ctx.key), {
    p_phone: phone,
    p_ip: ctx.ip,
    p_action: action,
  });
  const row = (Array.isArray(data) ? data[0] : data) as Json | undefined;
  if (status !== 200 || !row || typeof row.allowed !== 'boolean') throw new Error(`phone_auth_resolve: ${status}`);
  return { allowed: row.allowed, email: typeof row.email === 'string' && row.email ? row.email : null };
}

function sessionReply(data: Json): Response {
  if (typeof data.access_token !== 'string' || typeof data.refresh_token !== 'string') {
    return reply(503, { error: 'unavailable' });
  }
  return reply(200, { status: 'signed_in', access_token: data.access_token, refresh_token: data.refresh_token });
}

async function login(ctx: Context, phone: string, password: string): Promise<Response> {
  const { allowed, email } = await resolve(ctx, phone, 'login');
  if (!allowed) return reply(429, { error: 'rate_limited' });

  // Telefone desconhecido também vai ao Auth (com um e-mail que não existe), para que o tempo
  // de resposta não denuncie quais telefones têm conta.
  const { status, data } = await auth(ctx, 'token?grant_type=password', {
    email: email ?? 'desconhecido@login.invalid',
    password,
  });

  if (status === 200 && email) return sessionReply(data);
  if (status === 429) return reply(429, { error: 'rate_limited' });
  if (status >= 500) return reply(503, { error: 'unavailable' });

  // O Auth só responde email_not_confirmed depois de conferir a senha: quem chega aqui é o dono
  // da conta, então pode receber o próprio e-mail para digitar o código de confirmação.
  if (email && data.error_code === 'email_not_confirmed') {
    try {
      await auth(ctx, 'resend', { type: 'signup', email });
    } catch {
      // Limite de reenvio: a tela de confirmação permite pedir outro código depois.
    }
    return reply(200, { status: 'confirmation_required', email });
  }
  return reply(401, { error: 'invalid_credentials' });
}

async function recover(ctx: Context, phone: string): Promise<Response> {
  const { allowed, email } = await resolve(ctx, phone, 'recover');
  if (!allowed) return reply(429, { error: 'rate_limited' });

  // A resposta é a mesma com ou sem conta, e sai antes do envio do e-mail terminar.
  if (email) {
    const sending = auth(ctx, 'recover', { email }).then(
      ({ status }) => {
        if (status >= 400) console.error(`phone-auth recover: auth ${status}`);
      },
      () => console.error('phone-auth recover: auth unreachable'),
    );
    const runtime = (globalThis as { EdgeRuntime?: { waitUntil(promise: Promise<unknown>): void } }).EdgeRuntime;
    if (runtime) runtime.waitUntil(sending);
    else await sending;
  }
  return reply(200, { status: 'ok' });
}

async function verifyRecovery(ctx: Context, phone: string, code: string): Promise<Response> {
  const { allowed, email } = await resolve(ctx, phone, 'verify');
  if (!allowed) return reply(429, { error: 'rate_limited' });
  if (!email) return reply(401, { error: 'invalid_code' });

  // Devolve a sessão de recuperação; a troca da senha é feita pelo app, direto no Auth.
  const { status, data } = await auth(ctx, 'verify', { type: 'recovery', email, token: code });
  if (status === 200) return sessionReply(data);
  if (status === 429) return reply(429, { error: 'rate_limited' });
  if (status >= 500) return reply(503, { error: 'unavailable' });
  return reply(401, { error: 'invalid_code' });
}

export async function handler(req: Request): Promise<Response> {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: corsHeaders });
  if (req.method !== 'POST') return reply(405, { error: 'method_not_allowed' });

  const raw = await req.text();
  if (new TextEncoder().encode(raw).length > MAX_BODY_BYTES) return reply(413, { error: 'payload_too_large' });

  let body: Json;
  try {
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) throw new Error('not an object');
    body = parsed;
  } catch {
    return reply(400, { error: 'invalid_request' });
  }

  const phone = typeof body.phone === 'string' && body.phone.length <= 32 ? body.phone.replace(/\D/g, '') : '';
  if (!/^\d{8,15}$/.test(phone)) return reply(400, { error: 'invalid_request' });

  const ctx: Context = { url: (Deno.env.get('SUPABASE_URL') ?? '').replace(/\/+$/, ''), key: secretKey(), ip: clientIp(req) };
  if (!ctx.url || !ctx.key) {
    console.error('phone-auth: SUPABASE_URL ou chave secreta ausente');
    return reply(503, { error: 'unavailable' });
  }

  try {
    switch (body.action) {
      case 'login': {
        const password = body.password;
        if (typeof password !== 'string' || password.length < 1 || password.length > 256) return reply(400, { error: 'invalid_request' });
        return await login(ctx, phone, password);
      }
      case 'recover':
        return await recover(ctx, phone);
      case 'verify_recovery': {
        const code = body.code;
        if (typeof code !== 'string' || !/^\d{6,10}$/.test(code)) return reply(400, { error: 'invalid_request' });
        return await verifyRecovery(ctx, phone, code);
      }
      default:
        return reply(400, { error: 'invalid_request' });
    }
  } catch (error) {
    // Só o tipo do erro: a mensagem pode conter a URL ou dados da requisição.
    console.error(`phone-auth ${String(body.action)}: ${error instanceof Error ? error.name : 'erro'}`);
    return reply(503, { error: 'unavailable' });
  }
}
