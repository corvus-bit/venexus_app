import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'models.dart';

/// Toque numa notificação da bandeja: id da notificação e rota de destino.
typedef SystemNotificationTap = void Function(String notificationId, String? route);

/// Mostra as notificações do app na bandeja do sistema (Android/iOS).
class SystemNotifications {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  SystemNotificationTap? onTap;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'venexus_updates',
      'Novidades do Venexus',
      channelDescription: 'Fórum, catálogo SENAI e cartilha',
      icon: 'ic_notification',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  bool get _supported => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> init() async {
    if (_initialized || !_supported) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        // A permissão é pedida depois do login, não na abertura do app.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) => _handleTap(response.payload),
    );
    _initialized = true;
  }

  /// Payload da notificação que abriu o app, quando ele estava fechado.
  Future<String?> launchPayload() async {
    if (!_initialized) return null;
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    return details!.notificationResponse?.payload;
  }

  Future<void> requestPermission() async {
    if (!_initialized) return;
    await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> show(AppNotification notification) async {
    if (!_initialized) return;
    await _plugin.show(
      id: notification.id.hashCode & 0x7fffffff,
      title: notification.title,
      body: notification.body,
      notificationDetails: _details,
      payload: jsonEncode({'id': notification.id, 'route': notification.targetRoute}),
    );
  }

  Future<void> cancelAll() async {
    if (!_initialized) return;
    await _plugin.cancelAll();
  }

  void handleLaunchPayload(String? payload) => _handleTap(payload);

  void _handleTap(String? payload) {
    if (payload == null) return;
    try {
      final data = Map<String, dynamic>.from(jsonDecode(payload) as Map);
      onTap?.call(data['id'] as String, data['route'] as String?);
    } catch (_) {
      // Payload de versão antiga ou inválido: só abre o app.
    }
  }
}
