import 'package:company_app/main.dart';
import 'package:company_app/services/pet_profile_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpToDashboard(WidgetTester tester) async {
  MockPetProfileService.resetMockProfile();
  await tester.pumpWidget(const CompanyApp());
  await tester.pumpAndSettle();
  expect(find.text('欢迎来到 Easylife'), findsOneWidget);
  await tester.tap(find.widgetWithText(FilledButton, '登录'));
  await tester.pumpAndSettle();
  expect(find.text('让easy更懂你'), findsOneWidget);
  await tester.tap(find.widgetWithText(FilledButton, '保存档案'));
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('birthday uses an iOS-style wheel picker', (tester) async {
    MockPetProfileService.resetMockProfile();
    await tester.pumpWidget(const CompanyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('出生日期'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoDatePicker), findsOneWidget);
    expect(find.text('选择出生日期'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('完成'), findsOneWidget);
  });

  testWidgets('dashboard renders core companion content', (tester) async {
    await pumpToDashboard(tester);

    expect(find.text('Easylife'), findsOneWidget);
    expect(find.text('创建宠物档案'), findsOneWidget);
    expect(find.text('今日运势'), findsOneWidget);
    expect(find.text('整体运势'), findsOneWidget);
    expect(find.text('幸运色'), findsOneWidget);
    expect(find.text('幸运食物'), findsOneWidget);
    expect(find.text('幸运数字'), findsOneWidget);
    expect(find.text('幸运花'), findsOneWidget);
    expect(find.text('运势分数'), findsOneWidget);
    expect(find.text('事业'), findsOneWidget);
    expect(find.text('财富'), findsOneWidget);
    expect(find.text('爱情'), findsOneWidget);
    expect(find.text('人际'), findsOneWidget);
    expect(find.textContaining('建议：'), findsOneWidget);
    expect(find.textContaining('避免：'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('今日状态'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('今日状态'), findsOneWidget);
    expect(find.text('陪伴'), findsOneWidget);
    expect(find.text('饮食'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
    expect(find.text('灵感'), findsNothing);
    expect(find.text('塔罗'), findsNothing);
  });

  testWidgets('saving basic info enters dashboard without pet onboarding',
      (tester) async {
    MockPetProfileService.resetMockProfile();
    await tester.pumpWidget(const CompanyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '保存档案'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Easylife'), findsOneWidget);
    expect(find.text('让你的宠物住进 Easylife'), findsNothing);
    expect(find.text('创建宠物档案'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard pet input returns a mock reply', (tester) async {
    await pumpToDashboard(tester);
    final petInput = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.hintText == '和我说说今天的心情吧...',
    );

    await tester.scrollUntilVisible(
      petInput,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      petInput,
      '今天有点累',
    );
    await tester.ensureVisible(find.byTooltip('发送'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('发送'));
    await tester.pumpAndSettle();

    expect(find.text('听起来你真的撑了很久。先靠一会儿，我陪你把今天放慢一点。'), findsOneWidget);
  });

  testWidgets('quick weight action opens the real health recording flow', (
    tester,
  ) async {
    await pumpToDashboard(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.monitor_weight_outlined));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('饮食体重'), findsOneWidget);
    expect(find.text('记录今日体重'), findsOneWidget);
    expect(find.text('保存并查看'), findsNothing);
  });

  testWidgets('my tab shows profile and preference entries', (tester) async {
    await pumpToDashboard(tester);

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();

    expect(find.text('长期记忆'), findsOneWidget);
    expect(find.text('宠物档案'), findsOneWidget);
    expect(find.text('饮食偏好'), findsOneWidget);
    expect(find.text('系统偏好'), findsOneWidget);
    expect(find.text('内容创作偏好'), findsNothing);
  });

  testWidgets('quick mood action opens the real companion flow',
      (tester) async {
    await pumpToDashboard(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.sentiment_satisfied_alt_rounded));
    await tester.pumpAndSettle();

    final input = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == '例如：今天事情很多，我有点累，也担心做得不够好…',
    );
    expect(input, findsOneWidget);
    await tester.enterText(input, '今天有一点累');
    await tester.ensureVisible(find.text('分析我的情绪'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('分析我的情绪'));
    await tester.pumpAndSettle();

    expect(find.textContaining('听起来你真的撑了很久'), findsOneWidget);
    expect(find.text('保存并查看'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('weight dialog closes without lifecycle errors', (tester) async {
    await pumpToDashboard(tester);

    await tester.tap(find.text('饮食'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('新增体重'));
    await tester.pumpAndSettle();

    final dialogInput = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextFormField),
    );
    expect(dialogInput, findsOneWidget);
    await tester.enterText(dialogInput, '52.1');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('diet record can become a sticker in today journal',
      (tester) async {
    await pumpToDashboard(tester);

    await tester.tap(find.text('饮食'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('拍照或写一句话记录'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('拍照或写一句话记录'));
    await tester.pumpAndSettle();
    expect(find.text('一句话，也能轻松记录'), findsOneWidget);

    await tester.tap(find.text('跳过'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      '吃了半袋薯片',
    );
    await tester.scrollUntilVisible(
      find.text('AI 估算热量'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('AI 估算热量'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(find.text('确认识别结果'), findsOneWidget);
    expect(find.text('约 250 kcal'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -650));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认，制作贴纸'));
    await tester.pumpAndSettle();

    expect(find.text('制作食物贴纸'), findsOneWidget);
    await tester.tap(find.text('浅绿色描边'));
    await tester.tap(find.text('贴到今日手帐'));
    await tester.pumpAndSettle();

    expect(find.text('薯片'), findsOneWidget);
    expect(find.text('250 kcal'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings editor can close and route can pop safely',
      (tester) async {
    await pumpToDashboard(tester);

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('昵称'));
    await tester.pumpAndSettle();

    final dialogInput = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextFormField),
    );
    expect(dialogInput, findsOneWidget);
    await tester.enterText(dialogInput, 'Easylife 用户');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
