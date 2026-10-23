import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:venexus/core/models.dart';

void main() {
  group('device language', () {
    test('uses Spanish when the device prefers Spanish', () {
      expect(languageFromLocales(const [Locale('es', 'VE')]), AppLanguage.es);
    });

    test('uses Portuguese when the device prefers Portuguese', () {
      expect(languageFromLocales(const [Locale('pt', 'BR')]), AppLanguage.ptBR);
    });

    test('picks the first supported language in the device list', () {
      expect(languageFromLocales(const [Locale('en', 'US'), Locale('es')]), AppLanguage.es);
    });

    test('falls back to Portuguese when no language is supported', () {
      expect(languageFromLocales(const [Locale('en', 'US')]), AppLanguage.ptBR);
      expect(languageFromLocales(const []), AppLanguage.ptBR);
    });
  });
}
