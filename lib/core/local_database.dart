import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import 'models.dart';
import 'permissions.dart';
import 'supabase_config.dart';

class LocalDatabase {
  bool _supabaseInitialized = false;

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
        anonKey: SupabaseConfig.anonKey,
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
      _loadPosts(),
      _loadComments(),
      _loadCourses(),
      _loadCartilha(),
      _loadReadNotifications(),
    ]);
  }

  Future<void> _loadCurrentUser() async {
    _users.clear();
    final authUser = client.auth.currentUser;
    if (authUser == null) return;
    final profile = await getUserByIdRemote(authUser.id);
    if (profile != null) _users.add(profile);
  }

  Future<void> _loadPosts() async {
    final data = await client.from('posts').select('*').order('created_at', ascending: false);
    _posts
      ..clear()
      ..addAll((data as List).map((item) => _postFromSupabase(Map<String, dynamic>.from(item as Map))));
  }

  Future<void> _loadComments() async {
    final data = await client.from('comments').select('*').order('created_at', ascending: true);
    _comments
      ..clear()
      ..addAll((data as List).map((item) => _commentFromSupabase(Map<String, dynamic>.from(item as Map))));
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

  User? getUserByPhone(String phone) {
    final normalized = normalizePhone(phone);
    for (final user in _users) {
      if (normalizePhone(user.phone) == normalized) return user;
    }
    return null;
  }

  User? getUserByEmail(String email) {
    final normalized = normalizeEmail(email);
    for (final user in _users) {
      if (normalizeEmail(user.email) == normalized) return user;
    }
    return null;
  }

  Future<User?> getUserByIdRemote(String id) async {
    final data = await client.from('profiles').select('*').eq('id', id).maybeSingle();
    if (data == null) return null;
    return _userFromSupabase(Map<String, dynamic>.from(data));
  }

  Future<User?> findUserByPhone(String phone) async {
    final data = await client.rpc('find_profile_by_phone', params: {'profile_phone': normalizePhone(phone)});
    final rows = data as List?;
    if (rows == null || rows.isEmpty) return null;
    return _userFromSupabase(Map<String, dynamic>.from(rows.first as Map));
  }

  Future<User?> findUserByEmail(String email) async {
    final data = await client.rpc('find_profile_by_email', params: {'profile_email': normalizeEmail(email)});
    final rows = data as List?;
    if (rows == null || rows.isEmpty) return null;
    return _userFromSupabase(Map<String, dynamic>.from(rows.first as Map));
  }

  Future<User?> signInWithPhone({required String phone, required String password}) async {
    final account = await findUserByPhone(phone);
    if (account == null) return null;

    final response = await client.auth.signInWithPassword(email: account.email, password: password);
    final authUser = response.user;
    if (authUser == null) return null;
    final user = await getUserByIdRemote(authUser.id);
    _users
      ..clear()
      ..addAll(user == null ? [] : [user]);
    await refreshAll();
    return user;
  }

  Future<User> signUpUser({
    required String name,
    required String phone,
    required String email,
    required String address,
    required String password,
    required AppLanguage language,
  }) async {
    final normalizedEmail = normalizeEmail(email);
    final normalizedPhone = normalizePhone(phone);
    final now = DateTime.now().toIso8601String();

    final response = await client.auth.signUp(
      email: normalizedEmail,
      password: password,
      data: {
        'name': name.trim(),
        'phone': normalizedPhone,
        'email': normalizedEmail,
        'address': address.trim(),
        'role': roleToJson(roleFromEmail(normalizedEmail)),
        'language': languageToJson(language),
        'lgpd_accepted_at': now,
        'lgpd_version': lgpdVersion,
      },
    );

    final authUser = response.user;
    if (authUser == null) throw StateError('Não foi possível criar o usuário no Supabase Auth.');

    final user = await getUserByIdRemote(authUser.id);
    if (user == null) throw StateError('Perfil criado pelo Auth, mas não foi possível carregar os dados. Confira se o provedor Email está habilitado e se Confirm email está desativado.');
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
  }

  Future<void> addUser(User user) async {
    await client.from('profiles').upsert(_profilePayload(user), onConflict: 'id');
    final saved = await getUserByIdRemote(user.id);
    if (saved != null) {
      _users
        ..clear()
        ..add(saved);
    }
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
    final saved = _userFromSupabase(Map<String, dynamic>.from(data));
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
  Future<User?> sendPasswordResetByPhone(String phone) async {
    final user = await findUserByPhone(phone);
    if (user == null) return null;
    await client.auth.resetPasswordForEmail(user.email);
    return user;
  }

  Future<void> resetPasswordWithCode({required String phone, required String code, required String newPassword}) async {
    final account = await findUserByPhone(phone);
    if (account == null) throw StateError('Telefone não encontrado.');

    await client.auth.verifyOTP(email: account.email, token: code, type: OtpType.recovery);
    try {
      await client.auth.updateUser(UserAttributes(password: newPassword));
      await client
          .from('profiles')
          .update({'password_updated_at': DateTime.now().toIso8601String()})
          .eq('id', account.id);
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

  Future<void> addPost(Post post) async {
    await client.from('posts').insert({
      'title': post.title,
      'body': post.body,
      'author_id': post.authorId,
      'author_name': post.authorName,
      'author_role': roleToJson(post.authorRole),
      'images': post.images,
    });
    await _loadPosts();
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

  Future<void> addComment(Comment comment) async {
    await client.from('comments').insert({
      'post_id': comment.postId,
      'author_id': comment.authorId,
      'author_name': comment.authorName,
      'author_role': roleToJson(comment.authorRole),
      'text': comment.text,
    });
    await _loadComments();
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
      'text_pt': content.textPt,
      'text_es': content.textEs,
      'explanation': content.explanation,
      'created_by_id': content.createdById,
      'created_by_name': content.createdByName,
    });
    await _loadCartilha();
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

  // Ninguém é notificado do próprio conteúdo.
  bool _isMine(String? authorId) => authorId != null && authorId == client.auth.currentUser?.id;

  AppNotification? _postNotification(Post post) {
    if (_isMine(post.authorId)) return null;
    final id = 'post-${post.id}';
    return AppNotification(
      id: id,
      type: 'post',
      title: 'Nova publicação no fórum',
      body: post.title,
      targetRoute: '/forum/${post.id}',
      createdAt: post.createdAt,
      read: _readNotificationIds.contains(id),
    );
  }

  // Comentários só interessam a quem escreveu a publicação ou já participou da conversa.
  AppNotification? _commentNotification(Comment comment) {
    if (_isMine(comment.authorId)) return null;
    final isPostAuthor = _isMine(getPostById(comment.postId)?.authorId);
    final participated = _comments.any((other) => other.postId == comment.postId && _isMine(other.authorId));
    if (!isPostAuthor && !participated) return null;
    final id = 'comment-${comment.id}';
    return AppNotification(
      id: id,
      type: 'comment',
      title: isPostAuthor ? 'Novo comentário na sua publicação' : 'Nova resposta em uma conversa sua',
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
      title: 'Novo curso no catálogo SENAI',
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
      title: 'Nova orientação trabalhista',
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

    _changesChannel = channel..subscribe();
  }

  void unsubscribeFromChanges() {
    final channel = _changesChannel;
    _changesChannel = null;
    if (channel != null) client.removeChannel(channel);
  }

  Map<String, dynamic> _profilePayload(User user) => {
        'id': user.id,
        'name': user.name.trim(),
        'phone': normalizePhone(user.phone),
        'email': normalizeEmail(user.email),
        'address': user.address.trim(),
        'role': roleToJson(user.role),
        'language': user.language == null ? 'pt-BR' : languageToJson(user.language!),
        'avatar_url': user.avatarPath,
        'lgpd_accepted_at': user.lgpdAcceptedAt,
        'lgpd_version': user.lgpdVersion ?? lgpdVersion,
        'password_updated_at': user.passwordUpdatedAt,
      };

  Map<String, dynamic> _profileUpdatePayload(User user) => {
        'name': user.name.trim(),
        'phone': normalizePhone(user.phone),
        'address': user.address.trim(),
        'language': user.language == null ? 'pt-BR' : languageToJson(user.language!),
        'avatar_url': user.avatarPath,
        'lgpd_accepted_at': user.lgpdAcceptedAt,
        'lgpd_version': user.lgpdVersion ?? lgpdVersion,
        'password_updated_at': user.passwordUpdatedAt,
      };

  User _userFromSupabase(Map<String, dynamic> json) => User(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        phone: normalizePhone(json['phone'] as String? ?? ''),
        email: normalizeEmail(json['email'] as String? ?? ''),
        address: json['address'] as String? ?? '',
        role: roleFromJson(json['role'] as String?),
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
        textPt: json['text_pt'] as String? ?? '',
        textEs: json['text_es'] as String? ?? '',
        explanation: json['explanation'] as String? ?? '',
        createdById: json['created_by_id'] as String?,
        createdByName: json['created_by_name'] as String?,
        createdAt: json['created_at'] as String?,
      );
}
