import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/models.dart';
import '../main.dart';

Uint8List? decodeStoredImage(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  try {
    final source = value.contains(',') ? value.split(',').last : value;
    return base64Decode(source);
  } catch (_) {
    return null;
  }
}

class StoredImage extends StatelessWidget {
  const StoredImage({required this.value, required this.width, required this.height, this.fit = BoxFit.cover, super.key});

  final String? value;
  final double width;
  final double height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final bytes = decodeStoredImage(value);
    if (bytes == null) return const SizedBox.shrink();
    return Image.memory(bytes, width: width, height: height, fit: fit, gaplessPlayback: true);
  }
}

class VenexusShell extends StatelessWidget {
  const VenexusShell({
    required this.title,
    required this.child,
    this.currentIndex = 0,
    this.floatingActionButton,
    super.key,
  });

  final String title;
  final Widget child;
  final int currentIndex;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      endDrawer: const _VenexusEndDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            const _TopHeader(),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 448),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}

class _TopHeader extends StatelessWidget {
  const _TopHeader();

  @override
  Widget build(BuildContext context) {
    final user = appState.currentUser;
    final firstName = (user?.name.trim().split(RegExp(r'\s+')).first ?? '').isEmpty ? 'Usuário' : user!.name.trim().split(RegExp(r'\s+')).first;
    final greeting = appState.language == AppLanguage.es ? 'Hola' : 'Olá';
    final welcome = appState.language == AppLanguage.es ? 'Bienvenido al apoyo Venexus' : 'Bem-vindo ao apoio Venexus';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.gray200)),
        boxShadow: AppShadows.sm,
      ),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 448),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              UserAvatar(user: user, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Venexus',
                      style: TextStyle(
                        color: AppColors.blue,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.9,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$greeting, $firstName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.purple, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      welcome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                    if (user?.role == UserRole.admin) ...[
                      const SizedBox(height: 5),
                      const AdminRoleTag(),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _HeaderIconButton(
                tooltip: appState.t('common.search'),
                icon: Icons.search,
                onTap: () => Navigator.pushNamed(context, '/search'),
              ),
              _NotificationHeaderButton(onTap: () => Navigator.pushNamed(context, '/notifications')),
              Builder(
                builder: (innerContext) => _HeaderIconButton(
                  tooltip: 'Abrir menu',
                  icon: Icons.menu,
                  size: 28,
                  onTap: () => Scaffold.of(innerContext).openEndDrawer(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationHeaderButton extends StatelessWidget {
  const _NotificationHeaderButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: appState, builder: (context, _) => _buildBadge());
  }

  Widget _buildBadge() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _HeaderIconButton(tooltip: appState.t('common.notifications'), icon: Icons.notifications_outlined, onTap: onTap),
        if (appState.unreadNotifications > 0)
          Positioned(
            top: 5,
            right: 5,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: const BoxDecoration(color: AppColors.red),
              child: Text(
                appState.unreadNotifications > 9 ? '9+' : '${appState.unreadNotifications}',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, height: 1),
              ),
            ),
          ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onTap, required this.tooltip, this.size = 22});

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: size, color: AppColors.gray600),
        ),
      ),
    );
  }
}

class _VenexusEndDrawer extends StatelessWidget {
  const _VenexusEndDrawer();

  @override
  Widget build(BuildContext context) {
    final user = appState.currentUser;
    final navItems = [
      _MenuItem(Icons.home_outlined, appState.t('layout.home'), '/'),
      _MenuItem(Icons.menu_book_outlined, appState.t('layout.cartilha'), '/cartilha'),
      _MenuItem(Icons.forum_outlined, appState.t('layout.forum'), '/forum'),
      _MenuItem(Icons.work_outline, appState.t('layout.senai'), '/senai'),
      _MenuItem(Icons.person_outline, appState.t('layout.profile'), '/perfil'),
    ];

    return Drawer(
      width: 288,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      appState.language == AppLanguage.es ? 'Menú' : 'Menu',
                      style: const TextStyle(color: AppColors.purple, fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                  ),
                  _HeaderIconButton(
                    tooltip: appState.t('common.close'),
                    icon: Icons.close,
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.only(left: 12, bottom: 24),
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: AppColors.yellow, width: 4),
                    bottom: BorderSide(color: AppColors.gray100),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UserAvatar(user: user, size: 42),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user?.name ?? 'Venexus', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.purple)),
                          const SizedBox(height: 4),
                          Text(user?.phone ?? '', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                          if ((user?.email ?? '').isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(user!.email, style: const TextStyle(fontSize: 12, color: AppColors.gray600), overflow: TextOverflow.ellipsis),
                          ],
                          if (user?.role == UserRole.admin) ...[
                            const SizedBox(height: 6),
                            const Text('Administrador', style: TextStyle(fontSize: 12, color: AppColors.blue, fontWeight: FontWeight.w800)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.separated(
                  itemCount: navItems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => _DrawerNavLink(item: navItems[index]),
                ),
              ),
              Container(
                padding: const EdgeInsets.only(top: 20),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.gray100))),
                child: InkWell(
                  onTap: () async {
                    await appState.logout();
                    if (context.mounted) {
                      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.logout, color: AppColors.red, size: 20),
                        const SizedBox(width: 16),
                        Text(appState.t('layout.logout'), style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerNavLink extends StatelessWidget {
  const _DrawerNavLink({required this.item});

  final _MenuItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        Navigator.pushNamedAndRemoveUntil(context, item.route, (route) => false);
      },
      child: Container(
        decoration: const BoxDecoration(border: Border(left: BorderSide(color: Colors.transparent, width: 4))),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(item.icon, size: 20, color: AppColors.gray700),
            const SizedBox(width: 16),
            Expanded(child: Text(item.label, style: const TextStyle(color: AppColors.gray700, fontWeight: FontWeight.w700))),
          ],
        ),
      ),
    );
  }
}

class _MenuItem {
  const _MenuItem(this.icon, this.label, this.route);
  final IconData icon;
  final String label;
  final String route;
}

class UserAvatar extends StatelessWidget {
  const UserAvatar({required this.user, this.size = 44, this.radius = 0, super.key});

  final User? user;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final bytes = decodeStoredImage(user?.avatarPath);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.gray50,
        border: Border.fromBorderSide(BorderSide(color: AppColors.yellow)),
      ),
      clipBehavior: Clip.hardEdge,
      child: bytes != null
          ? Image.memory(bytes, width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true)
          : Icon(Icons.account_circle_outlined, color: AppColors.blue, size: size * .72),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({required this.child, this.padding = const EdgeInsets.all(16), this.accentColor, this.backgroundColor, super.key});

  final Widget child;
  final EdgeInsets padding;
  final Color? accentColor;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface,
        border: Border(
          left: BorderSide(color: accentColor ?? AppColors.gray200, width: accentColor == null ? 1 : 4),
          top: const BorderSide(color: AppColors.gray200),
          right: const BorderSide(color: AppColors.gray200),
          bottom: const BorderSide(color: AppColors.gray200),
        ),
        boxShadow: AppShadows.sm,
      ),
      padding: padding,
      child: child,
    );
  }
}

class PageIntro extends StatelessWidget {
  const PageIntro({required this.title, required this.description, this.accentColor = AppColors.blue, super.key});

  final String title;
  final String description;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      accentColor: accentColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.purple, fontSize: 20, fontWeight: FontWeight.w800, height: 1.25)),
          const SizedBox(height: 4),
          Text(description, style: const TextStyle(color: AppColors.gray600, fontSize: 14, height: 1.65)),
        ],
      ),
    );
  }
}

class AdminBadge extends StatelessWidget {
  const AdminBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: const BoxDecoration(color: AppColors.blue),
      child: Text(
        appState.t('common.senaiTeam').toUpperCase(),
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: .8),
      ),
    );
  }
}

class AdminRoleTag extends StatelessWidget {
  const AdminRoleTag({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: const BoxDecoration(
        color: Color(0x1FFAB206),
        border: Border(left: BorderSide(color: AppColors.yellow, width: 3)),
      ),
      child: const Text(
        'ADMINISTRADOR',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.purple, letterSpacing: .7),
      ),
    );
  }
}

class BackAction extends StatelessWidget {
  const BackAction({this.label, this.route = '/', super.key});

  final String? label;
  final String route;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => Navigator.pushNamedAndRemoveUntil(context, route, (_) => false),
        icon: const Icon(Icons.arrow_back, size: 18),
        label: Text(label ?? (appState.language == AppLanguage.es ? 'Volver al dashboard' : 'Voltar ao dashboard')),
      ),
    );
  }
}

class AuthFrame extends StatelessWidget {
  const AuthFrame({required this.title, required this.subtitle, required this.child, super.key});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 384),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border(left: BorderSide(color: AppColors.red, width: 4)),
                      boxShadow: AppShadows.sm,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(border: Border.fromBorderSide(BorderSide(color: AppColors.yellow))),
                          child: const Icon(Icons.account_balance_outlined, color: AppColors.blue),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Venexus', style: TextStyle(color: AppColors.blue, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 2.8)),
                              const SizedBox(height: 4),
                              Text(appState.t('app.support'), style: const TextStyle(color: AppColors.purple700, fontSize: 14, height: 1.65)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border.fromBorderSide(BorderSide(color: AppColors.gray200)),
                      boxShadow: AppShadows.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(
                          children: [
                            Expanded(child: ColoredBox(color: AppColors.red, child: SizedBox(height: 4))),
                            Expanded(child: ColoredBox(color: AppColors.yellow, child: SizedBox(height: 4))),
                            Expanded(child: ColoredBox(color: AppColors.green, child: SizedBox(height: 4))),
                            Expanded(child: ColoredBox(color: AppColors.blue, child: SizedBox(height: 4))),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Column(
                                children: [
                                  Text(
                                    title.toUpperCase(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: AppColors.purple,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 4.6,
                                      height: 1.15,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    subtitle,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: AppColors.purple700, fontSize: 14, height: 1.65),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 28),
                              child,
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class InlineNotice extends StatelessWidget {
  const InlineNotice({required this.title, required this.text, this.accentColor = AppColors.blue, super.key});

  final String title;
  final String text;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        border: Border(left: BorderSide(color: accentColor, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(color: AppColors.gray600, fontSize: 14, height: 1.6)),
        ],
      ),
    );
  }
}
