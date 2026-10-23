import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/models.dart';
import '../main.dart';
import '../widgets/venexus_shell.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Rotas já abertas não são reconstruídas pelo MaterialApp: escuta o estado aqui.
    return ListenableBuilder(listenable: appState, builder: (context, _) => _build(context));
  }

  void _open(BuildContext context, AppNotification notification) {
    appState.markNotificationRead(notification.id);
    if (notification.targetRoute != null) Navigator.pushNamed(context, notification.targetRoute!);
  }

  Widget _build(BuildContext context) {
    final notifications = appState.notifications;
    final hasUnread = notifications.any((notification) => !notification.read);
    return VenexusShell(
      title: appState.t('notifications.title'),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const BackAction(),
          PageIntro(title: appState.t('notifications.title'), description: 'Acompanhe novidades do fórum, catálogo e cartilha.', accentColor: AppColors.blue),
          const SizedBox(height: 16),
          if (hasUnread)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OutlinedButton.icon(
                onPressed: () => appState.markAllNotificationsRead(),
                icon: const Icon(Icons.done_all),
                label: Text(appState.t('notifications.markAllRead').toUpperCase()),
              ),
            ),
          if (notifications.isEmpty)
            InlineNotice(title: appState.t('notifications.title'), text: appState.t('notifications.empty'), accentColor: AppColors.yellow)
          else
            ...notifications.map((notification) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () => _open(context, notification),
                    child: SectionCard(
                      accentColor: notification.read ? AppColors.gray200 : AppColors.yellow,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: notification.read ? AppColors.gray50 : const Color(0x24FAB206),
                              border: Border.fromBorderSide(BorderSide(color: notification.read ? AppColors.gray200 : AppColors.yellow)),
                            ),
                            child: Icon(_icon(notification.type), color: AppColors.blue, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(
                                children: [
                                  Expanded(child: Text(notification.title, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.purple))),
                                  if (!notification.read) const Icon(Icons.circle, size: 10, color: AppColors.red),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(notification.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.gray600, height: 1.55)),
                            ]),
                          ),
                        ],
                      ),
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  IconData _icon(String type) {
    switch (type) {
      case 'post':
        return Icons.forum_outlined;
      case 'comment':
        return Icons.chat_bubble_outline;
      case 'course':
        return Icons.work_outline;
      case 'labor':
        return Icons.gavel_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }
}
