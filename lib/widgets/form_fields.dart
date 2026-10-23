import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_theme.dart';
import '../core/input_masks.dart';
import '../main.dart';

String? _requiredValidator(String? value) => value == null || value.trim().isEmpty ? appState.t('common.required') : null;

class PhoneField extends StatelessWidget {
  const PhoneField({required this.controller, this.textInputAction, this.onFieldSubmitted, super.key});

  final TextEditingController controller;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.phone,
      textInputAction: textInputAction,
      autofillHints: const [AutofillHints.telephoneNumberNational],
      inputFormatters: [PhoneInputFormatter()],
      onFieldSubmitted: onFieldSubmitted,
      decoration: InputDecoration(
        labelText: appState.t('auth.phone'),
        hintText: '(00) 00000-0000',
        prefixIcon: const Icon(Icons.phone_outlined),
      ),
      validator: (value) => _requiredValidator(value) ?? (isValidPhone(value!) ? null : appState.t('validation.phone')),
    );
  }
}

class EmailField extends StatelessWidget {
  const EmailField({required this.controller, this.readOnly = false, this.textInputAction, super.key});

  final TextEditingController controller;
  final bool readOnly;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: TextInputType.emailAddress,
      textInputAction: textInputAction,
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: TextCapitalization.none,
      autofillHints: const [AutofillHints.email],
      inputFormatters: [EmailInputFormatter()],
      decoration: InputDecoration(
        labelText: appState.t('auth.email'),
        hintText: 'nome@exemplo.com',
        prefixIcon: const Icon(Icons.alternate_email),
      ),
      validator: (value) => _requiredValidator(value) ?? (isValidEmail(value!) ? null : appState.t('validation.email')),
    );
  }
}

/// Senha mascarada com botão para mostrar/ocultar. [checkLength] valida o mínimo do Supabase Auth
/// (desligue no login, onde senhas antigas não devem ser barradas pelo app).
class PasswordField extends StatefulWidget {
  const PasswordField({
    required this.controller,
    required this.label,
    this.checkLength = true,
    this.matchController,
    this.isNewPassword = false,
    this.focusNode,
    this.textInputAction,
    this.onFieldSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final bool checkLength;

  /// Quando informado, o campo é a confirmação e precisa ser igual a este controller.
  final TextEditingController? matchController;
  final bool isNewPassword;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  String? _validate(String? value) {
    if (value == null || value.isEmpty) return appState.t('common.required');
    if (widget.matchController != null && value != widget.matchController!.text) return appState.t('validation.passwordMatch');
    if (widget.checkLength && value.length < passwordMinLength) return appState.t('validation.passwordMin');
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      obscureText: _obscure,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      autofillHints: [widget.isNewPassword ? AutofillHints.newPassword : AutofillHints.password],
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          tooltip: appState.t(_obscure ? 'validation.showPassword' : 'validation.hidePassword'),
          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
      validator: _validate,
    );
  }
}

/// Código de verificação em caixas separadas. Um único campo invisível recebe o texto,
/// então colar o código e o preenchimento automático do teclado continuam funcionando.
class OtpCodeField extends StatefulWidget {
  const OtpCodeField({required this.controller, this.label, this.autofocus = false, this.onCompleted, super.key});

  final TextEditingController controller;
  final String? label;
  final bool autofocus;
  final ValueChanged<String>? onCompleted;

  @override
  State<OtpCodeField> createState() => _OtpCodeFieldState();
}

class _OtpCodeFieldState extends State<OtpCodeField> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    if (value.length == otpLength) widget.onCompleted?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.label != null) ...[
          Text(widget.label!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.gray600, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
        ],
        Stack(
          children: [
            ListenableBuilder(
              listenable: Listenable.merge([widget.controller, _focusNode]),
              builder: (context, _) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < otpLength; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    _OtpBox(
                      digit: i < widget.controller.text.length ? widget.controller.text[i] : '',
                      active: _focusNode.hasFocus && i == widget.controller.text.length.clamp(0, otpLength - 1),
                    ),
                  ],
                ],
              ),
            ),
            Positioned.fill(
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                autofocus: widget.autofocus,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(otpLength)],
                onChanged: _onChanged,
                showCursor: false,
                style: const TextStyle(color: Colors.transparent, fontSize: 1),
                decoration: const InputDecoration.collapsed(hintText: null, filled: false),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OtpBox extends StatelessWidget {
  const _OtpBox({required this.digit, required this.active});

  final String digit;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final filled = digit.isNotEmpty;
    return Flexible(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 52),
        child: AspectRatio(
          aspectRatio: 0.85,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: filled ? const Color(0xFFFFF8E6) : AppColors.surface,
              border: Border.all(
                color: active ? AppColors.blue : (filled ? AppColors.yellow : AppColors.gray300),
                width: active ? 2 : 1.4,
              ),
              boxShadow: active ? AppShadows.md : null,
            ),
            child: Text(
              digit,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.purple, fontFeatures: [FontFeature.tabularFigures()]),
            ),
          ),
        ),
      ),
    );
  }
}
