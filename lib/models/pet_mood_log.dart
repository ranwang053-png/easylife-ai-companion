class PetMoodLog {
  const PetMoodLog({
    required this.id,
    required this.time,
    required this.userText,
    required this.emotionLabel,
    required this.emotionScore,
    required this.petReply,
    required this.suggestion,
  });

  final String id;
  final DateTime time;
  final String userText;
  final String emotionLabel;
  final double emotionScore;
  final String petReply;
  final String suggestion;

  factory PetMoodLog.fromJson(Map<String, dynamic> json) {
    return PetMoodLog(
      id: json['id'] as String,
      time: DateTime.parse(json['time'] as String),
      userText: json['userText'] as String,
      emotionLabel: json['emotionLabel'] as String,
      emotionScore: (json['emotionScore'] as num).toDouble(),
      petReply: json['petReply'] as String,
      suggestion: json['suggestion'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'time': time.toIso8601String(),
        'userText': userText,
        'emotionLabel': emotionLabel,
        'emotionScore': emotionScore,
        'petReply': petReply,
        'suggestion': suggestion,
      };
}
