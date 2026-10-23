import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_theme.dart';
import '../main.dart';
import '../widgets/venexus_shell.dart';

const _resendCooldownSeconds = 60;

/// Confirmação do cadastro pelo código enviado no e-mail (Supabase "Confirm email" ligado).
class ConfirmEmailScreen extends StatefulWidget {
  const ConfirmEmailScreen({super.key});

  @override
  State<ConfirmEmailScreen> createState() => _ConfirmEmailScreenState();
}

class _ConfirmEmailScreenState extends State<ConfirmEmailScreen> {
  final _code = TextEditingController();
  bool _submitting = false;
  bool _resending = false;
  int _resendIn = _resendCooldownSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _resendIn = _resendCooldownSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendIn <= 1) timer.cancel();
      setState(() => _resendIn--);
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    final error = await appState.resendSignUpCode();
    if (!mounted) return;
    setState(() => _resending = false);
    if (error != null) {
      _showMessage(error);
      return;
    }
    _showMessage(appState.t('auth.confirmCodeSent'));
    _startCooldown();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final error = await appState.confirmSignUp(code: _code.text);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (error != null) {
      _showMessage(error);
      return;
    }
    Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final canResend = _resendIn <= 0 && !_resending;
    final email = appState.pendingConfirmationEmail ?? '';
    return AuthFrame(
      title: appState.t('auth.confirmTitle'),
      subtitle: '${appState.t('auth.confirmSubtitle')} $email',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _code,
            autofocus: true,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 8),
            decoration: InputDecoration(labelText: appState.t('auth.resetCode')),
            onFieldSubmitted: (_) => _submitting ? null : _submit(),
          ),
          const SizedBox(height: 8),
          Text(appState.t('auth.confirmSpamHint'), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.gray600, fontSize: 13)),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(appState.t('auth.confirmSubmit').toUpperCase()),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: canResend ? _resend : null,
            child: Text(_resendIn > 0 ? '${appState.t('auth.resetResendIn')} ${_resendIn}s' : appState.t('auth.resetResend')),
          ),
          TextButton(onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false), child: Text(appState.t('auth.backLogin'))),
        ],
      ),
    );
  }
}
