// Telas reais do app para as capturas da Google Play, com dados de exemplo.
// Fora de test/: só roda quando pedido.
//
//   flutter test tool/render_store_shots_test.dart
//   python tool/store_assets.py
//
// Saída: build/store_shots/<idioma>/*.png (tela crua). O script Python monta
// as capturas finais, o ícone e o gráfico de recursos em prints/.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:venexus/core/app_state.dart';
import 'package:venexus/core/local_database.dart';
import 'package:venexus/core/models.dart';
import 'package:venexus/main.dart';

/// Pixels de um celular 1080 × 2160 (1:2), 2,75 px por dp.
const _dpr = 2.75;
const _size = Size(1080, 2160);

const _me = 'user_maria';

String _ago(Duration d) => DateTime.now().subtract(d).toIso8601String();

/// Banco em memória: as telas leem daqui em vez do Supabase.
class _ExampleDatabase extends LocalDatabase {
  _ExampleDatabase(this.language);

  final AppLanguage language;

  late final _user = User(
    id: _me,
    name: 'María González',
    phone: '(46) 99999-0000',
    email: 'maria@exemplo.com',
    address: 'Pato Branco - PR',
    role: UserRole.reader,
    language: language,
    createdAt: _ago(const Duration(days: 30)),
  );

  String _l(String pt, String es) => language == AppLanguage.es ? es : pt;

  late final _posts = [
    Post(
      id: 'p1',
      title: _l('Quais documentos levar na admissão?', '¿Qué documentos llevar a la contratación?'),
      body: _l('Fui chamado para auxiliar de produção. Além do CPF e da carteira de trabalho digital, o que mais costumam pedir?', 'Me llamaron para auxiliar de producción. Además del CPF y la cartera de trabajo digital, ¿qué más suelen pedir?'),
      authorId: 'u2',
      authorName: 'Carlos Pérez',
      images: const [],
      createdAt: _ago(const Duration(hours: 2)),
    ),
    Post(
      id: 'p2',
      title: _l('Como funciona o transporte fretado?', '¿Cómo funciona el transporte de la empresa?'),
      body: _l('Me disseram que a maioria das indústrias daqui tem ônibus próprio. Eles descontam do salário?', 'Me dijeron que la mayoría de las industrias de aquí tiene bus propio. ¿Lo descuentan del sueldo?'),
      authorId: 'u3',
      authorName: 'Yuleisy Rodríguez',
      images: const [],
      createdAt: _ago(const Duration(hours: 9)),
    ),
    Post(
      id: 'p3',
      title: _l('Inscrições abertas para Operador de Empilhadeira', 'Inscripciones abiertas: Operador de Montacargas'),
      body: _l('As vagas do próximo curso gratuito já estão no Catálogo SENAI. Procure a secretaria com seus documentos.', 'Las plazas del próximo curso gratuito ya están en el Catálogo SENAI. Acude a la secretaría con tus documentos.'),
      authorId: 'admin',
      authorName: 'Equipe SENAI',
      authorRole: UserRole.admin,
      images: const [],
      createdAt: _ago(const Duration(days: 1)),
    ),
    Post(
      id: 'p4',
      title: _l('Dica: abrir conta no banco pelo celular', 'Consejo: abrir cuenta bancaria por el celular'),
      body: _l('Consegui abrir a minha só com o CPF e o protocolo de refúgio. Levou uns 10 minutos.', 'Pude abrir la mía solo con el CPF y el protocolo de refugio. Tardó unos 10 minutos.'),
      authorId: 'u4',
      authorName: 'José Martínez',
      images: const [],
      createdAt: _ago(const Duration(days: 2)),
    ),
  ];

  late final _comments = [
    Comment(
      id: 'c1',
      postId: 'p1',
      authorId: 'admin',
      authorName: 'Equipe SENAI',
      authorRole: UserRole.admin,
      text: _l('Normalmente pedem comprovante de endereço, CRNM ou protocolo de refúgio, foto 3x4 e os dados bancários. Confira a lista com o RH.', 'Normalmente piden comprobante de domicilio, CRNM o protocolo de refugio, foto 3x4 y datos bancarios. Confirma la lista con RR. HH.'),
      createdAt: _ago(const Duration(hours: 1, minutes: 40)),
    ),
    Comment(
      id: 'c2',
      postId: 'p1',
      authorId: 'u4',
      authorName: 'José Martínez',
      text: _l('Na minha empresa também pediram o exame admissional, mas eles mesmos marcaram.', 'En mi empresa también pidieron el examen médico de ingreso, pero ellos mismos lo agendaron.'),
      createdAt: _ago(const Duration(hours: 1, minutes: 10)),
    ),
    Comment(
      id: 'c3',
      postId: 'p1',
      authorId: 'u2',
      authorName: 'Carlos Pérez',
      text: _l('Obrigado! Vou separar tudo hoje.', '¡Gracias! Hoy mismo junto todo.'),
      createdAt: _ago(const Duration(minutes: 50)),
      parentId: 'c1',
      replyToAuthorId: 'admin',
      replyToName: 'Equipe SENAI',
    ),
  ];

  final _courses = [
    SenaiCourse(
      id: 's1',
      name: 'Operador de Empilhadeira',
      description: 'Capacitação para operação segura e eficiente de empilhadeiras, seguindo as normas de segurança do trabalho.',
      institutionAddress: 'Rua Xingu, 833 - Amadori, Pato Branco - PR',
      createdById: 'admin',
      createdByName: 'Equipe SENAI',
      createdAt: _ago(const Duration(days: 1)),
    ),
    SenaiCourse(
      id: 's2',
      name: 'Auxiliar de Linha de Produção',
      description: 'Noções básicas sobre o funcionamento e a organização do setor produtivo industrial.',
      institutionAddress: 'Rua Xingu, 833 - Amadori, Pato Branco - PR',
      createdById: 'admin',
      createdByName: 'Equipe SENAI',
      createdAt: _ago(const Duration(days: 4)),
    ),
    SenaiCourse(
      id: 's3',
      name: 'Segurança no Trabalho (NR-12 Básica)',
      description: 'Orientação sobre segurança no manuseio de máquinas e equipamentos industriais.',
      institutionAddress: 'Rua Xingu, 833 - Amadori, Pato Branco - PR',
      createdById: 'admin',
      createdByName: 'Equipe SENAI',
      createdAt: _ago(const Duration(days: 6)),
    ),
  ];

  final _cartilha = [
    CartilhaContent(
      id: 'k1',
      type: CartilhaType.rights,
      title: 'Jornada de Trabalho e Horas Extras',
      titleEs: 'Jornada Laboral y Horas Extras',
      textPt: 'No Brasil, a jornada de trabalho normal é de 8 horas diárias e 44 horas semanais. Horas trabalhadas além desse limite devem ser pagas com acréscimo de no mínimo 50%.',
      textEs: 'En Brasil, la jornada laboral normal es de 8 horas diarias y 44 horas semanales. Las horas trabajadas más allá de este límite deben pagarse con un recargo de al menos el 50%.',
      explanation: 'Saber seus horários evita o trabalho excessivo não remunerado.',
      explanationEs: 'Conocer tus horarios evita el trabajo excesivo no remunerado.',
      createdById: 'admin',
      createdByName: 'Equipe SENAI',
      createdAt: _ago(const Duration(hours: 5)),
    ),
    CartilhaContent(
      id: 'k2',
      type: CartilhaType.rights,
      title: 'Equipamento de Proteção Individual (EPI)',
      titleEs: 'Equipo de Protección Individual (EPI)',
      textPt: 'O empregador é obrigado a fornecer gratuitamente equipamentos de proteção como botas, luvas e capacetes adequados ao risco da função.',
      textEs: 'El empleador está obligado a proporcionar gratuitamente equipos de protección como botas, guantes y cascos adecuados al riesgo de la función.',
      explanation: 'Sua segurança é o mais importante e é garantida por lei.',
      explanationEs: 'Tu seguridad es lo más importante y está garantizada por ley.',
      createdById: 'admin',
      createdByName: 'Equipe SENAI',
      createdAt: _ago(const Duration(days: 3)),
    ),
    CartilhaContent(
      id: 'k3',
      type: CartilhaType.expressions,
      title: 'Bater o ponto',
      titleEs: 'Fichar',
      textPt: 'Expressão usada para registrar o horário de chegada e saída do trabalho no relógio de ponto.',
      textEs: 'Expresión usada para registrar la hora de llegada y salida del trabajo en el reloj de fichar.',
      explanation: 'Não esqueça: garante o pagamento das suas horas.',
      explanationEs: 'No lo olvides: garantiza el pago de tus horas.',
      createdByName: 'Equipe SENAI',
    ),
  ];

  @override
  Future<void> init() async {}

  @override
  Future<void> refreshAll() async {}

  @override
  User? getCurrentUser() => _user;

  @override
  String? getCurrentUserId() => _me;

  @override
  List<User> getUsers() => [_user];

  @override
  List<Post> getPosts() => List.unmodifiable(_posts);

  @override
  Post? getPostById(String id) => _posts.where((p) => p.id == id).firstOrNull;

  @override
  List<Comment> getComments() => List.unmodifiable(_comments);

  @override
  List<Comment> getCommentsByPostId(String postId) => _comments.where((c) => c.postId == postId).toList();

  @override
  List<SenaiCourse> getCourses() => List.unmodifiable(_courses);

  @override
  List<CartilhaContent> getCartilha() => List.unmodifiable(_cartilha);

  @override
  List<AppNotification> getNotifications() => [
    AppNotification(id: 'n1', type: 'comment', title: '', body: '', createdAt: _ago(const Duration(minutes: 50))),
    AppNotification(id: 'n2', type: 'course', title: '', body: '', createdAt: _ago(const Duration(days: 1))),
  ];

  @override
  Future<void> markNotificationsRead(Iterable<String> ids) async {}

  @override
  void subscribeToChanges(void Function(AppNotification? notification) onChange) {}

  @override
  void unsubscribeFromChanges() {}
}

Future<void> _loadFonts() async {
  final sdk = Platform.environment['FLUTTER_ROOT'] ?? r'C:\Softwares\flutter';
  final dir = '$sdk/bin/cache/artifacts/material_fonts';
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      final bytes = File('$dir/$f').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  // O tema pede Inter, que não vem no app: no aparelho cai na Roboto do sistema.
  const roboto = [
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
    'roboto-black.ttf',
    'roboto-italic.ttf',
  ];
  await family('Inter', roboto);
  await family('Roboto', roboto);
  await family('MaterialIcons', ['materialicons-regular.otf']);
}

Future<void> _shot(WidgetTester tester, String dir, String name) async {
  await tester.pumpAndSettle();
  final boundary = tester.renderObject(find.byKey(const ValueKey('shot'))) as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: _dpr);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('build/store_shots/$dir/$name.png')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Future<void> _open(WidgetTester tester, String route) async {
  appState.navigatorKey.currentState!.pushNamed(route);
  await tester.pumpAndSettle();
}

/// Rola até [text] ficar no topo da lista, com uma folga para mostrar a borda do card.
Future<void> _alignTop(WidgetTester tester, String text) async {
  await tester.runAsync(() => Scrollable.ensureVisible(tester.element(find.text(text).first)));
  await tester.pumpAndSettle();
  await _scroll(tester, -24);
}

Future<void> _scroll(WidgetTester tester, double dy) async {
  await tester.drag(find.byType(Scrollable).first, Offset(0, -dy));
  await tester.pumpAndSettle();
}

void main() {
  for (final (language, dir) in [(AppLanguage.ptBR, 'pt'), (AppLanguage.es, 'es')]) {
    testWidgets('render store screenshots ($dir)', (tester) async {
      debugDisableShadows = false;
      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(_loadFonts);
      tester.view
        ..physicalSize = _size
        ..devicePixelRatio = _dpr
        // Barra de status (24 dp) e barra de gestos (16 dp) do Android.
        ..padding = const FakeViewPadding(top: 24 * _dpr, bottom: 16 * _dpr)
        ..viewPadding = const FakeViewPadding(top: 24 * _dpr, bottom: 16 * _dpr);
      addTearDown(tester.view.reset);

      appState = AppState(db: _ExampleDatabase(language));
      await tester.runAsync(appState.init);
      expect(appState.isLoggedIn, isTrue);

      await tester.pumpWidget(const RepaintBoundary(key: ValueKey('shot'), child: VenexusApp()));
      await tester.runAsync(() async {
        final context = tester.element(find.byType(MaterialApp));
        await precacheImage(const AssetImage('assets/images/logo_mark.png'), context);
      });
      await tester.pumpAndSettle();

      // 1. Início
      await _shot(tester, dir, '01_inicio');

      // 2. Cartilha: pula o aviso de perfil de consulta e mostra os cartões.
      await _open(tester, '/cartilha');
      await _alignTop(tester, appState.cartilha.first.titleFor(language));
      await _shot(tester, dir, '02_cartilha');

      // 3. Fórum
      await _open(tester, '/forum');
      await _shot(tester, dir, '03_forum');

      // 4. Conversa de uma publicação, com a resposta aberta.
      await _open(tester, '/forum/p1');
      final showReplies = find.textContaining(RegExp(r'(respostas|respuestas) \(1\)', caseSensitive: false));
      if (showReplies.evaluate().isNotEmpty) await tester.tap(showReplies.first);
      await tester.pumpAndSettle();
      await _alignTop(tester, appState.db.getPostById('p1')!.title);
      await _shot(tester, dir, '04_conversa');

      // 5. Catálogo SENAI
      await _open(tester, '/senai');
      await _alignTop(tester, appState.courses.first.name);
      await _shot(tester, dir, '05_senai');

      appState.db.unsubscribeFromChanges();
      debugDisableShadows = true;
    });
  }
}
