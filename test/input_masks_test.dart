import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venexus/core/input_masks.dart';

TextEditingValue _type(TextInputFormatter formatter, String oldText, String newText) {
  return formatter.formatEditUpdate(TextEditingValue(text: oldText), TextEditingValue(text: newText));
}

void main() {
  group('input masks', () {
    test('formats mobile and landline phones', () {
      expect(formatPhone('46999990000'), '(46) 99999-0000');
      expect(formatPhone('4632220000'), '(46) 3222-0000');
      expect(formatPhone('469'), '(46) 9');
      expect(formatPhone('5546999990000'), '5546999990000');
    });

    test('phone formatter caps digits and deletes across mask characters', () {
      final formatter = PhoneInputFormatter();
      expect(_type(formatter, '', '469999900001').text, '(46) 99999-0000');
      expect(_type(formatter, '(46) 9', '(46) ').text, '(46');
      expect(_type(formatter, '(46) 9999-0', '(46) 9999-').text, '(46) 9999');
    });

    test('validates phone and e-mail', () {
      expect(isValidPhone('(46) 99999-0000'), isTrue);
      expect(isValidPhone('(46) 9999-000'), isFalse);
      expect(isValidEmail('pessoa@exemplo.com'), isTrue);
      expect(isValidEmail('pessoa@exemplo'), isFalse);
    });

    test('e-mail formatter strips spaces and lowercases', () {
      expect(_type(EmailInputFormatter(), '', ' Pessoa@Exemplo.COM ').text, 'pessoa@exemplo.com');
    });
  });
}
