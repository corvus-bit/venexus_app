import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/models.dart';
import '../main.dart';
import '../widgets/venexus_shell.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      _DashboardItem(
        icon: Icons.menu_book_outlined,
        title: appState.t('dashboard.cartilhaTitle') == 'dashboard.cartilhaTitle' ? appState.t('layout.cartilha') : appState.t('dashboard.cartilhaTitle'),
        description: appState.t('dashboard.cartilhaDesc') == 'dashboard.cartilhaDesc' ? 'Direitos trabalhistas, expressões e orientação em PT/ES.' : appState.t('dashboard.cartilhaDesc'),
        color: AppColors.red,
        route: '/cartilha',
      ),
      _DashboardItem(
        icon: Icons.forum_outlined,
        title: appState.t('dashboard.forumTitle') == 'dashboard.forumTitle' ? appState.t('layout.forum') : appState.t('dashboard.forumTitle'),
        description: appState.t('dashboard.forumDesc') == 'dashboard.forumDesc' ? 'Espaço para perguntas, experiências e acolhimento entre trabalhadores migrantes.' : appState.t('dashboard.forumDesc'),
        color: AppColors.yellow,
        route: '/forum',
      ),
      _DashboardItem(
        icon: Icons.work_outline,
        title: appState.t('dashboard.senaiTitle') == 'dashboard.senaiTitle' ? appState.t('layout.senai') : appState.t('dashboard.senaiTitle'),
        description: appState.t('dashboard.senaiDesc') == 'dashboard.senaiDesc' ? 'Cursos e endereço de atendimento presencial.' : appState.t('dashboard.senaiDesc'),
        color: AppColors.green,
        route: '/senai',
      ),
      _DashboardItem(
        icon: Icons.school_outlined,
        title: appState.t('dashboard.ejaTitle'),
        description: appState.t('dashboard.ejaDesc'),
        color: AppColors.blue,
        onTap: () => _showEja(context),
      ),
      _DashboardItem(
        icon: Icons.person_outline,
        title: appState.t('dashboard.profileTitle') == 'dashboard.profileTitle' ? appState.t('layout.profile') : appState.t('dashboard.profileTitle'),
        description: appState.t('dashboard.profileDesc') == 'dashboard.profileDesc' ? appState.t('profile.description') : appState.t('dashboard.profileDesc'),
        color: AppColors.blue,
        route: '/perfil',
      ),
    ];

    return VenexusShell(
      title: appState.t('layout.home'),
      currentIndex: 0,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          PageIntro(title: appState.t('dashboard.title'), description: appState.t('dashboard.description')),
          const SizedBox(height: 16),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _DashboardCard(item: item),
              )),
        ],
      ),
    );
  }

  void _showEja(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.surface,
        insetPadding: const EdgeInsets.all(16),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 384),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(border: Border.fromBorderSide(BorderSide(color: AppColors.blue))),
                      child: const Icon(Icons.school_outlined, color: AppColors.blue, size: 32),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (appState.t('dashboard.ejaEyebrow') == 'dashboard.ejaEyebrow' ? 'EDUCAÇÃO' : appState.t('dashboard.ejaEyebrow')).toUpperCase(),
                            style: const TextStyle(fontSize: 12, color: AppColors.blue, fontWeight: FontWeight.w800, letterSpacing: 2),
                          ),
                          const SizedBox(height: 4),
                          Text(appState.t('dashboard.ejaTitle'), style: const TextStyle(fontSize: 20, color: AppColors.purple, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: AppColors.muted)),
                  ],
                ),
                const SizedBox(height: 20),
                Text(appState.t('dashboard.ejaText'), style: const TextStyle(color: AppColors.gray600, height: 1.65)),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: AppColors.gray50,
                    border: Border(left: BorderSide(color: AppColors.yellow, width: 4)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ENDEREÇO', style: TextStyle(fontSize: 12, color: AppColors.purple, fontWeight: FontWeight.w800, letterSpacing: 1.6)),
                      SizedBox(height: 8),
                      Text('SESI Pato Branco\nRua Xingu, 833 - Amadori\nPato Branco - PR', style: TextStyle(color: AppColors.gray600, height: 1.55)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(onPressed: () => Navigator.pop(context), child: Text(appState.language == AppLanguage.es ? 'ENTENDIDO' : 'ENTENDI')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({required this.item});

  final _DashboardItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap ?? () => Navigator.pushNamed(context, item.route!),
      child: SectionCard(
        accentColor: item.color,
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(border: Border.fromBorderSide(BorderSide(color: item.color))),
              child: Icon(item.icon, color: item.color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: const TextStyle(fontSize: 18, color: AppColors.purple, fontWeight: FontWeight.w800, height: 1.25)),
                  const SizedBox(height: 4),
                  Text(item.description, style: const TextStyle(fontSize: 14, color: AppColors.gray600, height: 1.65)),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Icon(Icons.chevron_right, color: AppColors.gray300, size: 26),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardItem {
  const _DashboardItem({required this.icon, required this.title, required this.description, required this.color, this.route, this.onTap});

  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final String? route;
  final VoidCallback? onTap;
}
