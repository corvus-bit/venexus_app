import 'models.dart';

String nowIso() => DateTime.now().toIso8601String();

List<Post> initialPosts() => [
      Post(
        id: '1',
        title: 'Dúvida sobre contratação na indústria',
        body: 'Alguém sabe quais documentos são necessários para a admissão em vagas de auxiliar de produção?',
        authorId: '123',
        authorName: '@carlos_migrante',
        authorRole: UserRole.reader,
        images: const [],
        createdAt: nowIso(),
      ),
      Post(
        id: '2',
        title: 'Como funciona o transporte fretado?',
        body: 'Me disseram que a maioria das indústrias aqui tem ônibus próprio. Eles cobram do salário?',
        authorId: '124',
        authorName: '@maria_valle',
        authorRole: UserRole.reader,
        images: const [],
        createdAt: DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      ),
    ];

List<SenaiCourse> initialCourses() => const [
      SenaiCourse(
        id: '1',
        name: 'Operador de Empilhadeira',
        description: 'Capacitação para operação segura e eficiente de empilhadeiras, seguindo as normas de segurança do trabalho.',
        institutionAddress: 'Rua Xingu, 833 - Amadori, Pato Branco - PR',
        createdByName: 'Equipe SENAI',
      ),
      SenaiCourse(
        id: '2',
        name: 'Auxiliar de Linha de Produção',
        description: 'Noções básicas sobre o funcionamento e organização do setor produtivo industrial.',
        institutionAddress: 'Rua Xingu, 833 - Amadori, Pato Branco - PR',
        createdByName: 'Equipe SENAI',
      ),
      SenaiCourse(
        id: '3',
        name: 'Segurança no Trabalho (NR-12 Básica)',
        description: 'Orientação importante sobre segurança no manuseio de máquinas e equipamentos industriais.',
        institutionAddress: 'Rua Xingu, 833 - Amadori, Pato Branco - PR',
        createdByName: 'Equipe SENAI',
      ),
    ];

List<CartilhaContent> initialCartilha() => const [
      CartilhaContent(
        id: '1',
        type: CartilhaType.rights,
        title: 'Jornada de Trabalho e Horas Extras',
        textPt: 'No Brasil, a jornada de trabalho normal é de 8 horas diárias e 44 horas semanais. Horas trabalhadas além desse limite devem ser pagas com acréscimo de no mínimo 50%.',
        textEs: 'En Brasil, la jornada laboral normal es de 8 horas diarias y 44 horas semanales. Las horas trabajadas más allá de este límite deben pagarse con un recargo de al menos el 50%.',
        explanation: 'Saber seus horários evita o trabalho excessivo não remunerado.',
        createdByName: 'Equipe SENAI',
      ),
      CartilhaContent(
        id: '2',
        type: CartilhaType.rights,
        title: 'Equipamento de Proteção Individual (EPI)',
        textPt: 'O empregador é obrigado a fornecer gratuitamente equipamentos de proteção como botas, luvas e capacetes adequados ao risco da função. É obrigação do funcionário utilizá-los e zelar por eles.',
        textEs: 'El empleador está obligado a proporcionar gratuitamente equipos de protección como botas, guantes y cascos adecuados al riesgo de la función. Es obligación del empleado usarlos y cuidarlos.',
        explanation: 'Sua segurança é o mais importante e é garantida por lei.',
        createdByName: 'Equipe SENAI',
      ),
      CartilhaContent(
        id: '3',
        type: CartilhaType.rights,
        title: 'Férias Remuneradas',
        textPt: 'Após 12 meses de trabalho, o trabalhador tem direito a 30 dias de férias remuneradas, com acréscimo de um terço (1/3) do salário normal.',
        textEs: 'Después de 12 meses de trabajo, el trabajador tiene derecho a 30 días de vacaciones remuneradas, con un recargo de un tercio (1/3) del salario normal.',
        explanation: 'O descanso é essencial e pago, ajudando na recuperação física e mental.',
        createdByName: 'Equipe SENAI',
      ),
      CartilhaContent(
        id: '4',
        type: CartilhaType.expressions,
        title: 'Bater o ponto',
        textPt: 'Expressão utilizada para registrar o horário de chegada e saída do trabalho eletronicamente ou no relógio de ponto.',
        textEs: 'Expresión utilizada para registrar electrónicamente o en el reloj de fichar la hora de llegada y salida del trabajo.',
        explanation: 'É importante não esquecer para garantir o pagamento das suas horas.',
      ),
      CartilhaContent(
        id: '5',
        type: CartilhaType.expressions,
        title: 'Contra-cheque ou Holerite',
        textPt: 'Documento mensal recebido do empregador que detalha o seu salário, bônus, além dos descontos permitidos em lei.',
        textEs: 'Documento mensual recibido del empleador que detalla su salario, bonos, además de los descuentos permitidos por la ley (recibo de sueldo).',
        explanation: 'Sempre confira os valores do seu contra-cheque e guarde-o com você.',
      ),
    ];
