import 'package:company_app/utils/fortune_icon_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('getFortuneIconPath', () {
    test('matches food icons from lucky food text', () {
      expect(
        getFortuneIconPath(type: FortuneIconTypes.food, value: '草莓酸奶'),
        'assets/icons/fortune/food_yogurt.png',
      );
      expect(
        getFortuneIconPath(type: FortuneIconTypes.food, value: '晚风烧烤'),
        'assets/icons/fortune/food_skewer.png',
      );
      expect(
        getFortuneIconPath(type: FortuneIconTypes.food, value: '热拿铁'),
        'assets/icons/fortune/food_coffee.png',
      );
      expect(
        getFortuneIconPath(type: FortuneIconTypes.food, value: '蓝莓'),
        'assets/icons/fortune/food_fruit.png',
      );
      expect(
        getFortuneIconPath(type: FortuneIconTypes.food, value: '蔬菜沙拉'),
        'assets/icons/fortune/food_salad.png',
      );
    });

    test('matches flower and color icons from lucky text', () {
      expect(
        getFortuneIconPath(type: FortuneIconTypes.flower, value: '洋甘菊'),
        'assets/icons/fortune/flower_chamomile.png',
      );
      expect(
        getFortuneIconPath(type: FortuneIconTypes.flower, value: '玫瑰'),
        'assets/icons/fortune/flower_rose.png',
      );
      expect(
        getFortuneIconPath(type: FortuneIconTypes.color, value: '雾霾蓝'),
        'assets/icons/fortune/color_blue.png',
      );
      expect(
        getFortuneIconPath(type: FortuneIconTypes.color, value: '香槟金'),
        'assets/icons/fortune/color_gold.png',
      );
    });

    test('keeps lucky number icon text-based', () {
      expect(
        getFortuneIconPath(type: FortuneIconTypes.number, value: '7'),
        isNull,
      );
    });
  });
}
