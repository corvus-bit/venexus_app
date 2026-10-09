import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  static String get url {
    const dartDefineValue = String.fromEnvironment('SUPABASE_URL');
    if (dartDefineValue.isNotEmpty) return dartDefineValue;
    return dotenv.env['SUPABASE_URL'] ?? '';
  }

  static String get anonKey {
    const dartDefineValue = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (dartDefineValue.isNotEmpty) return dartDefineValue;
    return dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  }

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  static void assertConfigured() {
    if (!isConfigured) {
      throw StateError(
        'Supabase não configurado. Preencha SUPABASE_URL e SUPABASE_ANON_KEY no arquivo .env.',
      );
    }
  }
}
