import 'package:flutter/material.dart';

import '../main.dart';
import '../widgets/venexus_shell.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({required this.phone, super.key});

  final String phone;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_password.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A senha deve ter pelo menos 6 caracteres.')));
      return;
    }
    if (_password.text != _confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A confirmação de senha não confere.')));
      return;
    }
    final error = await appState.completePasswordRecovery(newPassword: _password.text);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return AuthFrame(
      title: appState.t('auth.forgotPassword'),
      subtitle: widget.phone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(controller: _password, obscureText: true, decoration: InputDecoration(labelText: appState.t('profile.newPassword'))),
          const SizedBox(height: 12),
          TextFormField(controller: _confirm, obscureText: true, decoration: InputDecoration(labelText: appState.t('profile.confirmPassword'))),
          const SizedBox(height: 18),
          ElevatedButton(onPressed: _submit, child: Text(appState.t('profile.changePassword').toUpperCase())),
          const SizedBox(height: 6),
          TextButton(onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false), child: Text(appState.t('auth.backLogin'))),
        ],
      ),
    );
  }
}
