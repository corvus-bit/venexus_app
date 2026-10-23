import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import 'i18n.dart';
import 'local_database.dart';
import 'models.dart';
import 'permissions.dart';
import 'system_notifications.dart';

const _languagePreferenceKey = 'venexus.language';

class AppState extends ChangeNotifier with WidgetsBindingObserver {
  AppState() {
    // Enquanto não houver idioma salvo (primeiro acesso), acompanha o idioma do aparelho.
    ui.PlatformDispatcher.instance.onLocaleChanged = _onDeviceLocaleChanged;
    systemNotifications.onTap = _openFromSystemNotification;
  }

  final LocalDatabase db = LocalDatabase();
  final SystemNotifications systemNotifications = SystemNotifications();
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  bool _ready = false;
  bool _initializing = false;
  Object? _initializationError;
  User? _currentUser;
  AppLanguage _language = languageFromLocales(ui.PlatformDispatcher.instance.locales);
  AppLanguage? _savedLanguage;

  bool get ready => _ready;
  bool get initializing => _initializing;
  Object? get initializationError => _initializationError;
  User? get currentUser => _currentUser;
  AppLanguage get language => _language;
  I18n get i18n => I18n(_language);
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.role == UserRole.admin;

  List<Post> get posts => db.getPosts();
  List<SenaiCourse> get courses => db.getCourses();
  List<CartilhaContent> get cartilha => db.getCartilha();
  List<AppNotification> get notifications => db.getNotifications();
  int get unreadNotifications => notifications.where((notification) => !notification.read).length;

  Future<void> init() async {
    if (_initializing) return;

    _initializing = true;
    _initializationError = null;
    notifyListeners();

    try {
      await _loadSavedLanguage();
      await _initSystemNotifications();
      await db.init();
      _currentUser = db.getCurrentUser();
      _language = _currentUser?.language ?? _savedLanguage ?? _deviceLanguage();
      _ready = true;
    } catch (error) {
      _ready = false;
      _initializationError = error;
    } finally {
      _initializing = false;
      notifyListeners();
    }

    if (_ready && isLoggedIn) {
      _startNotifications();
      // App aberto pelo toque numa notificação enquanto estava fechado.
      systemNotifications.handleLaunchPayload(await systemNotifications.launchPayload());
    }
  }

  Future<void> _initSystemNotifications() async {
    WidgetsBinding.instance
      ..removeObserver(this)
      ..addObserver(this);
    try {
      await systemNotifications.init();
    } catch (_) {
      // Sem a bandeja do sistema o app segue com as notificações internas.
    }
  }

  void _startNotifications() {
    db.subscribeToChanges(_onRealtimeChange);
    unawaited(systemNotifications.requestPermission().catchError((_) {}));
  }

  void _onRealtimeChange(AppNotification? notification) {
    notifyListeners();
    if (notification != null && !notification.read) {
      unawaited(systemNotifications.show(notification).catchError((_) {}));
    }
  }

  void _openFromSystemNotification(String notificationId, String? route) {
    unawaited(markNotificationRead(notificationId));
    if (route != null && isLoggedIn) navigatorKey.currentState?.pushNamed(route);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // O Realtime não entrega o que chegou com a conexão parada: recarrega ao voltar ao app.
    if (state == AppLifecycleState.resumed && isLoggedIn) {
      unawaited(refresh().catchError((_) {}));
    }
  }

  AppLanguage _deviceLanguage() => languageFromLocales(ui.PlatformDispatcher.instance.locales);

  void _onDeviceLocaleChanged() {
    if (_currentUser?.language != null || _savedLanguage != null) return;
    final language = _deviceLanguage();
    if (language == _language) return;
    _language = language;
    notifyListeners();
  }

  Future<void> _loadSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_languagePreferenceKey);
      _savedLanguage = saved == null ? null : languageFromJson(saved);
    } catch (_) {
      _savedLanguage = null;
    }
  }

  Future<void> _saveLanguage(AppLanguage language) async {
    _savedLanguage = language;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languagePreferenceKey, languageToJson(language));
    } catch (_) {
      // Sem persistência local, o idioma volta a seguir o aparelho no próximo acesso.
    }
  }

  String t(String key) => i18n.t(key);

  Future<void> refresh() async {
    await db.refreshAll();
    _currentUser = db.getCurrentUser();
    _language = _currentUser?.language ?? _language;
    notifyListeners();
  }

  Future<String?> login({required String phone, required String password}) async {
    try {
      final user = await db.signInWithPhone(phone: phone, password: password);
      if (user == null) return t('auth.invalid');
      _currentUser = user;
      _language = user.language ?? _savedLanguage ?? _deviceLanguage();
      await _saveLanguage(_language);
      _startNotifications();
      notifyListeners();
      return null;
    } catch (_) {
      return t('auth.invalid');
    }
  }

  Future<String?> register({
    required String name,
    required String phone,
    required String email,
    required String address,
    required String password,
    required bool lgpdAccepted,
  }) async {
    if (!lgpdAccepted) return t('auth.lgpdRequired');

    try {
      if (await db.findUserByPhone(phone) != null) return t('auth.duplicatedPhone');
      if (await db.findUserByEmail(email) != null) return t('auth.duplicatedEmail');

      final user = await db.signUpUser(
        name: name,
        phone: phone,
        email: email,
        address: address,
        password: password,
        language: _language,
      );

      _currentUser = user;
      _language = user.language ?? _language;
      await _saveLanguage(_language);
      _startNotifications();
      notifyListeners();
      return null;
    } catch (_) {
      return 'Não foi possível criar a conta. Confira o Supabase e tente novamente.';
    }
  }

  Future<void> logout() async {
    await db.clearCurrentUser();
    _currentUser = null;
    unawaited(systemNotifications.cancelAll().catchError((_) {}));
    notifyListeners();
  }

  Future<void> updateLanguage(AppLanguage language) async {
    _language = language;
    await _saveLanguage(language);
    if (_currentUser != null) {
      _currentUser = await db.updateUser(_currentUser!.copyWith(language: language));
    }
    notifyListeners();
  }

  Future<String?> updateProfile({
    required String name,
    required String phone,
    required String address,
    required AppLanguage language,
    String? avatarPath,
    bool clearAvatar = false,
  }) async {
    final user = _currentUser;
    if (user == null) return 'Usuário não autenticado.';

    try {
      final existingPhone = await db.findUserByPhone(phone);
      if (existingPhone != null && existingPhone.id != user.id) return t('auth.duplicatedPhone');

      final updated = user.copyWith(
        name: name.trim(),
        phone: normalizePhone(phone),
        email: user.email,
        address: address.trim(),
        role: user.role,
        language: language,
        avatarPath: avatarPath,
        clearAvatar: clearAvatar,
      );

      _currentUser = await db.updateUser(updated);
      _language = language;
      await _saveLanguage(language);
      notifyListeners();
      return null;
    } catch (_) {
      return 'Não foi possível salvar o perfil no Supabase.';
    }
  }

  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final user = _currentUser;
    if (user == null) return 'Usuário não autenticado.';
    if (newPassword.length < 6) return 'A nova senha deve ter pelo menos 6 caracteres.';
    if (newPassword != confirmPassword) return 'A confirmação de senha não confere.';

    try {
      _currentUser = await db.changePassword(
        user: user,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      notifyListeners();
      return null;
    } catch (_) {
      return 'Senha atual inválida ou erro ao atualizar no Supabase.';
    }
  }

  Future<String?> requestPasswordReset({required String phone}) async {
    try {
      final user = await db.sendPasswordResetByPhone(phone);
      if (user == null) return t('auth.phoneNotFound');
      return null;
    } on AuthException catch (e) {
      if (e.statusCode == '429' || e.code == 'over_email_send_rate_limit') return t('auth.resetRateLimit');
      return t('auth.resetSendError');
    } catch (_) {
      return t('auth.resetSendError');
    }
  }

  Future<String?> resetPasswordWithCode({
    required String phone,
    required String code,
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (code.trim().isEmpty) return t('common.required');
    if (newPassword.length < 6) return 'A senha deve ter pelo menos 6 caracteres.';
    if (newPassword != confirmPassword) return 'A confirmação de senha não confere.';

    try {
      await db.resetPasswordWithCode(phone: phone, code: code.trim(), newPassword: newPassword);
      _currentUser = null;
      notifyListeners();
      return null;
    } on AuthException catch (e) {
      if (e.code == 'same_password') return t('auth.resetSamePassword');
      if (e.code == 'weak_password') return 'A senha deve ter pelo menos 6 caracteres.';
      return t('auth.resetInvalidCode');
    } catch (_) {
      return t('auth.resetInvalidCode');
    }
  }

  Future<String?> addPost({required String title, required String body, required List<String> images}) async {
    final user = _currentUser;
    if (user == null) return 'Usuário não autenticado.';
    final now = DateTime.now().toIso8601String();
    final post = Post(
      id: _id('post'),
      title: title.trim(),
      body: body.trim(),
      authorId: user.id,
      authorName: user.name,
      authorRole: user.role,
      images: images,
      createdAt: now,
    );
    await db.addPost(post);
    await db.refreshAll();
    notifyListeners();
    return null;
  }

  Future<String?> addComment({required String postId, required String text}) async {
    final user = _currentUser;
    if (user == null) return 'Usuário não autenticado.';
    final comment = Comment(
      id: _id('comment'),
      postId: postId,
      authorId: user.id,
      authorName: user.name,
      authorRole: user.role,
      text: text.trim(),
      createdAt: DateTime.now().toIso8601String(),
    );
    await db.addComment(comment);
    await db.refreshAll();
    notifyListeners();
    return null;
  }

  Future<String?> addCourse({required String name, required String description, required String address}) async {
    final user = _currentUser;
    if (!canPublish(user)) return t('senai.onlyAdmin');
    final course = SenaiCourse(
      id: _id('course'),
      name: name.trim(),
      description: description.trim(),
      institutionAddress: address.trim(),
      createdById: user!.id,
      createdByName: 'Equipe SENAI',
      createdAt: DateTime.now().toIso8601String(),
    );
    await db.addCourse(course);
    await db.refreshAll();
    notifyListeners();
    return null;
  }

  Future<String?> addCartilhaContent({
    required CartilhaType type,
    required String title,
    required String textPt,
    required String textEs,
    required String explanation,
  }) async {
    final user = _currentUser;
    if (!canPublish(user)) return t('cartilha.onlyAdmin');
    final content = CartilhaContent(
      id: _id('cartilha'),
      type: type,
      title: title.trim(),
      textPt: textPt.trim(),
      textEs: textEs.trim(),
      explanation: explanation.trim(),
      createdById: user!.id,
      createdByName: 'Equipe SENAI',
      createdAt: DateTime.now().toIso8601String(),
    );
    await db.addCartilha(content);
    await db.refreshAll();
    notifyListeners();
    return null;
  }

  Future<void> markNotificationRead(String id) => _markNotificationsRead([id]);

  Future<void> markAllNotificationsRead() async {
    await _markNotificationsRead(notifications.map((notification) => notification.id));
    unawaited(systemNotifications.cancelAll().catchError((_) {}));
  }

  Future<void> _markNotificationsRead(Iterable<String> ids) async {
    final pending = db.markNotificationsRead(ids);
    notifyListeners();
    try {
      await pending;
    } catch (_) {
      // Falhou no Supabase: a marcação local foi desfeita, então redesenha como não lida.
    }
    notifyListeners();
  }

  List<SearchResultItem> search(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.length < 2) return [];

    bool contains(String value) => value.toLowerCase().contains(normalized);

    final results = <SearchResultItem>[];

    for (final item in cartilha) {
      if (contains(item.title) || contains(item.textPt) || contains(item.textEs) || contains(item.explanation)) {
        results.add(SearchResultItem(
          type: t('layout.cartilha'),
          title: item.title,
          description: language == AppLanguage.es ? item.textEs : item.textPt,
          route: '/cartilha',
        ));
      }
    }

    for (final post in posts) {
      if (contains(post.title) || contains(post.body) || contains(post.authorName)) {
        results.add(SearchResultItem(
          type: t('layout.forum'),
          title: post.title,
          description: post.body,
          route: '/forum/${post.id}',
        ));
      }
    }

    for (final course in courses) {
      if (contains(course.name) || contains(course.description) || contains(course.institutionAddress)) {
        results.add(SearchResultItem(
          type: t('layout.senai'),
          title: course.name,
          description: course.description,
          route: '/senai',
        ));
      }
    }

    return results;
  }

  String _id(String prefix) => '${prefix}_${DateTime.now().microsecondsSinceEpoch}';
}
