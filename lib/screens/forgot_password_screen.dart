import 'package:flutter/material.dart';

import '../main.dart';
import '../widgets/form_fields.dart';
import '../widgets/venexus_shell.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    final phone = _phone.text.trim();
    setState(() => _sending = true);
    final error = await appState.requestPasswordReset(phone: phone);
    if (!mounted) return;
    setState(() => _sending = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appState.t('auth.resetCodeSent'))));
    Navigator.pushNamed(context, '/reset-password', arguments: phone);
  }

  @override
  Widget build(BuildContext context) {
    return AuthFrame(
      title: appState.t('auth.forgotPassword'),
      subtitle: appState.t('auth.forgotSubtitle'),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PhoneField(
              controller: _phone,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _sending ? null : _continue(),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _sending ? null : _continue,
              child: _sending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(appState.t('auth.sendCode').toUpperCase()),
            ),
            const SizedBox(height: 6),
            TextButton(onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false), child: Text(appState.t('auth.backLogin'))),
          ],
        ),
      ),
    );
  }
}
