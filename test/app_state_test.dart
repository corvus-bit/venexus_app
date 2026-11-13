import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:venexus/core/app_state.dart';
import 'package:venexus/core/local_database.dart';
import 'package:venexus/core/models.dart';
import 'package:venexus/core/permissions.dart';

const _now = '2026-01-01T12:00:00.000Z';

const _reader = User(
  id: 'reader',
  name: 'Ana',
  phone: '46999990000',
  email: 'ana@example.com',
  address: 'Pato Branco - PR',
  role: UserRole.reader,
  createdAt: _now,
);

const _admin = User(
  id: 'admin',
  name: 'Equipe',
  phone: '46999991111',
  email: 'equipe@sistemafiep.org.br',
  address: 'Pato Branco - PR',
  role: UserRole.admin,
  createdAt: _now,
);

/// Banco em memória: nada aqui fala com o Supabase.
class _FakeDatabase extends LocalDatabase {
  _FakeDatabase({this.user, this.failWith});

  final User? user;

  /// Quando definido, as gravações lançam este erro.
  final Object? failWith;

  final posts = <Post>[];
  String? editedPostTitle;
  String? editedPostBody;
  String? editedCommentText;

  @override
  Future<void> init() async {}

  @override
  Future<void> refreshAll() async {}

  @override
  String? get venexusMembershipStatus => 'active';

  @override
  User? getCurrentUser() => user;

  @override
  List<Post> getPosts() => List.unmodifiable(posts);

  @override
  List<SenaiCourse> getCourses() => const [];

  @override
  List<CartilhaContent> getCartilha() => const [
        CartilhaContent(
          id: 'c1',
          type: CartilhaType.expressions,
          title: 'Bater o ponto',
          titleEs: 'Fichar',
          textPt: 'Registrar o horário de chegada e saída.',
          textEs: 'Registrar la hora de llegada y salida.',
          explanation: 'Garante o pagamento das horas.',
          explanationEs: 'Garantiza el pago de las horas.',
        ),
      ];

  @override
  List<AppNotification> getNotifications() => const [];

  @override
  void subscribeToChanges(void Function(AppNotification? notification) onChange) {}

  @override
  void unsubscribeFromChanges() {}

  @override
  Future<User> updateUser(User updatedUser) async => updatedUser;

  @override
  Future<void> addPost(Post post) async {
    if (failWith != null) throw failWith!;
    posts.insert(0, post);
  }

  @override
  Future<void> updatePost(Post post, {required String title, required String body}) async {
    if (failWith != null) throw failWith!;
    editedPostTitle = title;
    editedPostBody = body;
  }

  @override
  Future<void> updateComment(Comment comment, {required String text}) async {
    if (failWith != null) throw failWith!;
    editedCommentText = text;
  }
}

Future<AppState> _appState(_FakeDatabase db) async {
  final state = AppState(db: db);
  await state.init();
  return state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('reading preferences survive reopening the app', () async {
    final first = await _appState(_FakeDatabase(user: _reader));
    await first.updateReadingPreferences(bionic: true, scale: 1.5, spacing: true, focus: true);

    final reopened = await _appState(_FakeDatabase(user: _reader));
    expect(reopened.bionicReading, isTrue);
    expect(reopened.readingScale, 1.5);
    expect(reopened.readingSpacing, isTrue);
    expect(reopened.readingFocus, isTrue);
  });

  group('search', () {
    test('finds cartilha content by its Spanish title and explanation', () async {
      final state = await _appState(_FakeDatabase(user: _reader));
      await state.updateLanguage(AppLanguage.es);

      final byTitle = state.search('fichar');
      expect(byTitle, hasLength(1));
      expect(byTitle.single.title, 'Fichar');

      expect(state.search('garantiza'), hasLength(1));
    });

    test('shows the Portuguese title for Portuguese readers', () async {
      final state = await _appState(_FakeDatabase(user: _reader));
      await state.updateLanguage(AppLanguage.ptBR);

      expect(state.search('fichar').single.title, 'Bater o ponto');
    });

    test('ignores queries shorter than two characters', () async {
      final state = await _appState(_FakeDatabase(user: _reader));
      expect(state.search('a'), isEmpty);
    });
  });

  group('addPost', () {
    test('returns null and publishes when the database accepts it', () async {
      final db = _FakeDatabase(user: _reader);
      final state = await _appState(db);

      final error = await state.addPost(title: ' Título ', body: ' Corpo ', images: const []);

      expect(error, isNull);
      expect(db.posts.single.title, 'Título');
    });

    test('returns a message instead of throwing when the database fails', () async {
      final state = await _appState(_FakeDatabase(user: _reader, failWith: StateError('rls')));

      final error = await state.addPost(title: 'Título', body: 'Corpo', images: const []);

      expect(error, state.t('forum.postFailed'));
    });

    test('reports connection problems separately', () async {
      final state = await _appState(_FakeDatabase(user: _reader, failWith: const SocketException('Failed host lookup')));

      final error = await state.addPost(title: 'Título', body: 'Corpo', images: const []);

      expect(error, state.t('common.networkError'));
    });

    test('requires a signed-in user', () async {
      final state = await _appState(_FakeDatabase());

      final error = await state.addPost(title: 'Título', body: 'Corpo', images: const []);

      expect(error, state.t('auth.notAuthenticated'));
    });
  });

  group('edit own forum messages', () {
    const post = Post(id: 'p1', title: 'Antes', body: 'Texto', authorId: 'reader', authorName: 'Ana', images: [], createdAt: _now);
    const comment = Comment(id: 'c1', postId: 'p1', authorId: 'reader', authorName: 'Ana', text: 'Antes', createdAt: _now);

    test('saves trimmed post and comment text', () async {
      final db = _FakeDatabase(user: _reader);
      final state = await _appState(db);

      expect(await state.updatePost(post, title: ' Novo ', body: ' Conteúdo '), isNull);
      expect(await state.updateComment(comment, text: ' Resposta '), isNull);
      expect(db.editedPostTitle, 'Novo');
      expect(db.editedPostBody, 'Conteúdo');
      expect(db.editedCommentText, 'Resposta');
    });

    test('denies an administrator editing another author and rejects empty text', () async {
      final db = _FakeDatabase(user: _admin);
      final state = await _appState(db);
      expect(await state.updatePost(post, title: 'Outro', body: 'Texto'), state.t('forum.editDenied'));
      expect(await state.updateComment(comment, text: 'Outro'), state.t('forum.editDenied'));
      expect(db.editedPostTitle, isNull);
      expect(db.editedCommentText, isNull);

      final author = await _appState(_FakeDatabase(user: _reader));
      expect(await author.updatePost(post, title: ' ', body: 'Texto'), author.t('forum.invalidPost'));
      expect(await author.updateComment(comment, text: ' '), author.t('forum.invalidComment'));
    });
  });

  group('isNetworkError', () {
    test('recognizes connection failures', () {
      expect(AppState.isNetworkError(const SocketException('Failed host lookup')), isTrue);
      expect(AppState.isNetworkError(TimeoutException('slow')), isTrue);
    });

    test('does not treat other errors as connection failures', () {
      expect(AppState.isNetworkError(StateError('delete-denied')), isFalse);
    });
  });

  group('canDeleteComment', () {
    const comment = Comment(id: 'c1', postId: 'p1', authorId: 'reader', authorName: 'Ana', text: 'Oi', createdAt: _now);
    const other = User(
      id: 'other',
      name: 'Beto',
      phone: '46999992222',
      email: 'beto@example.com',
      address: '',
      role: UserRole.reader,
      createdAt: _now,
    );

    test('allows the author and admins', () {
      expect(canDeleteComment(_reader, comment), isTrue);
      expect(canDeleteComment(_admin, comment), isTrue);
    });

    test('denies other readers and anonymous users', () {
      expect(canDeleteComment(other, comment), isFalse);
      expect(canDeleteComment(null, comment), isFalse);
    });
  });
}
