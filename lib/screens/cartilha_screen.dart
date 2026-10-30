import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/models.dart';
import '../core/permissions.dart';
import '../main.dart';
import '../widgets/form_fields.dart';
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
            description: appState.t('cartilha.description'),
            accentColor: AppColors.red,
          ),
          const SizedBox(height: 18),
          _SectionHeader(title: appState.t('cartilha.rights'), color: AppColors.red),
          const SizedBox(height: 10),
          if (appState.isAdmin) _PublishCartilhaForm(type: CartilhaType.rights) else InlineNotice(title: appState.t('common.consultProfile'), text: appState.t('cartilha.onlyAdmin'), accentColor: AppColors.blue),
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

  Future<void> _delete(BuildContext context) async {
    final confirmed = await confirmDelete(context, title: appState.t('cartilha.deleteTitle'), message: appState.t('cartilha.deleteMessage'));
    if (!confirmed || !context.mounted) return;
    final error = await appState.deleteCartilhaContent(item);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? appState.t('cartilha.deleted'))));
  }

  @override
  Widget build(BuildContext context) {
    final text = appState.language == AppLanguage.es ? item.textEs : item.textPt;
    final title = item.titleFor(appState.language);
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.purple, height: 1.25)),
                      // Em espanhol, a expressão original em português continua visível para o aprendizado.
                      if (item.type == CartilhaType.expressions && title != item.title) ...[
                        const SizedBox(height: 4),
                        Text('PT: ${item.title}', style: const TextStyle(color: AppColors.blue, fontSize: 13, fontWeight: FontWeight.w700, fontStyle: FontStyle.italic)),
                      ],
                    ],
                  ),
                ),
                if (item.createdByName == 'Equipe SENAI') ...[const SizedBox(width: 8), const AdminBadge()],
                if (canDeleteCartilha(appState.currentUser)) DeleteIconButton(onPressed: () => _delete(context)),
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
              child: Text(item.explanationFor(appState.language), style: const TextStyle(color: AppColors.gray700, fontWeight: FontWeight.w600, height: 1.5)),
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
  final _titleEs = TextEditingController();
  final _pt = TextEditingController();
  final _es = TextEditingController();
  final _explanation = TextEditingController();
  final _explanationEs = TextEditingController();
  bool _open = false;

  @override
  void dispose() {
    _title.dispose();
    _titleEs.dispose();
    _pt.dispose();
    _es.dispose();
    _explanation.dispose();
    _explanationEs.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty || _titleEs.text.trim().isEmpty || _pt.text.trim().isEmpty || _es.text.trim().isEmpty) return;
    final error = await appState.addCartilhaContent(
      type: widget.type,
      title: _title.text,
      titleEs: _titleEs.text,
      textPt: _pt.text,
      textEs: _es.text,
      explanation: _explanation.text,
      explanationEs: _explanationEs.text,
    );
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    _title.clear();
    _titleEs.clear();
    _pt.clear();
    _es.clear();
    _explanation.clear();
    _explanationEs.clear();
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
            TextField(controller: _title, decoration: InputDecoration(labelText: appState.t('cartilha.titlePt'))),
            const SizedBox(height: 10),
            TextField(controller: _titleEs, decoration: InputDecoration(labelText: appState.t('cartilha.titleEs'))),
            const SizedBox(height: 10),
            TextField(controller: _pt, minLines: 2, maxLines: 4, decoration: InputDecoration(labelText: appState.t('cartilha.textPt'))),
            const SizedBox(height: 10),
            TextField(controller: _es, minLines: 2, maxLines: 4, decoration: InputDecoration(labelText: appState.t('cartilha.textEs'))),
            const SizedBox(height: 10),
            TextField(controller: _explanation, minLines: 2, maxLines: 3, decoration: InputDecoration(labelText: appState.t('cartilha.explanationPt'))),
            const SizedBox(height: 10),
            TextField(controller: _explanationEs, minLines: 2, maxLines: 3, decoration: InputDecoration(labelText: appState.t('cartilha.explanationEs'))),
            const SizedBox(height: 12),
            AsyncButton(label: appState.t('common.save').toUpperCase(), onPressed: _submit),
          ],
        ],
      ),
    );
  }
}
