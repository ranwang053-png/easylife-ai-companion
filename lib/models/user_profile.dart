class UserProfile {
  const UserProfile({
    this.accountIdentifier = '',
    this.avatarImageUrl = '',
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
    this.birthPlace = '',
    this.currentResidence = '',
    this.personalTags = const [],
    this.memoryNotes = const [],
    this.notificationsEnabled = true,
    this.locationAccessEnabled = false,
    this.microphoneAccessEnabled = true,
    this.cameraPhotoAccessEnabled = false,
    this.healthDataAccessEnabled = false,
    this.cloudSyncEnabled = false,
    this.aiMemoryEnabled = true,
    this.diagnosticsEnabled = false,
  });

  final String accountIdentifier;
  final String avatarImageUrl;
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
  final String birthPlace;
  final String currentResidence;
  final List<String> personalTags;
  final List<String> memoryNotes;
  final bool notificationsEnabled;
  final bool locationAccessEnabled;
  final bool microphoneAccessEnabled;
  final bool cameraPhotoAccessEnabled;
  final bool healthDataAccessEnabled;
  final bool cloudSyncEnabled;
  final bool aiMemoryEnabled;
  final bool diagnosticsEnabled;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      accountIdentifier: json['accountIdentifier'] as String? ?? '',
      avatarImageUrl: json['avatarImageUrl'] as String? ?? '',
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
      birthPlace: json['birthPlace'] as String? ?? '',
      currentResidence: json['currentResidence'] as String? ?? '',
      personalTags: List<String>.from(
        json['personalTags'] as List? ?? const [],
      ),
      memoryNotes: List<String>.from(json['memoryNotes'] as List? ?? const []),
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      locationAccessEnabled: json['locationAccessEnabled'] as bool? ?? false,
      microphoneAccessEnabled: json['microphoneAccessEnabled'] as bool? ?? true,
      cameraPhotoAccessEnabled:
          json['cameraPhotoAccessEnabled'] as bool? ?? false,
      healthDataAccessEnabled:
          json['healthDataAccessEnabled'] as bool? ?? false,
      cloudSyncEnabled: json['cloudSyncEnabled'] as bool? ?? false,
      aiMemoryEnabled: json['aiMemoryEnabled'] as bool? ?? true,
      diagnosticsEnabled: json['diagnosticsEnabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'accountIdentifier': accountIdentifier,
        'avatarImageUrl': avatarImageUrl,
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
        'birthPlace': birthPlace,
        'currentResidence': currentResidence,
        'personalTags': personalTags,
        'memoryNotes': memoryNotes,
        'notificationsEnabled': notificationsEnabled,
        'locationAccessEnabled': locationAccessEnabled,
        'microphoneAccessEnabled': microphoneAccessEnabled,
        'cameraPhotoAccessEnabled': cameraPhotoAccessEnabled,
        'healthDataAccessEnabled': healthDataAccessEnabled,
        'cloudSyncEnabled': cloudSyncEnabled,
        'aiMemoryEnabled': aiMemoryEnabled,
        'diagnosticsEnabled': diagnosticsEnabled,
      };

  UserProfile copyWith({
    String? accountIdentifier,
    String? avatarImageUrl,
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
    String? birthPlace,
    String? currentResidence,
    List<String>? personalTags,
    List<String>? memoryNotes,
    bool? notificationsEnabled,
    bool? locationAccessEnabled,
    bool? microphoneAccessEnabled,
    bool? cameraPhotoAccessEnabled,
    bool? healthDataAccessEnabled,
    bool? cloudSyncEnabled,
    bool? aiMemoryEnabled,
    bool? diagnosticsEnabled,
  }) {
    return UserProfile(
      accountIdentifier: accountIdentifier ?? this.accountIdentifier,
      avatarImageUrl: avatarImageUrl ?? this.avatarImageUrl,
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
      birthPlace: birthPlace ?? this.birthPlace,
      currentResidence: currentResidence ?? this.currentResidence,
      personalTags: personalTags ?? this.personalTags,
      memoryNotes: memoryNotes ?? this.memoryNotes,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      locationAccessEnabled:
          locationAccessEnabled ?? this.locationAccessEnabled,
      microphoneAccessEnabled:
          microphoneAccessEnabled ?? this.microphoneAccessEnabled,
      cameraPhotoAccessEnabled:
          cameraPhotoAccessEnabled ?? this.cameraPhotoAccessEnabled,
      healthDataAccessEnabled:
          healthDataAccessEnabled ?? this.healthDataAccessEnabled,
      cloudSyncEnabled: cloudSyncEnabled ?? this.cloudSyncEnabled,
      aiMemoryEnabled: aiMemoryEnabled ?? this.aiMemoryEnabled,
      diagnosticsEnabled: diagnosticsEnabled ?? this.diagnosticsEnabled,
    );
  }
}
