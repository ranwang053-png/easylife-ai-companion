enum MealType {
  breakfast('早餐'),
  lunch('午餐'),
  dinner('晚餐'),
  snack('加餐');

  const MealType(this.label);

  final String label;
}

class MealRecord {
  const MealRecord({
    required this.id,
    required this.date,
    required this.mealType,
    required this.foodName,
    required this.description,
    required this.estimatedCalories,
    required this.imageUrl,
    required this.portionText,
    required this.ingredientsText,
    required this.note,
    required this.recordTime,
    required this.stickerStyle,
    required this.sourceType,
  });

  final String id;
  final DateTime date;
  final MealType mealType;
  final String foodName;
  final String description;
  final int estimatedCalories;
  final String? imageUrl;
  final String portionText;
  final String ingredientsText;
  final String note;
  final DateTime recordTime;
  final String stickerStyle;
  final String sourceType;

  factory MealRecord.fromJson(Map<String, dynamic> json) {
    return MealRecord(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      mealType: MealType.values.byName(json['mealType'] as String),
      foodName: json['foodName'] as String,
      description: json['description'] as String? ?? '',
      estimatedCalories: (json['estimatedCalories'] as num).toInt(),
      imageUrl: json['imageUrl'] as String?,
      portionText: json['portionText'] as String? ?? '',
      ingredientsText: json['ingredientsText'] as String? ?? '',
      note: json['note'] as String? ?? '',
      recordTime: DateTime.parse(json['recordTime'] as String),
      stickerStyle: json['stickerStyle'] as String? ?? '白色描边',
      sourceType: json['sourceType'] as String? ?? 'text',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'mealType': mealType.name,
        'foodName': foodName,
        'description': description,
        'estimatedCalories': estimatedCalories,
        'imageUrl': imageUrl,
        'portionText': portionText,
        'ingredientsText': ingredientsText,
        'note': note,
        'recordTime': recordTime.toIso8601String(),
        'stickerStyle': stickerStyle,
        'sourceType': sourceType,
      };

  MealRecord copyWith({
    String? foodName,
    String? description,
    int? estimatedCalories,
    String? imageUrl,
    String? portionText,
    String? ingredientsText,
    String? note,
    MealType? mealType,
    DateTime? recordTime,
    String? stickerStyle,
    String? sourceType,
  }) {
    return MealRecord(
      id: id,
      date: date,
      mealType: mealType ?? this.mealType,
      foodName: foodName ?? this.foodName,
      description: description ?? this.description,
      estimatedCalories: estimatedCalories ?? this.estimatedCalories,
      imageUrl: imageUrl ?? this.imageUrl,
      portionText: portionText ?? this.portionText,
      ingredientsText: ingredientsText ?? this.ingredientsText,
      note: note ?? this.note,
      recordTime: recordTime ?? this.recordTime,
      stickerStyle: stickerStyle ?? this.stickerStyle,
      sourceType: sourceType ?? this.sourceType,
    );
  }
}
