import 'package:flutter/material.dart';

import '../main.dart';
import '../widgets/venexus_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final error = await appState.login(phone: _phone.text, password: _password.text);
    if (mounted) setState(() => _loading = false);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return AuthFrame(
      title: appState.t('auth.loginTitle'),
      subtitle: appState.t('auth.loginSubtitle'),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: appState.t('auth.phone')),
              validator: (value) => value == null || value.trim().isEmpty ? appState.t('common.required') : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(labelText: appState.t('auth.password')),
              validator: (value) => value == null || value.trim().isEmpty ? appState.t('common.required') : null,
            ),
            const SizedBox(height: 18),
            ElevatedButton(onPressed: _loading ? null : _submit, child: Text(_loading ? '...' : appState.t('auth.enter').toUpperCase())),
            const SizedBox(height: 6),
            TextButton(onPressed: () => Navigator.pushNamed(context, '/forgot-password'), child: Text(appState.t('auth.forgotPassword'))),
            const SizedBox(height: 6),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(appState.t('auth.noAccount')),
                TextButton(onPressed: () => Navigator.pushNamed(context, '/register'), child: Text(appState.t('auth.registerLink'))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
