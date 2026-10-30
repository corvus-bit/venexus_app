import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/models.dart';
import '../core/permissions.dart';
import '../main.dart';
import '../widgets/form_fields.dart';
import '../widgets/venexus_shell.dart';

class SenaiScreen extends StatefulWidget {
  const SenaiScreen({super.key});

  @override
  State<SenaiScreen> createState() => _SenaiScreenState();
}

class _SenaiScreenState extends State<SenaiScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  static String _fold(String value) {
    const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const to = 'aaaaaeeeeiiiiooooouuuucn';
    final lower = value.toLowerCase();
    final buffer = StringBuffer();
    for (final char in lower.split('')) {
      final index = from.indexOf(char);
      buffer.write(index == -1 ? char : to[index]);
    }
    return buffer.toString();
  }

  Future<void> _deleteCourse(SenaiCourse course) async {
    final confirmed = await confirmDelete(context, title: appState.t('senai.deleteTitle'), message: appState.t('senai.deleteMessage'));
    if (!confirmed || !mounted) return;
    final error = await appState.deleteCourse(course);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? appState.t('senai.deleted'))));
  }

  @override
  Widget build(BuildContext context) {
    final query = _fold(_search.text.trim());
    final courses = query.isEmpty
        ? appState.courses
        : appState.courses.where((course) => _fold('${course.name} ${course.description} ${course.institutionAddress}').contains(query)).toList();
    return VenexusShell(
      title: appState.t('senai.title'),
      currentIndex: 3,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const BackAction(),
          PageIntro(
            title: appState.t('senai.title'),
            description: 'Cursos, capacitações e endereço de atendimento presencial do SENAI.',
            accentColor: AppColors.green,
          ),
          const SizedBox(height: 16),
          if (appState.isAdmin) const _CourseForm() else InlineNotice(title: 'Perfil de consulta', text: appState.t('senai.onlyAdmin'), accentColor: AppColors.blue),
          const SizedBox(height: 16),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              labelText: appState.t('senai.searchPlaceholder'),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: appState.t('common.close'),
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(_search.clear),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          if (courses.isEmpty && query.isNotEmpty)
            InlineNotice(title: appState.t('common.search'), text: appState.t('senai.searchEmpty'), accentColor: AppColors.red),
          ...courses.map((course) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SectionCard(
                  accentColor: AppColors.green,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(border: Border.fromBorderSide(BorderSide(color: AppColors.green))),
                            child: const Icon(Icons.work_outline, color: AppColors.green),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Expanded(child: Text(course.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.purple, height: 1.25))),
                                  const SizedBox(width: 8),
                                  const AdminBadge(),
                                  if (canDeleteCourse(appState.currentUser)) DeleteIconButton(onPressed: () => _deleteCourse(course)),
                                ]),
                                const SizedBox(height: 8),
                                Text(course.description, style: const TextStyle(color: AppColors.gray600, height: 1.65)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: AppColors.gray50,
                          border: Border(left: BorderSide(color: AppColors.yellow, width: 4)),
                        ),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Icon(Icons.location_on_outlined, size: 18, color: AppColors.blue),
                          const SizedBox(width: 8),
                          Expanded(child: Text(course.institutionAddress, style: const TextStyle(color: AppColors.gray600, fontWeight: FontWeight.w600, height: 1.5))),
                        ]),
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

class _CourseForm extends StatefulWidget {
  const _CourseForm();

  @override
  State<_CourseForm> createState() => _CourseFormState();
}

class _CourseFormState extends State<_CourseForm> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _address = TextEditingController(text: 'Rua Xingu, 833 - Amadori, Pato Branco - PR');
  bool _open = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty || _description.text.trim().isEmpty) return;
    final error = await appState.addCourse(name: _name.text, description: _description.text, address: _address.text);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    _name.clear();
    _description.clear();
    setState(() => _open = false);
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      accentColor: AppColors.yellow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(onPressed: () => setState(() => _open = !_open), icon: const Icon(Icons.add), label: Text(appState.t('senai.publish'))),
          if (_open) ...[
            const SizedBox(height: 12),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nome do curso')),
            const SizedBox(height: 10),
            TextField(controller: _description, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Descrição')),
            const SizedBox(height: 10),
            TextField(controller: _address, decoration: const InputDecoration(labelText: 'Endereço')),
            const SizedBox(height: 12),
            AsyncButton(label: appState.t('common.save').toUpperCase(), onPressed: _submit),
          ],
        ],
      ),
    );
  }
}
