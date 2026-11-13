import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../main.dart';
import '../widgets/form_fields.dart';
import '../widgets/venexus_shell.dart';

/// Conta autenticada na plataforma, mas sem vínculo ativo com o Venexus: criada por outro
/// aplicativo (pode entrar aceitando o termo) ou com o acesso pendente/revogado.
class JoinVenexusScreen extends StatefulWidget {
  const JoinVenexusScreen({super.key});

  @override
  State<JoinVenexusScreen> createState() => _JoinVenexusScreenState();
}

class _JoinVenexusScreenState extends State<JoinVenexusScreen> {
  bool _lgpdAccepted = false;
  bool _loading = false;

  Future<void> _join() async {
    setState(() => _loading = true);
    final error = await appState.joinVenexus(lgpdAccepted: _lgpdAccepted);
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
  }

  Future<void> _logout() async {
    await appState.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final status = appState.venexusMembershipStatus;
    final canJoin = status == null;
    return AuthFrame(
      title: 'Venexus',
      subtitle: appState.t(switch (status) {
        null => 'access.joinSubtitle',
        'pending' => 'access.pending',
        _ => 'access.revoked',
      }),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (canJoin) ...[
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
            AsyncButton(label: appState.t('access.join').toUpperCase(), loading: _loading, onPressed: _join),
            const SizedBox(height: 6),
          ],
          TextButton(onPressed: _logout, child: Text(appState.t('layout.logout'))),
        ],
      ),
    );
  }
}
