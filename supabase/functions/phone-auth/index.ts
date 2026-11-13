// Publicar SEM verificação de JWT: a função roda antes do login e o app usa chave publishable
// (que não é um JWT).
//
//   supabase functions deploy phone-auth --no-verify-jwt

import { handler } from './handler.ts';

Deno.serve(handler);
