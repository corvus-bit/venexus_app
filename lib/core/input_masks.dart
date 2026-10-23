import 'package:flutter/services.dart';

import 'permissions.dart';

/// Tamanho do código enviado pelo Supabase Auth (Authentication > Providers > Email > Email OTP Length).
const otpLength = 6;

const passwordMinLength = 6;

const _phoneMaxDigits = 11;

final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

/// Formata telefone brasileiro com DDD: (46) 9999-0000 ou (46) 99999-0000.
/// Valores fora do padrão (ex.: com DDI salvo antes da máscara) voltam só com os dígitos.
String formatPhone(String phone) {
  final digits = normalizePhone(phone);
  if (digits.length > _phoneMaxDigits) return digits;
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i == 0) buffer.write('(');
    if (i == 2) buffer.write(') ');
    // O hífen fica depois do 4º dígito do número fixo e do 5º do celular.
    if (i == (digits.length == _phoneMaxDigits ? 7 : 6)) buffer.write('-');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

bool isValidPhone(String phone) {
  final length = normalizePhone(phone).length;
  return length == 10 || length == _phoneMaxDigits;
}

bool isValidEmail(String email) => _emailPattern.hasMatch(normalizeEmail(email));

class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = normalizePhone(newValue.text);
    // Apagar um caractere da máscara (parêntese, espaço ou hífen) apaga o dígito anterior.
    if (newValue.text.length < oldValue.text.length && digits == normalizePhone(oldValue.text) && digits.isNotEmpty) {
      digits = digits.substring(0, digits.length - 1);
    }
    if (digits.length > _phoneMaxDigits) digits = digits.substring(0, _phoneMaxDigits);
    final text = formatPhone(digits);
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

/// E-mail sem espaços e em minúsculas enquanto a pessoa digita.
class EmailInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll(RegExp(r'\s'), '').toLowerCase();
    if (text == newValue.text) return newValue;
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
