import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/models.dart';
import '../main.dart';
import '../widgets/venexus_shell.dart';

class CartilhaScreen extends StatelessWidget {
  const CartilhaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rights = appState.cartilha.where((item) => item.type == CartilhaType.rights).toList();
    final expressions = appState.cartilha.where((item) => item.type == CartilhaType.expressions).toList();

    return VenexusShell(
      title: appState.t('cartilha.title'),
      currentIndex: 1,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const BackAction(),
          PageIntro(
            title: appState.t('cartilha.title'),
            description: appState.language == AppLanguage.es
                ? 'Orientaciones laborales y expresiones útiles en portugués y español.'
                : 'Orientações trabalhistas e expressões úteis em português e espanhol.',
            accentColor: AppColors.red,
          ),
          const SizedBox(height: 18),
          _SectionHeader(title: appState.t('cartilha.rights'), color: AppColors.red),
          const SizedBox(height: 10),
          if (appState.isAdmin) _PublishCartilhaForm(type: CartilhaType.rights) else InlineNotice(title: 'Perfil de consulta', text: appState.t('cartilha.onlyAdmin'), accentColor: AppColors.blue),
          const SizedBox(height: 12),
          ...rights.map((item) => _CartilhaCard(item: item, color: AppColors.red)),
          const SizedBox(height: 18),
          _SectionHeader(title: appState.t('cartilha.expressions'), color: AppColors.blue),
          const SizedBox(height: 10),
          if (appState.isAdmin) _PublishCartilhaForm(type: CartilhaType.expressions),
          const SizedBox(height: 12),
          ...expressions.map((item) => _CartilhaCard(item: item, color: AppColors.blue)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.color});
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color));
  }
}

class _CartilhaCard extends StatelessWidget {
  const _CartilhaCard({required this.item, required this.color});

  final CartilhaContent item;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = appState.language == AppLanguage.es ? item.textEs : item.textPt;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SectionCard(
        accentColor: color,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.purple, height: 1.25))),
                if (item.createdByName == 'Equipe SENAI') ...[const SizedBox(width: 8), const AdminBadge()],
              ],
            ),
            const SizedBox(height: 10),
            Text(text, style: const TextStyle(height: 1.65, color: AppColors.gray600)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AppColors.gray50,
                border: Border(left: BorderSide(color: AppColors.yellow, width: 4)),
              ),
              child: Text(item.explanation, style: const TextStyle(color: AppColors.gray700, fontWeight: FontWeight.w600, height: 1.5)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PublishCartilhaForm extends StatefulWidget {
  const _PublishCartilhaForm({required this.type});

  final CartilhaType type;

  @override
  State<_PublishCartilhaForm> createState() => _PublishCartilhaFormState();
}

class _PublishCartilhaFormState extends State<_PublishCartilhaForm> {
  final _title = TextEditingController();
  final _pt = TextEditingController();
  final _es = TextEditingController();
  final _explanation = TextEditingController();
  bool _open = false;

  @override
  void dispose() {
    _title.dispose();
    _pt.dispose();
    _es.dispose();
    _explanation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty || _pt.text.trim().isEmpty || _es.text.trim().isEmpty) return;
    final error = await appState.addCartilhaContent(
      type: widget.type,
      title: _title.text,
      textPt: _pt.text,
      textEs: _es.text,
      explanation: _explanation.text,
    );
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    _title.clear();
    _pt.clear();
    _es.clear();
    _explanation.clear();
    setState(() => _open = false);
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      accentColor: AppColors.yellow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(onPressed: () => setState(() => _open = !_open), icon: const Icon(Icons.add), label: Text(appState.t('cartilha.publish'))),
          if (_open) ...[
            const SizedBox(height: 12),
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'Título')),
            const SizedBox(height: 10),
            TextField(controller: _pt, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Texto em português')),
            const SizedBox(height: 10),
            TextField(controller: _es, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Texto em espanhol')),
            const SizedBox(height: 10),
            TextField(controller: _explanation, minLines: 2, maxLines: 3, decoration: const InputDecoration(labelText: 'Explicação prática')),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _submit, child: Text(appState.t('common.save').toUpperCase())),
          ],
        ],
      ),
    );
  }
}
