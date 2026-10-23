import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/models.dart';
import '../main.dart';
import '../widgets/form_fields.dart';
import '../widgets/venexus_shell.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _password = TextEditingController();
  bool _lgpdAccepted = false;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final error = await appState.register(
      name: _name.text,
      phone: _phone.text,
      email: _email.text,
      address: _address.text,
      password: _password.text,
      lgpdAccepted: _lgpdAccepted,
    );
    if (mounted) setState(() => _loading = false);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    if (appState.pendingConfirmationEmail != null) {
      Navigator.pushReplacementNamed(context, '/confirm-email');
      return;
    }
    Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return AuthFrame(
      title: appState.t('auth.registerTitle'),
      subtitle: appState.language == AppLanguage.es ? 'Crea tu acceso para usar Venexus con seguridad.' : 'Crie seu acesso para usar o Venexus com segurança.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _field(_name, appState.t('auth.name')),
            _spaced(PhoneField(controller: _phone, textInputAction: TextInputAction.next)),
            _spaced(EmailField(controller: _email, textInputAction: TextInputAction.next)),
            _field(_address, appState.t('auth.address')),
            _spaced(PasswordField(controller: _password, label: appState.t('auth.password'), isNewPassword: true)),
            const SizedBox(height: 4),
            Container(
              decoration: const BoxDecoration(
                color: AppColors.gray50,
                border: Border(left: BorderSide(color: AppColors.yellow, width: 4)),
              ),
              padding: const EdgeInsets.all(12),
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _lgpdAccepted,
                activeColor: AppColors.blue,
                onChanged: (value) => setState(() => _lgpdAccepted = value ?? false),
                title: Text(appState.t('auth.lgpdTitle'), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.purple)),
                subtitle: Text(appState.t('auth.lgpdText'), style: const TextStyle(color: AppColors.gray600, height: 1.5)),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(onPressed: _loading ? null : _submit, child: Text(_loading ? '...' : appState.t('auth.finish').toUpperCase())),
            const SizedBox(height: 6),
            TextButton(onPressed: () => Navigator.pop(context), child: Text(appState.t('auth.backLogin'))),
          ],
        ),
      ),
    );
  }

  Widget _spaced(Widget child) => Padding(padding: const EdgeInsets.only(bottom: 12), child: child);

  Widget _field(TextEditingController controller, String label) {
    return _spaced(
      TextFormField(
        controller: controller,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(labelText: label),
        validator: (value) => value == null || value.trim().isEmpty ? appState.t('common.required') : null,
      ),
    );
  }
}
