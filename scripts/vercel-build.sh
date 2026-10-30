
#!/usr/bin/env bash
set -e

# Instala o Flutter SDK
git clone https://github.com/flutter/flutter.git \
  --depth 1 \
  --branch stable \
  /tmp/flutter

export PATH="/tmp/flutter/bin:$PATH"

# Prepara o ambiente
flutter config --enable-web
flutter pub get

# Compila para produção
flutter build web --release
