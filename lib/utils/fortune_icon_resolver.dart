abstract final class FortuneIconTypes {
  static const food = 'food';
  static const flower = 'flower';
  static const color = 'color';
  static const number = 'number';
}

const _fortuneIconBasePath = 'assets/icons/fortune';

String? getFortuneIconPath({
  required String type,
  required String value,
}) {
  final normalized = value.trim();
  return switch (type) {
    FortuneIconTypes.food => _resolveFoodIcon(normalized),
    FortuneIconTypes.flower => _resolveFlowerIcon(normalized),
    FortuneIconTypes.color => _resolveColorIcon(normalized),
    FortuneIconTypes.number => null,
    _ => null,
  };
}

String _resolveFoodIcon(String value) {
  if (_containsAny(value, const ['酸奶', '牛奶'])) {
    return '$_fortuneIconBasePath/food_yogurt.png';
  }
  if (_containsAny(value, const ['烧烤', '烤串'])) {
    return '$_fortuneIconBasePath/food_skewer.png';
  }
  if (_containsAny(value, const ['咖啡', '拿铁'])) {
    return '$_fortuneIconBasePath/food_coffee.png';
  }
  if (_containsAny(value, const ['水果', '草莓', '蓝莓', '苹果'])) {
    return '$_fortuneIconBasePath/food_fruit.png';
  }
  if (_containsAny(value, const ['沙拉', '蔬菜'])) {
    return '$_fortuneIconBasePath/food_salad.png';
  }
  return '$_fortuneIconBasePath/food_default.png';
}

String _resolveFlowerIcon(String value) {
  if (value.contains('洋甘菊')) {
    return '$_fortuneIconBasePath/flower_chamomile.png';
  }
  if (value.contains('玫瑰')) {
    return '$_fortuneIconBasePath/flower_rose.png';
  }
  if (value.contains('向日葵')) {
    return '$_fortuneIconBasePath/flower_sunflower.png';
  }
  return '$_fortuneIconBasePath/flower_default.png';
}

String _resolveColorIcon(String value) {
  if (value.contains('蓝')) {
    return '$_fortuneIconBasePath/color_blue.png';
  }
  if (value.contains('绿')) {
    return '$_fortuneIconBasePath/color_green.png';
  }
  if (value.contains('紫')) {
    return '$_fortuneIconBasePath/color_purple.png';
  }
  if (_containsAny(value, const ['金', '黄'])) {
    return '$_fortuneIconBasePath/color_gold.png';
  }
  return '$_fortuneIconBasePath/color_default.png';
}

bool _containsAny(String value, List<String> keywords) {
  return keywords.any(value.contains);
}
