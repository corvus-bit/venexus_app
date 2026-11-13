import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import 'models.dart';
import 'permissions.dart';
import 'supabase_config.dart';

/// Aplicativo deste cliente na plataforma compartilhada (platform.apps.slug).
const venexusApp = 'venexus';

/// Resposta de erro da Edge Function `phone-auth`. [code] é genérico de propósito:
/// `invalid_credentials`, `invalid_code`, `rate_limited` ou `unavailable`.
class PhoneAuthException implements Exception {
  const PhoneAuthException(this.code);

  final String code;

  @override
  String toString() => 'PhoneAuthException($code)';
}

/// A senha está certa, mas o e-mail da conta ainda não foi confirmado.
class EmailNotConfirmedException implements Exception {
  const EmailNotConfirmedException(this.email);

  final String email;
}

/// O Auth não criou a conta porque o e-mail ou o telefone já pertence a outra.
class AccountAlreadyExistsException implements Exception {
  const AccountAlreadyExistsException();
}

class LocalDatabase {
  bool _supabaseInitialized = false;
  String? _venexusMembershipStatus;

  final List<User> _users = [];
  final List<Post> _posts = [];
  final List<Comment> _comments = [];
  final List<SenaiCourse> _courses = [];
  final List<CartilhaContent> _cartilha = [];
  final Set<String> _readNotificationIds = {};
  RealtimeChannel? _changesChannel;

  SupabaseClient get client => Supabase.instance.client;

  Future<void> init() async {
    SupabaseConfig.assertConfigured();

    if (!_supabaseInitialized) {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.anonKey,
      );
      _supabaseInitialized = true;
    }

    await refreshAll();
  }

  Future<void> refreshAll() async {
    await _loadCurrentUser();

    if (client.auth.currentUser == null) {
      _posts.clear();
      _comments.clear();
      _courses.clear();
      _cartilha.clear();
      _readNotificationIds.clear();
      return;
    }

    await Future.wait([
      _loadPosts().then((_) => _loadComments()),
      _loadCourses(),
      _loadCartilha(),
      _loadReadNotifications(),
    ]);
  }

  /// Quantidade de publicações por página do fórum.
  static const postsPageSize = 30;

  bool _hasMorePosts = false;

  /// Há publicações mais antigas que ainda não foram carregadas.
  bool get hasMorePosts => _hasMorePosts;

  static const _postColumns = 'id, title, body, author_id, author_name, author_role, images, created_at';
  static const _commentColumns = 'id, post_id, author_id, author_name, author_role, text, parent_id, reply_to_author_id, reply_to_name, created_at';

  Future<List<Post>> _fetchPosts({String? olderThan}) async {
    var query = client.from('posts').select(_postColumns);
    if (olderThan != null) query = query.lt('created_at', olderThan);
    final data = await query.order('created_at', ascending: false).limit(postsPageSize);
    final page = (data as List).map((item) => _postFromSupabase(Map<String, dynamic>.from(item as Map))).toList();
    _hasMorePosts = page.length == postsPageSize;
    return page;
  }

  Future<List<Comment>> _fetchComments(Iterable<String> postIds) async {
    final ids = postIds.toList();
    if (ids.isEmpty) return [];
    final data = await client.from('comments').select(_commentColumns).inFilter('post_id', ids).order('created_at', ascending: true);
    return (data as List).map((item) => _commentFromSupabase(Map<String, dynamic>.from(item as Map))).toList();
  }

  /// Carrega a próxima página de publicações (e os comentários delas).
  Future<void> loadMorePosts() async {
    if (!_hasMorePosts || _posts.isEmpty) return;
    final page = await _fetchPosts(olderThan: _posts.last.createdAt);
    final known = _posts.map((post) => post.id).toSet();
    final added = page.where((post) => !known.contains(post.id)).toList();
    _posts.addAll(added);
    _comments.addAll(await _fetchComments(added.map((post) => post.id)));
  }

  /// Vínculo do usuário logado com o Venexus: `active`, `pending`, `revoked` ou null (sem vínculo).
  /// Serve só para a interface; quem autoriza de fato é o RLS, que consulta o vínculo a cada operação.
  String? get venexusMembershipStatus => _venexusMembershipStatus;

  Future<void> _loadCurrentUser() async {
    _users.clear();
    final authUser = client.auth.currentUser;
    if (authUser == null) {
      _venexusMembershipStatus = null;
      return;
    }
    final profile = await getUserByIdRemote(authUser.id);
    if (profile != null) _users.add(profile);
  }

  Future<void> _loadPosts() async {
    final page = await _fetchPosts();
    _posts
      ..clear()
      ..addAll(page);
  }

  // Só os comentários das publicações carregadas.
  Future<void> _loadComments() async {
    final comments = await _fetchComments(_posts.map((post) => post.id));
    _comments
      ..clear()
      ..addAll(comments);
  }

  Future<void> _loadCourses() async {
    final data = await client.from('senai_courses').select('*').order('created_at', ascending: false);
    _courses
      ..clear()
      ..addAll((data as List).map((item) => _courseFromSupabase(Map<String, dynamic>.from(item as Map))));
  }

  Future<void> _loadCartilha() async {
    final data = await client.from('cartilha_contents').select('*').order('created_at', ascending: false);
    _cartilha
      ..clear()
      ..addAll((data as List).map((item) => _cartilhaFromSupabase(Map<String, dynamic>.from(item as Map))));
  }

  Future<void> _loadReadNotifications() async {
    _readNotificationIds.clear();
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    final data = await client.from('notification_reads').select('notification_id').eq('user_id', userId);
    _readNotificationIds.addAll((data as List).map((item) => Map<String, dynamic>.from(item as Map)['notification_id'] as String));
  }

  List<User> getUsers() => List.unmodifiable(_users);

  User? getCurrentUser() {
    final id = client.auth.currentUser?.id;
    if (id == null) return null;
    return getUserById(id);
  }

  String? getCurrentUserId() => client.auth.currentUser?.id;

  Future<void> setCurrentUser(String userId) async {
    final user = await getUserByIdRemote(userId);
    _users
      ..clear()
      ..addAll(user == null ? [] : [user]);
  }

  Future<void> clearCurrentUser() => signOut();

  User? getUserById(String id) {
    for (final user in _users) {
      if (user.id == id) return user;
    }
    return null;
  }

  /// Perfil do usuário logado, com o papel que ele tem no Venexus.
  Future<User?> getUserByIdRemote(String id) async {
    final data = await client.from('profiles').select('*').eq('id', id).maybeSingle();
    if (data == null) return null;
    return _userFromSupabase(Map<String, dynamic>.from(data), role: await _loadVenexusRole());
  }

  /// Campos escolhidos do perfil de um participante ativo do Venexus.
  Future<PublicProfile?> getPublicProfile(String id) async {
    final data = await client.rpc('get_public_profile', params: {'p_user': id}) as List;
    if (data.isEmpty) return null;
    return PublicProfile.fromJson(Map<String, dynamic>.from(data.first as Map));
  }

  /// O papel vem do vínculo com o aplicativo (platform.app_memberships), não do perfil nem do e-mail.
  Future<UserRole> _loadVenexusRole() async {
    final memberships = await client.rpc('my_app_memberships') as List;
    Map<String, dynamic>? membership;
    for (final item in memberships) {
      final row = Map<String, dynamic>.from(item as Map);
      if (row['app_slug'] == venexusApp) membership = row;
    }
    _venexusMembershipStatus = membership?['status'] as String?;
    final isAdmin = _venexusMembershipStatus == 'active' && membership?['role'] == 'admin';
    return isAdmin ? UserRole.admin : UserRole.reader;
  }

  /// Entra no Venexus com uma identidade criada por outro aplicativo da plataforma,
  /// registrando o aceite do termo do Venexus. Não reativa um vínculo revogado.
  Future<User?> joinVenexus() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return null;
    await client.rpc('join_app', params: {'p_app': venexusApp});
    await client.from('profiles').update({
      'lgpd_accepted_at': DateTime.now().toIso8601String(),
      'lgpd_version': lgpdVersion,
    }).eq('id', userId);
    await refreshAll();
    return getCurrentUser();
  }

  /// Chama a Edge Function `phone-auth`, que resolve o e-mail da conta no servidor.
  /// O app nunca recebe o e-mail de um telefone sem provar a senha.
  Future<Map<String, dynamic>> _phoneAuth(Map<String, dynamic> body) async {
    try {
      final response = await client.functions.invoke('phone-auth', body: body);
      return Map<String, dynamic>.from(response.data as Map);
    } on FunctionException catch (e) {
      // status 0 = a requisição nem saiu (sem rede): segue como erro de conexão.
      if (e.status == 0) rethrow;
      final details = e.details;
      final code = details is Map ? details['error'] : null;
      throw PhoneAuthException(code is String ? code : 'unavailable');
    }
  }

  /// Abre no app a sessão criada pelo Auth do outro lado da Edge Function.
  Future<AuthResponse> _openSession(Map<String, dynamic> data) =>
      client.auth.setSession(data['refresh_token'] as String, accessToken: data['access_token'] as String);

  /// Lança [EmailNotConfirmedException] quando a senha confere mas o e-mail ainda não foi confirmado
  /// (um código novo já foi enviado) e [PhoneAuthException] nas demais recusas.
  Future<User?> signInWithPhone({required String phone, required String password}) async {
    final data = await _phoneAuth({'action': 'login', 'phone': normalizePhone(phone), 'password': password});
    if (data['status'] == 'confirmation_required') throw EmailNotConfirmedException(data['email'] as String);

    final response = await _openSession(data);
    final authUser = response.user;
    if (authUser == null) return null;
    final user = await getUserByIdRemote(authUser.id);
    _users
      ..clear()
      ..addAll(user == null ? [] : [user]);
    await refreshAll();
    return user;
  }

  /// Cria a conta. Devolve null quando o Supabase exige confirmação do e-mail
  /// ("Confirm email" ligado): não há sessão até o código ser validado em [verifySignUpCode].
  Future<User?> signUpUser({
    required String name,
    required String phone,
    required String email,
    required String address,
    String originCountry = '',
    String originRegion = '',
    required String password,
    required AppLanguage language,
  }) async {
    final normalizedEmail = normalizeEmail(email);
    final normalizedPhone = normalizePhone(phone);

    final response = await client.auth.signUp(
      email: normalizedEmail,
      password: password,
      // O metadata é só um pedido: o banco valida cada campo, decide o papel sozinho e data o aceite
      // do termo. signup_app pede a entrada neste aplicativo (o Venexus tem adesão aberta).
      data: {
        'signup_app': venexusApp,
        'name': name.trim(),
        'phone': normalizedPhone,
        'address': address.trim(),
        'origin_country': originCountry.trim(),
        'origin_region': originRegion.trim(),
        'language': languageToJson(language),
        'lgpd_version': lgpdVersion,
      },
    );

    final authUser = response.user;
    if (authUser == null) throw StateError('Não foi possível criar o usuário no Supabase Auth.');
    // Para um e-mail já cadastrado o Auth devolve um usuário de fachada, sem identidades e sem enviar código.
    if (response.session == null && (authUser.identities?.isEmpty ?? false)) throw const AccountAlreadyExistsException();
    if (response.session == null) return null;

    return _loadSignedInUser(authUser.id);
  }

  // O template "Confirm signup" do Supabase envia {{ .Token }} (código), no mesmo padrão da recuperação de senha.
  Future<User> verifySignUpCode({required String email, required String code}) async {
    final response = await client.auth.verifyOTP(email: normalizeEmail(email), token: code, type: OtpType.signup);
    final authUser = response.user;
    if (authUser == null || response.session == null) throw StateError('Código validado, mas o Supabase não abriu a sessão.');
    return _loadSignedInUser(authUser.id);
  }

  Future<void> resendSignUpCode(String email) => client.auth.resend(type: OtpType.signup, email: normalizeEmail(email));

  Future<User> _loadSignedInUser(String userId) async {
    final user = await getUserByIdRemote(userId);
    // Com sessão aberta, o perfil só falta se o trigger handle_new_auth_user não rodou.
    if (user == null) throw StateError('Conta criada no Auth, mas o perfil não foi encontrado. Confira o trigger on_auth_user_created_profile.');
    _users
      ..clear()
      ..add(user);
    await refreshAll();
    return user;
  }

  Future<void> signOut() async {
    unsubscribeFromChanges();
    await client.auth.signOut();
    _users.clear();
    _venexusMembershipStatus = null;
  }

  Future<User> updateUser(User updatedUser) async {
    final authUser = client.auth.currentUser;
    if (authUser?.id == updatedUser.id) {
      await client.auth.updateUser(
        UserAttributes(
          data: {
            ...?authUser?.userMetadata,
            'name': updatedUser.name.trim(),
            'phone': normalizePhone(updatedUser.phone),
            'address': updatedUser.address.trim(),
            'origin_country': updatedUser.originCountry.trim(),
            'origin_region': updatedUser.originRegion.trim(),
            'language': languageToJson(updatedUser.language ?? AppLanguage.ptBR),
          },
        ),
      );
    }

    final data = await client
        .from('profiles')
        .update(_profileUpdatePayload(updatedUser))
        .eq('id', updatedUser.id)
        .select('*')
        .single();
    // O papel não muda por atualização de perfil.
    final saved = _userFromSupabase(Map<String, dynamic>.from(data), role: updatedUser.role);
    _users
      ..clear()
      ..add(saved);
    return saved;
  }

  Future<User> changePassword({required User user, required String currentPassword, required String newPassword}) async {
    await client.auth.signInWithPassword(email: user.email, password: currentPassword);
    await client.auth.updateUser(UserAttributes(password: newPassword));
    return updateUser(user.copyWith(passwordUpdatedAt: DateTime.now().toIso8601String()));
  }

  // O template "Reset Password" do Supabase envia {{ .Token }} (código), não link: dispensa deep link no app.
  /// A resposta é a mesma havendo ou não conta com este telefone.
  Future<void> sendPasswordResetByPhone(String phone) async {
    await _phoneAuth({'action': 'recover', 'phone': normalizePhone(phone)});
  }

  Future<void> resetPasswordWithCode({required String phone, required String code, required String newPassword}) async {
    final response = await _openSession(
      await _phoneAuth({'action': 'verify_recovery', 'phone': normalizePhone(phone), 'code': code}),
    );
    try {
      await client.auth.updateUser(UserAttributes(password: newPassword));
      final userId = response.user?.id;
      if (userId != null) {
        await client
            .from('profiles')
            .update({'password_updated_at': DateTime.now().toIso8601String()})
            .eq('id', userId);
      }
    } finally {
      // A sessão de recuperação serve só para trocar a senha; o usuário entra de novo com a senha nova.
      await signOut();
    }
  }

  List<Post> getPosts() => List.unmodifiable(_posts);

  Future<void> savePosts(List<Post> posts) async {
    _posts
      ..clear()
      ..addAll(posts);
  }

  // author_name/author_role são sobrescritos no banco (trigger posts_set_author) com os dados do perfil.
  Future<void> addPost(Post post) async {
    final data = await client.from('posts').insert({
      'title': post.title,
      'body': post.body,
      'author_id': post.authorId,
      'author_name': post.authorName,
      'author_role': roleToJson(post.authorRole),
      'images': post.images,
    }).select(_postColumns).single();
    final saved = _postFromSupabase(Map<String, dynamic>.from(data));
    _posts
      ..removeWhere((item) => item.id == saved.id)
      ..insert(0, saved);
  }

  Future<void> deletePost(String id) async {
    await _deleteById('posts', id);
    _posts.removeWhere((post) => post.id == id);
    _comments.removeWhere((comment) => comment.postId == id);
  }

  Post? getPostById(String id) {
    for (final post in _posts) {
      if (post.id == id) return post;
    }
    return null;
  }

  List<Comment> getComments() => List.unmodifiable(_comments);

  List<Comment> getCommentsByPostId(String postId) => _comments.where((comment) => comment.postId == postId).toList();

  Future<void> saveComments(List<Comment> comments) async {
    _comments
      ..clear()
      ..addAll(comments);
  }

  // Autor e reply_to_name são sobrescritos no banco (trigger comments_set_author).
  Future<void> addComment(Comment comment) async {
    final data = await client.from('comments').insert({
      'post_id': comment.postId,
      'author_id': comment.authorId,
      'author_name': comment.authorName,
      'author_role': roleToJson(comment.authorRole),
      'text': comment.text,
      'parent_id': comment.parentId,
      'reply_to_author_id': comment.replyToAuthorId,
      'reply_to_name': comment.replyToName,
    }).select(_commentColumns).single();
    final saved = _commentFromSupabase(Map<String, dynamic>.from(data));
    _comments
      ..removeWhere((item) => item.id == saved.id)
      ..add(saved);
  }

  /// Apaga o comentário e as respostas dele (on delete cascade no banco).
  Future<void> deleteComment(String id) async {
    await _deleteById('comments', id);
    _comments.removeWhere((comment) => comment.id == id || comment.parentId == id);
  }

  List<SenaiCourse> getCourses() => List.unmodifiable(_courses);

  Future<void> saveCourses(List<SenaiCourse> courses) async {
    _courses
      ..clear()
      ..addAll(courses);
  }

  Future<void> addCourse(SenaiCourse course) async {
    await client.from('senai_courses').insert({
      'name': course.name,
      'description': course.description,
      'institution_address': course.institutionAddress,
      'created_by_id': course.createdById,
      'created_by_name': course.createdByName,
    });
    await _loadCourses();
  }

  Future<void> deleteCourse(String id) async {
    await _deleteById('senai_courses', id);
    _courses.removeWhere((course) => course.id == id);
  }

  List<CartilhaContent> getCartilha() => List.unmodifiable(_cartilha);

  Future<void> saveCartilha(List<CartilhaContent> contents) async {
    _cartilha
      ..clear()
      ..addAll(contents);
  }

  Future<void> addCartilha(CartilhaContent content) async {
    await client.from('cartilha_contents').insert({
      'type': cartilhaTypeToJson(content.type),
      'title': content.title,
      'title_es': content.titleEs,
      'text_pt': content.textPt,
      'text_es': content.textEs,
      'explanation': content.explanation,
      'explanation_es': content.explanationEs,
      'created_by_id': content.createdById,
      'created_by_name': content.createdByName,
    });
    await _loadCartilha();
  }

  Future<void> deleteCartilha(String id) async {
    await _deleteById('cartilha_contents', id);
    _cartilha.removeWhere((content) => content.id == id);
  }

  /// O RLS do Supabase não retorna erro quando bloqueia um delete, só não apaga nada.
  /// Por isso pedimos as linhas apagadas de volta e tratamos lista vazia como recusa.
  Future<void> _deleteById(String table, String id) async {
    final deleted = await client.from(table).delete().eq('id', id).select('id');
    if ((deleted as List).isEmpty) throw StateError('delete-denied');
  }

  List<AppNotification> getNotifications() {
    final items = <AppNotification?>[
      ..._posts.map(_postNotification),
      ..._comments.map(_commentNotification),
      ..._courses.map(_courseNotification),
      ..._cartilha.map(_cartilhaNotification),
    ].whereType<AppNotification>().toList();

    items.sort((a, b) => DateTime.parse(b.createdAt).compareTo(DateTime.parse(a.createdAt)));
    return items.take(20).toList();
  }

  /// Tradutor do idioma atual, configurado pelo AppState (notificações são montadas aqui).
  String Function(String key) translate = (key) => key;

  // Ninguém é notificado do próprio conteúdo.
  bool _isMine(String? authorId) => authorId != null && authorId == client.auth.currentUser?.id;

  AppNotification? _postNotification(Post post) {
    if (_isMine(post.authorId)) return null;
    final id = 'post-${post.id}';
    return AppNotification(
      id: id,
      type: 'post',
      title: translate('notifications.newPost'),
      body: post.title,
      targetRoute: '/forum/${post.id}',
      createdAt: post.createdAt,
      read: _readNotificationIds.contains(id),
    );
  }

  // Comentários só interessam a quem escreveu a publicação ou já participou da conversa.
  AppNotification? _commentNotification(Comment comment) {
    if (_isMine(comment.authorId)) return null;
    final repliedToMe = _isMine(comment.replyToAuthorId);
    final isPostAuthor = _isMine(getPostById(comment.postId)?.authorId);
    final participated = _comments.any((other) => other.postId == comment.postId && _isMine(other.authorId));
    if (!repliedToMe && !isPostAuthor && !participated) return null;
    final id = 'comment-${comment.id}';
    return AppNotification(
      id: id,
      type: 'comment',
      title: repliedToMe
          ? translate('notifications.replyToYou').replaceAll('{name}', comment.authorName)
          : translate(isPostAuthor ? 'notifications.commentOnYourPost' : 'notifications.replyInThread'),
      body: '${comment.authorName}: ${comment.text}',
      targetRoute: '/forum/${comment.postId}',
      createdAt: comment.createdAt,
      read: _readNotificationIds.contains(id),
    );
  }

  AppNotification? _courseNotification(SenaiCourse course) {
    if (course.createdAt == null || _isMine(course.createdById)) return null;
    final id = 'course-${course.id}';
    return AppNotification(
      id: id,
      type: 'course',
      title: translate('notifications.newCourse'),
      body: course.name,
      targetRoute: '/senai',
      createdAt: course.createdAt!,
      read: _readNotificationIds.contains(id),
    );
  }

  AppNotification? _cartilhaNotification(CartilhaContent content) {
    if (content.type != CartilhaType.rights || content.createdAt == null || _isMine(content.createdById)) return null;
    final id = 'labor-${content.id}';
    return AppNotification(
      id: id,
      type: 'labor',
      title: translate('notifications.newLabor'),
      body: content.title,
      targetRoute: '/cartilha',
      createdAt: content.createdAt!,
      read: _readNotificationIds.contains(id),
    );
  }

  Future<void> markNotificationsRead(Iterable<String> ids) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    final unread = ids.where((id) => !_readNotificationIds.contains(id)).toSet();
    if (unread.isEmpty) return;
    // Marca localmente primeiro para a interface responder na hora.
    _readNotificationIds.addAll(unread);
    try {
      // ignoreDuplicates = ON CONFLICT DO NOTHING: notification_reads não tem policy de UPDATE.
      await client.from('notification_reads').upsert(
        unread.map((id) => {'user_id': userId, 'notification_id': id}).toList(),
        onConflict: 'user_id,notification_id',
        ignoreDuplicates: true,
      );
    } catch (_) {
      _readNotificationIds.removeAll(unread);
      rethrow;
    }
  }

  /// Escuta inserções pelo Supabase Realtime, atualiza os dados em memória e
  /// repassa a notificação gerada (ou null, quando o item não notifica este usuário).
  void subscribeToChanges(void Function(AppNotification? notification) onChange) {
    unsubscribeFromChanges();
    final channel = client.channel('venexus-notifications');

    void listen(String table, AppNotification? Function(Map<String, dynamic> record) handle) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: table,
        callback: (payload) => onChange(handle(Map<String, dynamic>.from(payload.newRecord))),
      );
    }

    listen('posts', (record) {
      final post = _postFromSupabase(record);
      _posts
        ..removeWhere((item) => item.id == post.id)
        ..insert(0, post);
      return _postNotification(post);
    });
    listen('comments', (record) {
      final comment = _commentFromSupabase(record);
      _comments
        ..removeWhere((item) => item.id == comment.id)
        ..add(comment);
      return _commentNotification(comment);
    });
    listen('senai_courses', (record) {
      final course = _courseFromSupabase(record);
      _courses
        ..removeWhere((item) => item.id == course.id)
        ..insert(0, course);
      return _courseNotification(course);
    });
    listen('cartilha_contents', (record) {
      final content = _cartilhaFromSupabase(record);
      _cartilha
        ..removeWhere((item) => item.id == content.id)
        ..insert(0, content);
      return _cartilhaNotification(content);
    });

    void listenDelete(String table, void Function(String id) remove) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: table,
        callback: (payload) {
          final id = payload.oldRecord['id'] as String?;
          if (id == null) return;
          remove(id);
          onChange(null);
        },
      );
    }

    listenDelete('posts', (id) {
      _posts.removeWhere((post) => post.id == id);
      _comments.removeWhere((comment) => comment.postId == id);
    });
    listenDelete('comments', (id) => _comments.removeWhere((comment) => comment.id == id || comment.parentId == id));
    listenDelete('cartilha_contents', (id) => _cartilha.removeWhere((content) => content.id == id));
    listenDelete('senai_courses', (id) => _courses.removeWhere((course) => course.id == id));

    _changesChannel = channel..subscribe();
  }

  void unsubscribeFromChanges() {
    final channel = _changesChannel;
    _changesChannel = null;
    if (channel != null) client.removeChannel(channel);
  }

  Map<String, dynamic> _profileUpdatePayload(User user) => {
        'name': user.name.trim(),
        'phone': normalizePhone(user.phone),
        'address': user.address.trim(),
        'origin_country': user.originCountry.trim().isEmpty ? null : user.originCountry.trim(),
        'origin_region': user.originRegion.trim().isEmpty ? null : user.originRegion.trim(),
        'language': user.language == null ? 'pt-BR' : languageToJson(user.language!),
        'avatar_url': user.avatarPath,
        'lgpd_accepted_at': user.lgpdAcceptedAt,
        'lgpd_version': user.lgpdVersion ?? lgpdVersion,
        'password_updated_at': user.passwordUpdatedAt,
      };

  User _userFromSupabase(Map<String, dynamic> json, {required UserRole role}) => User(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        phone: normalizePhone(json['phone'] as String? ?? ''),
        email: normalizeEmail(json['email'] as String? ?? ''),
        address: json['address'] as String? ?? '',
        originCountry: json['origin_country'] as String? ?? '',
        originRegion: json['origin_region'] as String? ?? '',
        role: role,
        language: languageFromJson(json['language'] as String?),
        avatarPath: json['avatar_url'] as String?,
        lgpdAcceptedAt: json['lgpd_accepted_at'] as String?,
        lgpdVersion: json['lgpd_version'] as String? ?? lgpdVersion,
        passwordUpdatedAt: json['password_updated_at'] as String?,
        createdAt: json['created_at'] as String? ?? DateTime.now().toIso8601String(),
        updatedAt: json['updated_at'] as String?,
      );

  Post _postFromSupabase(Map<String, dynamic> json) => Post(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        authorId: json['author_id'] as String? ?? '',
        authorName: json['author_name'] as String? ?? '',
        authorRole: roleFromJson(json['author_role'] as String?),
        images: List<String>.from(json['images'] as List? ?? const []),
        createdAt: json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      );

  Comment _commentFromSupabase(Map<String, dynamic> json) => Comment(
        id: json['id'] as String? ?? '',
        postId: json['post_id'] as String? ?? '',
        authorId: json['author_id'] as String? ?? '',
        authorName: json['author_name'] as String? ?? '',
        authorRole: roleFromJson(json['author_role'] as String?),
        text: json['text'] as String? ?? '',
        createdAt: json['created_at'] as String? ?? DateTime.now().toIso8601String(),
        parentId: json['parent_id'] as String?,
        replyToAuthorId: json['reply_to_author_id'] as String?,
        replyToName: json['reply_to_name'] as String?,
      );

  SenaiCourse _courseFromSupabase(Map<String, dynamic> json) => SenaiCourse(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        institutionAddress: json['institution_address'] as String? ?? '',
        createdById: json['created_by_id'] as String?,
        createdByName: json['created_by_name'] as String?,
        createdAt: json['created_at'] as String?,
      );

  CartilhaContent _cartilhaFromSupabase(Map<String, dynamic> json) => CartilhaContent(
        id: json['id'] as String? ?? '',
        type: cartilhaTypeFromJson(json['type'] as String?),
        title: json['title'] as String? ?? '',
        titleEs: json['title_es'] as String? ?? '',
        textPt: json['text_pt'] as String? ?? '',
        textEs: json['text_es'] as String? ?? '',
        explanation: json['explanation'] as String? ?? '',
        explanationEs: json['explanation_es'] as String? ?? '',
        createdById: json['created_by_id'] as String?,
        createdByName: json['created_by_name'] as String?,
        createdAt: json['created_at'] as String?,
      );
}
