class WeightRecord {
  const WeightRecord({required this.date, required this.weight});

  final DateTime date;
  final double weight;

  factory WeightRecord.fromJson(Map<String, dynamic> json) {
    return WeightRecord(
      date: DateTime.parse(json['date'] as String),
      weight: (json['weight'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'weight': weight,
      };
}
