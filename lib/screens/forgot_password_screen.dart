import 'package:flutter/material.dart';

import '../main.dart';
import '../widgets/venexus_shell.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _phone = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_phone.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appState.t('common.required'))));
      return;
    }
    final error = await appState.requestPasswordReset(phone: _phone.text.trim());
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link de recuperação enviado para o e-mail cadastrado.')),
    );
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return AuthFrame(
      title: appState.t('auth.forgotPassword'),
      subtitle: appState.language.name == 'es' ? 'Informe seu teléfono para continuar con la recuperación.' : 'Informe seu telefone. O link de recuperação será enviado para o e-mail cadastrado.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: appState.t('auth.phone'))),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _continue, child: Text((appState.language.name == 'es' ? 'Continuar' : 'Continuar').toUpperCase())),
          const SizedBox(height: 6),
          TextButton(onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false), child: Text(appState.t('auth.backLogin'))),
        ],
      ),
    );
  }
}
