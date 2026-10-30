
#!/usr/bin/env bash
set -euo pipefail

echo "===================================="
echo " Flutter Web - Vercel Build"
echo "===================================="

# Configurações
FLUTTER_VERSION="${FLUTTER_VERSION:-stable}"
FLUTTER_DIR="/tmp/flutter"

# Instala Flutter SDK
echo "[1/5] Instalando Flutter SDK..."

if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  git clone \
    --depth 1 \
    --branch "$FLUTTER_VERSION" \
    https://github.com/flutter/flutter.git \
    "$FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"

flutter --version
flutter config --enable-web

# Gera arquivo .env
echo "[2/5] Configurando variáveis de ambiente..."

: "${SUPABASE_URL:?SUPABASE_URL não configurada na Vercel}"
: "${SUPABASE_ANON_KEY:?SUPABASE_ANON_KEY não configurada na Vercel}"

# Arquivo temporário contendo somente configurações públicas
umask 077
printf 'SUPABASE_URL=%s\nSUPABASE_ANON_KEY=%s\n' \
  "$SUPABASE_URL" \
  "$SUPABASE_ANON_KEY" > .env

# Instala dependências
echo "[3/5] Instalando dependências..."
flutter pub get

# Compila Flutter Web
echo "[4/5] Compilando para produção..."
flutter build web \
  --release \
  --no-wasm-dry-run

# Validação final
echo "[5/5] Validando build..."

if [ ! -f "build/web/index.html" ]; then
  echo "ERRO: build/web/index.html não encontrado."
  exit 1
fi

echo "===================================="
echo " Build concluído com sucesso!"
echo " Diretório: build/web"
echo "===================================="
