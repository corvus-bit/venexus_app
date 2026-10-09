# Venexus Flutter — Android

Aplicativo Flutter Android do Venexus, integrado ao Supabase.

## Requisitos

- Flutter compatível com o `pubspec.lock`;
- Dart `>= 3.10.3 < 4.0.0`;
- Android SDK configurado;
- JDK 17 ou superior compatível com a instalação do Flutter;
- dispositivo físico com depuração USB ou emulador Android.

Valide o ambiente:

```bash
flutter doctor -v
flutter --version
dart --version
```

## Configuração do Supabase

O arquivo `.env` deve conter somente as credenciais públicas do cliente:

```env
SUPABASE_URL=https://SEU-PROJECT-REF.supabase.co
SUPABASE_ANON_KEY=SUA_ANON_OU_PUBLISHABLE_KEY
```

Não inclua senha do banco, `service_role`, chave secreta ou string de conexão PostgreSQL.

Aplique o schema no SQL Editor do Supabase:

```text
supabase/schema.sql
```

Para o fluxo atual de cadastro e login:

```text
Authentication > Sign In / Providers > Email
Email provider: Enabled
```

O aplicativo apresenta telefone e senha, mas autentica no Supabase Auth por e-mail e senha depois de localizar o perfil pelo telefone.

## Executar

Na pasta `venexus_flutter`:

```bash
flutter clean
flutter pub get
flutter run
```

Para selecionar explicitamente um dispositivo:

```bash
flutter devices
flutter run -d ID_DO_DISPOSITIVO
```

## Validar

```bash
flutter analyze
flutter test
flutter build apk --debug
```

APK de debug:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

## Observações

- O target restaurado neste pacote é Android. Não há configuração Web ou iOS.
- O `applicationId` e o namespace são `br.app.venexus`.
- O build `release` ainda usa assinatura de debug para permitir validação local. Configure um keystore próprio antes de publicar na Play Store.
- A permissão de internet está declarada no manifest principal.
- Os arquivos `android/gradlew`, `android/gradlew.bat` e `android/gradle/wrapper/gradle-wrapper.jar` devem permanecer versionados.
