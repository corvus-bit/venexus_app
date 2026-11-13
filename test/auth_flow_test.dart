import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException, FunctionException, PostgrestException;
import 'package:venexus/core/app_state.dart';
import 'package:venexus/core/local_database.dart';
import 'package:venexus/core/models.dart';

const _ana = User(
  id: 'ana',
  name: 'Ana',
  phone: '46999990000',
  email: 'ana@example.com',
  address: 'Pato Branco - PR',
  role: UserRole.reader,
  createdAt: '2026-01-01T12:00:00.000Z',
);

/// Simula as respostas do Supabase (Edge Function phone-auth, Auth e banco) sem rede.
class _FakeDatabase extends LocalDatabase {
  _FakeDatabase({this.user, this.membershipStatus = 'active', this.failWith, this.joinResult});

  User? user;
  String? membershipStatus;

  /// Erro lançado pelas operações de autenticação e de perfil.
  Object? failWith;

  /// Status do vínculo depois de `join_app`.
  String? joinResult;

  final calls = <String>[];

  @override
  Future<void> init() async {}

  @override
  Future<void> refreshAll() async {}

  @override
  String? get venexusMembershipStatus => membershipStatus;

  @override
  User? getCurrentUser() => user;

  @override
  List<Post> getPosts() => const [];

  @override
  List<SenaiCourse> getCourses() => const [];

  @override
  List<CartilhaContent> getCartilha() => const [];

  @override
  List<AppNotification> getNotifications() => const [];

  @override
  void subscribeToChanges(void Function(AppNotification? notification) onChange) => calls.add('subscribe');

  @override
  void unsubscribeFromChanges() {}

  @override
  Future<User?> signInWithPhone({required String phone, required String password}) async {
    calls.add('signIn');
    if (failWith != null) throw failWith!;
    return user = _ana;
  }

  @override
  Future<User?> signUpUser({
    required String name,
    required String phone,
    required String email,
    required String address,
    required String password,
    required AppLanguage language,
  }) async {
    calls.add('signUp');
    if (failWith != null) throw failWith!;
    return null;
  }

  @override
  Future<void> sendPasswordResetByPhone(String phone) async {
    calls.add('recover');
    if (failWith != null) throw failWith!;
  }

  @override
  Future<void> resetPasswordWithCode({required String phone, required String code, required String newPassword}) async {
    calls.add('reset');
    if (failWith != null) throw failWith!;
  }

  @override
  Future<User> updateUser(User updatedUser) async {
    calls.add('updateUser');
    if (failWith != null) throw failWith!;
    return updatedUser;
  }

  @override
  Future<User?> joinVenexus() async {
    calls.add('join');
    if (failWith != null) throw failWith!;
    membershipStatus = joinResult;
    return user;
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

  group('login por telefone', () {
    test('entra quando a função devolve a sessão', () async {
      final state = await _appState(_FakeDatabase(membershipStatus: 'active'));

      expect(await state.login(phone: '(46) 99999-0000', password: 'segredo'), isNull);
      expect(state.isLoggedIn, isTrue);
      expect(state.hasVenexusAccess, isTrue);
    });

    test('telefone inexistente e senha errada têm a mesma mensagem', () async {
      final state = await _appState(_FakeDatabase(failWith: const PhoneAuthException('invalid_credentials')));

      expect(await state.login(phone: '46999990000', password: 'errada'), state.t('auth.invalid'));
      expect(state.isLoggedIn, isFalse);
    });

    test('limite de tentativas e indisponibilidade não viram "senha inválida"', () async {
      final limited = await _appState(_FakeDatabase(failWith: const PhoneAuthException('rate_limited')));
      expect(await limited.login(phone: '46999990000', password: 'x'), limited.t('auth.resetRateLimit'));

      final down = await _appState(_FakeDatabase(failWith: const PhoneAuthException('unavailable')));
      expect(await down.login(phone: '46999990000', password: 'x'), down.t('common.serviceUnavailable'));

      final offline = await _appState(_FakeDatabase(failWith: const FunctionException(status: 0, details: SocketException('offline'))));
      expect(await offline.login(phone: '46999990000', password: 'x'), offline.t('common.networkError'));
    });

    test('e-mail não confirmado leva para a confirmação, sem abrir sessão', () async {
      final state = await _appState(_FakeDatabase(failWith: const EmailNotConfirmedException('ana@example.com')));

      expect(await state.login(phone: '46999990000', password: 'segredo'), isNull);
      expect(state.pendingConfirmationEmail, 'ana@example.com');
      expect(state.isLoggedIn, isFalse);
    });
  });

  group('cadastro', () {
    test('vai direto ao Auth, sem consultar se telefone ou e-mail existem', () async {
      final db = _FakeDatabase();
      final state = await _appState(db);

      final error = await state.register(name: 'Ana', phone: '46999990000', email: 'Ana@Example.com', address: 'Rua', password: 'segredo', lgpdAccepted: true);

      expect(error, isNull);
      expect(db.calls, ['signUp']);
      expect(state.pendingConfirmationEmail, 'ana@example.com');
    });

    test('conta já existente (e-mail ou telefone) recebe a mesma orientação', () async {
      for (final failure in <Object>[
        const AccountAlreadyExistsException(),
        const AuthException('Database error saving new user', statusCode: '500', code: 'unexpected_failure'),
        const AuthException('User already registered', statusCode: '422', code: 'user_already_exists'),
      ]) {
        final state = await _appState(_FakeDatabase(failWith: failure));
        final error = await state.register(name: 'Ana', phone: '46999990000', email: 'ana@example.com', address: 'Rua', password: 'segredo', lgpdAccepted: true);
        expect(error, state.t('auth.duplicatedAccount'), reason: '$failure');
      }
    });

    test('exige o aceite do termo antes de qualquer chamada', () async {
      final db = _FakeDatabase();
      final state = await _appState(db);

      final error = await state.register(name: 'Ana', phone: '46999990000', email: 'ana@example.com', address: 'Rua', password: 'segredo', lgpdAccepted: false);

      expect(error, state.t('auth.lgpdRequired'));
      expect(db.calls, isEmpty);
    });
  });

  group('recuperação de senha', () {
    test('não diz se o telefone tem conta', () async {
      final state = await _appState(_FakeDatabase());
      expect(await state.requestPasswordReset(phone: '46900000000'), isNull);
    });

    test('limite de tentativas tem mensagem própria', () async {
      final state = await _appState(_FakeDatabase(failWith: const PhoneAuthException('rate_limited')));
      expect(await state.requestPasswordReset(phone: '46999990000'), state.t('auth.resetRateLimit'));
    });

    test('código errado ou de telefone desconhecido tem a mesma mensagem', () async {
      final state = await _appState(_FakeDatabase(failWith: const PhoneAuthException('invalid_code')));
      final error = await state.resetPasswordWithCode(phone: '46999990000', code: '12345678', newPassword: 'segredo1', confirmPassword: 'segredo1');
      expect(error, state.t('auth.resetInvalidCode'));
    });
  });

  group('perfil', () {
    test('telefone de outra conta é recusado pelo banco, não por consulta prévia', () async {
      final db = _FakeDatabase(user: _ana, failWith: const PostgrestException(message: 'duplicate key', code: '23505'));
      final state = await _appState(db);

      final error = await state.updateProfile(name: 'Ana', phone: '46999991111', address: 'Rua', language: AppLanguage.ptBR);

      expect(error, state.t('auth.duplicatedPhone'));
      expect(db.calls, ['subscribe', 'updateUser']);
    });
  });

  group('acesso ao Venexus', () {
    test('conta de outro aplicativo fica sem acesso até aceitar o termo e entrar', () async {
      final db = _FakeDatabase(user: _ana, membershipStatus: null, joinResult: 'active');
      final state = await _appState(db);
      expect(state.isLoggedIn, isTrue);
      expect(state.hasVenexusAccess, isFalse);

      expect(await state.joinVenexus(lgpdAccepted: false), state.t('auth.lgpdRequired'));
      expect(db.calls.contains('join'), isFalse);

      expect(await state.joinVenexus(lgpdAccepted: true), isNull);
      expect(state.hasVenexusAccess, isTrue);
    });

    test('vínculo revogado não é reativado pelo usuário', () async {
      final state = await _appState(_FakeDatabase(user: _ana, membershipStatus: 'revoked', joinResult: 'revoked'));

      expect(state.hasVenexusAccess, isFalse);
      expect(await state.joinVenexus(lgpdAccepted: true), state.t('access.denied'));
      expect(state.hasVenexusAccess, isFalse);
    });
  });
}
