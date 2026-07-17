import 'user_role.dart';

/// Mirrors `public.users` (docs/02-data-model.md).
class AppUser {
  const AppUser({
    required this.id,
    required this.familyId,
    required this.role,
    required this.displayName,
    required this.avatarColor,
    this.avatarUrl,
    this.birthYear,
    this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String? familyId;
  final UserRole role;
  final String displayName;
  final String avatarColor;
  final String? avatarUrl;
  final int? birthYear;
  final String? createdBy;
  final DateTime createdAt;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        familyId: json['family_id'] as String?,
        role: UserRole.fromString(json['role'] as String),
        displayName: json['display_name'] as String,
        avatarColor: json['avatar_color'] as String,
        avatarUrl: json['avatar_url'] as String?,
        birthYear: json['birth_year'] as int?,
        createdBy: json['created_by'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toInsertJson() => {
        'id': id,
        'family_id': familyId,
        'role': role.toStringValue(),
        'display_name': displayName,
        'avatar_color': avatarColor,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        if (birthYear != null) 'birth_year': birthYear,
        if (createdBy != null) 'created_by': createdBy,
      };

  AppUser copyWith({
    String? familyId,
    UserRole? role,
    String? displayName,
    String? avatarColor,
    String? avatarUrl,
    int? birthYear,
  }) {
    return AppUser(
      id: id,
      familyId: familyId ?? this.familyId,
      role: role ?? this.role,
      displayName: displayName ?? this.displayName,
      avatarColor: avatarColor ?? this.avatarColor,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      birthYear: birthYear ?? this.birthYear,
      createdBy: createdBy,
      createdAt: createdAt,
    );
  }
}
