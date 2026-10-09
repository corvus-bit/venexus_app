import 'package:flutter_test/flutter_test.dart';
import 'package:venexus/core/models.dart';
import 'package:venexus/core/permissions.dart';

void main() {
  group('permissions', () {
    test('normalizes phone numbers', () {
      expect(normalizePhone('+55 (46) 99999-0000'), '5546999990000');
    });

    test('normalizes e-mail addresses', () {
      expect(normalizeEmail('  Usuario@Exemplo.COM  '), 'usuario@exemplo.com');
    });

    test('maps institutional domain to admin', () {
      expect(roleFromEmail('pessoa@sistemafiep.org.br'), UserRole.admin);
      expect(roleFromEmail('pessoa@example.com'), UserRole.reader);
    });
  });
}
