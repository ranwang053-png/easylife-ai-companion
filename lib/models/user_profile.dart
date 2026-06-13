class UserProfile {
  const UserProfile({
    this.accountIdentifier = '',
    required this.nickname,
    required this.birthday,
    required this.gender,
    required this.occupation,
    required this.mbti,
    required this.zodiac,
    required this.goals,
    required this.targetWeight,
    required this.dietPreference,
    required this.foodRestrictions,
    required this.petReminderStyle,
  });

  final String accountIdentifier;
  final String nickname;
  final DateTime birthday;
  final String? gender;
  final String occupation;
  final String mbti;
  final String zodiac;
  final List<String> goals;
  final double targetWeight;
  final String dietPreference;
  final String foodRestrictions;
  final String petReminderStyle;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      accountIdentifier: json['accountIdentifier'] as String? ?? '',
      nickname: json['nickname'] as String? ?? '新朋友',
      birthday: DateTime.parse(json['birthday'] as String),
      gender: json['gender'] as String?,
      occupation: json['occupation'] as String? ?? '',
      mbti: json['mbti'] as String? ?? '',
      zodiac: json['zodiac'] as String? ?? '',
      goals: List<String>.from(json['goals'] as List? ?? const []),
      targetWeight: (json['targetWeight'] as num?)?.toDouble() ?? 0,
      dietPreference: json['dietPreference'] as String? ?? '',
      foodRestrictions: json['foodRestrictions'] as String? ?? '',
      petReminderStyle: json['petReminderStyle'] as String? ?? '轻提醒',
    );
  }

  Map<String, dynamic> toJson() => {
        'accountIdentifier': accountIdentifier,
        'nickname': nickname,
        'birthday': birthday.toIso8601String(),
        'gender': gender,
        'occupation': occupation,
        'mbti': mbti,
        'zodiac': zodiac,
        'goals': goals,
        'targetWeight': targetWeight,
        'dietPreference': dietPreference,
        'foodRestrictions': foodRestrictions,
        'petReminderStyle': petReminderStyle,
      };

  UserProfile copyWith({
    String? accountIdentifier,
    String? nickname,
    DateTime? birthday,
    String? gender,
    bool clearGender = false,
    String? occupation,
    String? mbti,
    String? zodiac,
    List<String>? goals,
    double? targetWeight,
    String? dietPreference,
    String? foodRestrictions,
    String? petReminderStyle,
  }) {
    return UserProfile(
      accountIdentifier: accountIdentifier ?? this.accountIdentifier,
      nickname: nickname ?? this.nickname,
      birthday: birthday ?? this.birthday,
      gender: clearGender ? null : gender ?? this.gender,
      occupation: occupation ?? this.occupation,
      mbti: mbti ?? this.mbti,
      zodiac: zodiac ?? this.zodiac,
      goals: goals ?? this.goals,
      targetWeight: targetWeight ?? this.targetWeight,
      dietPreference: dietPreference ?? this.dietPreference,
      foodRestrictions: foodRestrictions ?? this.foodRestrictions,
      petReminderStyle: petReminderStyle ?? this.petReminderStyle,
    );
  }
}
