class PetMoodLog {
  const PetMoodLog({
    required this.id,
    required this.time,
    required this.userText,
    required this.emotionLabel,
    required this.emotionScore,
    required this.petReply,
    required this.suggestion,
    this.summary,
    this.warmSummary,
    this.possibleReason,
    this.emotionChange,
    this.emotionValidation,
    this.actionSuggestion,
    this.nextActions = const [],
    this.closingMessage,
    this.emotionLabels = const [],
  });

  final String id;
  final DateTime time;
  final String userText;
  final String emotionLabel;
  final List<String> emotionLabels;
  final double emotionScore;
  final String petReply;
  final String suggestion;
  final String? summary;
  final String? warmSummary;
  final String? possibleReason;
  final String? emotionChange;
  final String? emotionValidation;
  final String? actionSuggestion;
  final List<String> nextActions;
  final String? closingMessage;

  List<String> get allEmotionLabels =>
      emotionLabels.isEmpty ? [emotionLabel] : emotionLabels;

  String get displaySummary => summary ?? userText;

  String get displayWarmSummary => warmSummary ?? '现在的你正在认真照顾自己的感受。';

  String get displayPossibleReason =>
      possibleReason ?? '这段感受可能和当时的压力、期待或身体状态有关。';

  String get displayEmotionChange =>
      emotionChange ?? '你在这段记录里主要经历了“${allEmotionLabels.join('、')}”。';

  String get displayEmotionValidation =>
      emotionValidation ?? '这些感受的出现是有原因的，不需要急着否定自己。';

  String get displayActionSuggestion => actionSuggestion ?? suggestion;

  List<String> get displayNextActions =>
      nextActions.isEmpty ? [displayActionSuggestion] : nextActions;

  String get displayClosingMessage => closingMessage ?? petReply;

  factory PetMoodLog.fromJson(Map<String, dynamic> json) {
    return PetMoodLog(
      id: json['id'] as String,
      time: DateTime.parse(json['time'] as String),
      userText: json['userText'] as String,
      emotionLabel: json['emotionLabel'] as String,
      emotionLabels: (json['emotionLabels'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const [],
      emotionScore: (json['emotionScore'] as num).toDouble(),
      petReply: json['petReply'] as String,
      suggestion: json['suggestion'] as String,
      summary: json['summary'] as String?,
      warmSummary: json['warmSummary'] as String?,
      possibleReason: json['possibleReason'] as String?,
      emotionChange: json['emotionChange'] as String?,
      emotionValidation: json['emotionValidation'] as String?,
      actionSuggestion: json['actionSuggestion'] as String?,
      nextActions: (json['nextActions'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const [],
      closingMessage: json['closingMessage'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'time': time.toIso8601String(),
        'userText': userText,
        'emotionLabel': emotionLabel,
        'emotionLabels': allEmotionLabels,
        'emotionScore': emotionScore,
        'petReply': petReply,
        'suggestion': suggestion,
        if (summary != null) 'summary': summary,
        if (warmSummary != null) 'warmSummary': warmSummary,
        if (possibleReason != null) 'possibleReason': possibleReason,
        if (emotionChange != null) 'emotionChange': emotionChange,
        if (emotionValidation != null) 'emotionValidation': emotionValidation,
        if (actionSuggestion != null) 'actionSuggestion': actionSuggestion,
        if (nextActions.isNotEmpty) 'nextActions': nextActions,
        if (closingMessage != null) 'closingMessage': closingMessage,
      };
}
