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

Aplique as migrations de `supabase/migrations/` em ordem (SQL Editor ou `supabase db push`) e publique a Edge Function `phone-auth`. A ordem de implantação, as configurações manuais e o modelo de acesso estão em [supabase/README.md](supabase/README.md).

Para o fluxo atual de cadastro e login:

```text
Authentication > Sign In / Providers > Email
Email provider: Enabled
```

O aplicativo apresenta telefone e senha, mas autentica no Supabase Auth por e-mail e senha. O e-mail da conta é resolvido no servidor pela Edge Function `phone-auth`: o app nunca recebe o e-mail de um telefone sem provar a senha.

### Segurança do banco

O projeto Supabase é compartilhado com outros aplicativos: a identidade (`auth.users` + `public.profiles`) é única, e o acesso é por aplicativo. Pontos importantes:

- O conteúdo do Venexus exige **vínculo ativo** com o aplicativo `venexus` (`platform.app_memberships`). Estar autenticado na plataforma não basta.
- **Admin do Venexus** = vínculo com papel `admin`, verificado por `public.is_admin()`. Quem tem e-mail do Auth **confirmado** em `@sistemafiep.org.br` recebe esse papel automaticamente; isso vale só dentro do Venexus e não é administração da plataforma.
- O e-mail e o papel nunca vêm do cliente: o metadata do cadastro é validado campo a campo, e o app só altera os dados pessoais do próprio perfil.
- O nome e o papel do autor de publicações e comentários são preenchidos pelo banco (triggers `posts_set_author` e `comments_set_author`).
- As RPCs `login_email_for_phone`, `phone_in_use` e `email_in_use` são **removidas** na última migration. Versões do APK anteriores a esta mudança deixam de conseguir entrar: publique o app novo antes dela.

### Recuperação de senha

O fluxo "Esqueci minha senha" usa o Supabase Auth com **código de verificação** (OTP), sem link nem deep link:

1. o usuário informa o telefone; o app chama a Edge Function `phone-auth` (`recover`), que pede o e-mail de recuperação ao Auth e responde igual havendo ou não conta;
2. o Supabase envia o e-mail com o código;
3. o usuário digita o código e a nova senha; a função valida o código no Auth (`verify_recovery`) e devolve a sessão de recuperação; o app chama `updateUser` e encerra a sessão para o login com a nova senha.

Configuração no Dashboard:

```text
Authentication > Emails > Templates > Reset Password
  Subject: {{ $es := false }}{{ if .Data.language }}{{ if eq .Data.language "es" }}{{ $es = true }}{{ end }}{{ end }}{{ if $es }}Tu código de recuperación Venexus{{ else }}Seu código de recuperação Venexus{{ end }}
  Message body: conteúdo de supabase/templates/reset_password.html

Authentication > Emails > Templates > Confirm signup
  Subject: {{ $es := false }}{{ if .Data.language }}{{ if eq .Data.language "es" }}{{ $es = true }}{{ end }}{{ end }}{{ if $es }}Confirma tu cuenta Venexus{{ else }}Confirme sua conta Venexus{{ end }}
  Message body: conteúdo de supabase/templates/confirm_signup.html
```

O template precisa usar `{{ .Token }}` (o código), não `{{ .ConfirmationURL }}`. O texto do e-mail informa validade de 1 hora: mantenha `Authentication > Providers > Email > Email OTP Expiration` em `3600` ou ajuste o template. O app espera códigos de **8 dígitos**: configure `Email OTP Length` com `8` (constante `otpLength` em `lib/core/input_masks.dart`).

Se o template tiver qualquer erro ao ser processado, o Supabase descarta o template personalizado **sem avisar** e envia o padrão (com link). O motivo aparece em `Logs > Auth` (eventos `templatemailer_template_body_parse_error` e parecidos). Por isso os templates só comparam `.Data.language` depois de verificar que ele existe, e o comentário HTML do topo não tem nenhuma ação `{{ }}`: o Supabase executa o template inteiro, comentários inclusive.

O SMTP padrão do Supabase tem limite baixo de envios por hora e serve apenas para testes. Em produção, configure um SMTP próprio em `Authentication > Emails > SMTP Settings`.

## Executar

Na raiz do projeto:

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

Banco e Edge Function (não precisam de Docker nem de projeto Supabase):

```bash
cd supabase/tests && npm install && npm test
deno test --allow-env supabase/functions/phone-auth/
```

APK de debug:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

## Observações

- Alvos: Android (APK pelo workflow `android-release.yml`) e Web (build na Vercel por `scripts/vercel-build.sh`). Não há configuração iOS.
- No build Web, o `.env` vai junto como asset e fica público: ele deve conter só a URL e a chave pública (anon/publishable).
- O `applicationId` e o namespace são `com.venexus.app`.
- Sem `android/key.properties`, o build `release` usa a assinatura de debug para permitir validação local. No CI, o keystore vem dos secrets `ANDROID_KEYSTORE_*`. `key.properties` e `*.jks` estão no `.gitignore`: nunca versione a chave.
- O workflow `ci.yml` roda `flutter analyze` e `flutter test` em cada pull request e push na `main`.
- A permissão de internet está declarada no manifest principal.
- Os arquivos `android/gradlew`, `android/gradlew.bat` e `android/gradle/wrapper/gradle-wrapper.jar` devem permanecer versionados.
