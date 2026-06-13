class PetProfile {
  const PetProfile({
    required this.id,
    required this.name,
    required this.birthday,
    required this.gender,
    required this.personalityTags,
    required this.relationshipNote,
    required this.originalPhotoUrl,
    required this.generatedAvatarUrl,
    required this.createdAt,
  });

  final String id;
  final String name;
  final DateTime birthday;
  final String? gender;
  final List<String> personalityTags;
  final String relationshipNote;
  final String? originalPhotoUrl;
  final String? generatedAvatarUrl;
  final DateTime createdAt;

  factory PetProfile.fromJson(Map<String, dynamic> json) {
    return PetProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      birthday: DateTime.parse(json['birthday'] as String),
      gender: json['gender'] as String?,
      personalityTags:
          List<String>.from(json['personalityTags'] as List? ?? const []),
      relationshipNote: json['relationshipNote'] as String? ?? '',
      originalPhotoUrl: json['originalPhotoUrl'] as String?,
      generatedAvatarUrl: json['generatedAvatarUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'birthday': birthday.toIso8601String(),
        'gender': gender,
        'personalityTags': personalityTags,
        'relationshipNote': relationshipNote,
        'originalPhotoUrl': originalPhotoUrl,
        'generatedAvatarUrl': generatedAvatarUrl,
        'createdAt': createdAt.toIso8601String(),
      };

  PetProfile copyWith({
    String? name,
    DateTime? birthday,
    String? gender,
    bool clearGender = false,
    List<String>? personalityTags,
    String? relationshipNote,
    String? originalPhotoUrl,
    String? generatedAvatarUrl,
  }) {
    return PetProfile(
      id: id,
      name: name ?? this.name,
      birthday: birthday ?? this.birthday,
      gender: clearGender ? null : gender ?? this.gender,
      personalityTags: personalityTags ?? this.personalityTags,
      relationshipNote: relationshipNote ?? this.relationshipNote,
      originalPhotoUrl: originalPhotoUrl ?? this.originalPhotoUrl,
      generatedAvatarUrl: generatedAvatarUrl ?? this.generatedAvatarUrl,
      createdAt: createdAt,
    );
  }
}
