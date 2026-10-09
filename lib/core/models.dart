enum UserRole { admin, reader }

enum CartilhaType { rights, expressions }

enum AppLanguage { ptBR, es }

String roleToJson(UserRole role) => role == UserRole.admin ? 'admin' : 'reader';

UserRole roleFromJson(String? value) => value == 'admin' ? UserRole.admin : UserRole.reader;

String languageToJson(AppLanguage language) => language == AppLanguage.es ? 'es' : 'pt-BR';

AppLanguage languageFromJson(String? value) => value == 'es' ? AppLanguage.es : AppLanguage.ptBR;

String cartilhaTypeToJson(CartilhaType type) => type == CartilhaType.rights ? 'rights' : 'expressions';

CartilhaType cartilhaTypeFromJson(String? value) => value == 'rights' ? CartilhaType.rights : CartilhaType.expressions;

class User {
  const User({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    required this.role,
    required this.createdAt,
    this.language,
    this.avatarPath,
    this.lgpdAcceptedAt,
    this.lgpdVersion,
    this.passwordUpdatedAt,
    this.password,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String phone;
  final String email;
  final String address;
  final UserRole role;
  final AppLanguage? language;
  final String? avatarPath;
  final String? lgpdAcceptedAt;
  final String? lgpdVersion;
  final String? passwordUpdatedAt;
  final String? password;
  final String createdAt;
  final String? updatedAt;

  User copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    UserRole? role,
    AppLanguage? language,
    String? avatarPath,
    bool clearAvatar = false,
    String? lgpdAcceptedAt,
    String? lgpdVersion,
    String? passwordUpdatedAt,
    String? password,
    String? createdAt,
    String? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      role: role ?? this.role,
      language: language ?? this.language,
      avatarPath: clearAvatar ? null : avatarPath ?? this.avatarPath,
      lgpdAcceptedAt: lgpdAcceptedAt ?? this.lgpdAcceptedAt,
      lgpdVersion: lgpdVersion ?? this.lgpdVersion,
      passwordUpdatedAt: passwordUpdatedAt ?? this.passwordUpdatedAt,
      password: password ?? this.password,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      address: json['address'] as String? ?? '',
      role: roleFromJson(json['role'] as String?),
      language: json['language'] == null ? null : languageFromJson(json['language'] as String?),
      avatarPath: json['avatarPath'] as String?,
      lgpdAcceptedAt: json['lgpdAcceptedAt'] as String?,
      lgpdVersion: json['lgpdVersion'] as String?,
      passwordUpdatedAt: json['passwordUpdatedAt'] as String?,
      password: json['password'] as String?,
      createdAt: json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      updatedAt: json['updatedAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'address': address,
        'role': roleToJson(role),
        'language': language == null ? null : languageToJson(language!),
        'avatarPath': avatarPath,
        'lgpdAcceptedAt': lgpdAcceptedAt,
        'lgpdVersion': lgpdVersion,
        'passwordUpdatedAt': passwordUpdatedAt,
        'password': password,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };
}

class Post {
  const Post({
    required this.id,
    required this.title,
    required this.body,
    required this.authorId,
    required this.authorName,
    required this.images,
    required this.createdAt,
    this.authorRole = UserRole.reader,
  });

  final String id;
  final String title;
  final String body;
  final String authorId;
  final String authorName;
  final UserRole authorRole;
  final List<String> images;
  final String createdAt;

  factory Post.fromJson(Map<String, dynamic> json) => Post(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        authorId: json['authorId'] as String? ?? '',
        authorName: json['authorName'] as String? ?? '',
        authorRole: roleFromJson(json['authorRole'] as String?),
        images: List<String>.from(json['images'] as List? ?? const []),
        createdAt: json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'authorId': authorId,
        'authorName': authorName,
        'authorRole': roleToJson(authorRole),
        'images': images,
        'createdAt': createdAt,
      };
}

class Comment {
  const Comment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    required this.text,
    required this.createdAt,
    this.authorRole = UserRole.reader,
  });

  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final UserRole authorRole;
  final String text;
  final String createdAt;

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
        id: json['id'] as String? ?? '',
        postId: json['postId'] as String? ?? '',
        authorId: json['authorId'] as String? ?? '',
        authorName: json['authorName'] as String? ?? '',
        authorRole: roleFromJson(json['authorRole'] as String?),
        text: json['text'] as String? ?? '',
        createdAt: json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'postId': postId,
        'authorId': authorId,
        'authorName': authorName,
        'authorRole': roleToJson(authorRole),
        'text': text,
        'createdAt': createdAt,
      };
}

class SenaiCourse {
  const SenaiCourse({
    required this.id,
    required this.name,
    required this.description,
    required this.institutionAddress,
    this.createdById,
    this.createdByName,
    this.createdAt,
  });

  final String id;
  final String name;
  final String description;
  final String institutionAddress;
  final String? createdById;
  final String? createdByName;
  final String? createdAt;

  factory SenaiCourse.fromJson(Map<String, dynamic> json) => SenaiCourse(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        institutionAddress: json['institutionAddress'] as String? ?? '',
        createdById: json['createdById'] as String?,
        createdByName: json['createdByName'] as String?,
        createdAt: json['createdAt'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'institutionAddress': institutionAddress,
        'createdById': createdById,
        'createdByName': createdByName,
        'createdAt': createdAt,
      };
}

class CartilhaContent {
  const CartilhaContent({
    required this.id,
    required this.type,
    required this.title,
    required this.textPt,
    required this.textEs,
    required this.explanation,
    this.createdById,
    this.createdByName,
    this.createdAt,
  });

  final String id;
  final CartilhaType type;
  final String title;
  final String textPt;
  final String textEs;
  final String explanation;
  final String? createdById;
  final String? createdByName;
  final String? createdAt;

  factory CartilhaContent.fromJson(Map<String, dynamic> json) => CartilhaContent(
        id: json['id'] as String? ?? '',
        type: cartilhaTypeFromJson(json['type'] as String?),
        title: json['title'] as String? ?? '',
        textPt: json['textPt'] as String? ?? '',
        textEs: json['textEs'] as String? ?? '',
        explanation: json['explanation'] as String? ?? '',
        createdById: json['createdById'] as String?,
        createdByName: json['createdByName'] as String?,
        createdAt: json['createdAt'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': cartilhaTypeToJson(type),
        'title': title,
        'textPt': textPt,
        'textEs': textEs,
        'explanation': explanation,
        'createdById': createdById,
        'createdByName': createdByName,
        'createdAt': createdAt,
      };
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.targetRoute,
    this.read = false,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final String createdAt;
  final String? targetRoute;
  final bool read;

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        createdAt: createdAt,
        targetRoute: targetRoute,
        read: read ?? this.read,
      );

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String? ?? '',
        type: json['type'] as String? ?? '',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        createdAt: json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
        targetRoute: json['targetRoute'] as String?,
        read: json['read'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'body': body,
        'createdAt': createdAt,
        'targetRoute': targetRoute,
        'read': read,
      };
}

class SearchResultItem {
  const SearchResultItem({
    required this.type,
    required this.title,
    required this.description,
    this.route,
  });

  final String type;
  final String title;
  final String description;
  final String? route;
}
