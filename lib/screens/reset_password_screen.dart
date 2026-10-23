import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../widgets/venexus_shell.dart';

const _resendCooldownSeconds = 60;

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({required this.phone, super.key});

  final String phone;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
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
    _password.dispose();
    _confirm.dispose();
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
    final error = await appState.requestPasswordReset(phone: widget.phone);
    if (!mounted) return;
    setState(() => _resending = false);
    if (error != null) {
      _showMessage(error);
      return;
    }
    _showMessage(appState.t('auth.resetCodeSent'));
    _startCooldown();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final error = await appState.resetPasswordWithCode(
      phone: widget.phone,
      code: _code.text,
      newPassword: _password.text,
      confirmPassword: _confirm.text,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (error != null) {
      _showMessage(error);
      return;
    }
    _showMessage(appState.t('auth.resetSuccess'));
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final canResend = _resendIn <= 0 && !_resending;
    return AuthFrame(
      title: appState.t('auth.resetTitle'),
      subtitle: appState.t('auth.resetSubtitle'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _code,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 8),
            decoration: InputDecoration(labelText: appState.t('auth.resetCode')),
          ),
          const SizedBox(height: 12),
          TextFormField(controller: _password, obscureText: true, decoration: InputDecoration(labelText: appState.t('profile.newPassword'))),
          const SizedBox(height: 12),
          TextFormField(controller: _confirm, obscureText: true, decoration: InputDecoration(labelText: appState.t('profile.confirmPassword'))),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(appState.t('auth.resetSubmit').toUpperCase()),
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
