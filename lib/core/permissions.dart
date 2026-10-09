import 'models.dart';

const senaiDomain = '@sistemafiep.org.br';
const lgpdVersion = 'VENEXUS-LGPD-1.0';

String normalizeEmail(String email) => email.trim().toLowerCase();

String normalizePhone(String phone) => phone.replaceAll(RegExp(r'\D'), '');

bool isSenaiEmail(String email) => normalizeEmail(email).endsWith(senaiDomain);

UserRole roleFromEmail(String email) => isSenaiEmail(email) ? UserRole.admin : UserRole.reader;

bool canPublish(User? user) => user?.role == UserRole.admin;

String publicAuthorLabel(UserRole role) => role == UserRole.admin ? 'Equipe SENAI' : 'Comunidade';
