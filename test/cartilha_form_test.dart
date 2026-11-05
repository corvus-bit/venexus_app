import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:venexus/core/app_state.dart';
import 'package:venexus/core/local_database.dart';
import 'package:venexus/core/models.dart';
import 'package:venexus/main.dart';
import 'package:venexus/screens/cartilha_screen.dart';

const _admin = User(
  id: 'admin',
  name: 'Equipe',
  phone: '46999991111',
  email: 'equipe@sistemafiep.org.br',
  address: 'Pato Branco - PR',
  role: UserRole.admin,
  language: AppLanguage.ptBR,
  createdAt: '2026-01-01T12:00:00.000Z',
);

class _FakeDatabase extends LocalDatabase {
  final saved = <CartilhaContent>[];

  @override
  Future<void> init() async {}

  @override
  Future<void> refreshAll() async {}

  @override
  User? getCurrentUser() => _admin;

  @override
  List<Post> getPosts() => const [];

  @override
  List<SenaiCourse> getCourses() => const [];

  @override
  List<CartilhaContent> getCartilha() => List.unmodifiable(saved);

  @override
  List<AppNotification> getNotifications() => const [];

  @override
  void subscribeToChanges(void Function(AppNotification? notification) onChange) {}

  @override
  void unsubscribeFromChanges() {}

  @override
  Future<void> addCartilha(CartilhaContent content) async => saved.add(content);
}

void main() {
  late _FakeDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = _FakeDatabase();
    appState = AppState(db: db);
    await appState.init();
  });

  Future<void> openForm(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: CartilhaScreen()));
    await tester.tap(find.text(appState.t('cartilha.publish')).first);
    await tester.pumpAndSettle();
  }

  Finder field(String key) => find.widgetWithText(TextField, '${appState.t(key)} *');

  testWidgets('saving with the Spanish title empty explains what is missing', (tester) async {
    await openForm(tester);

    await tester.enterText(field('cartilha.titlePt'), 'Férias');
    await tester.enterText(field('cartilha.textPt'), 'Texto');
    await tester.enterText(field('cartilha.textEs'), 'Texto');
    await tester.tap(find.text(appState.t('common.save').toUpperCase()));
    await tester.pump();

    expect(find.text(appState.t('common.fillRequired')), findsOneWidget);
    expect(find.text(appState.t('common.required')), findsOneWidget);
    expect(db.saved, isEmpty);
  });

  testWidgets('saving with every required field publishes and confirms', (tester) async {
    await openForm(tester);

    await tester.enterText(field('cartilha.titlePt'), 'Férias');
    await tester.enterText(field('cartilha.titleEs'), 'Vacaciones');
    await tester.enterText(field('cartilha.textPt'), 'Texto');
    await tester.enterText(field('cartilha.textEs'), 'Texto');
    await tester.tap(find.text(appState.t('common.save').toUpperCase()));
    await tester.pump();

    expect(db.saved.single.titleEs, 'Vacaciones');
    expect(find.text(appState.t('common.published')), findsOneWidget);
  });
}
