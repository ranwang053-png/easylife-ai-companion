import 'package:company_app/main.dart';
import 'package:company_app/models/app_models.dart';
import 'package:company_app/pages/app_shell.dart';
import 'package:company_app/pages/health_page.dart';
import 'package:company_app/pages/memory_management_page.dart';
import 'package:company_app/pages/pet_profile_form_page.dart';
import 'package:company_app/pages/settings_page.dart';
import 'package:company_app/services/agent_service.dart';
import 'package:company_app/services/journal_repository.dart';
import 'package:company_app/services/local_store.dart';
import 'package:company_app/services/pet_profile_service.dart';
import 'package:company_app/services/user_profile_service.dart';
import 'package:company_app/theme/app_colors.dart';
import 'package:company_app/widgets/quick_action_fab.dart';
import 'package:company_app/widgets/profile_field_pickers.dart';
import 'package:company_app/widgets/soft_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> authenticateNewUser(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('phone-field')), '13812345678');
  await tester.tap(find.byKey(const Key('send-code-button')));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.enterText(find.byKey(const Key('sms-code-field')), '123456');
  await tester.tap(find.byKey(const Key('verify-code-button')));
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpAndSettle();
}

Future<void> pumpToDashboard(WidgetTester tester) async {
  MockPetProfileService.resetMockProfile();
  await tester.pumpWidget(const CompanyApp());
  await tester.pumpAndSettle();
  expect(find.text('欢迎来到 Easylife'), findsOneWidget);
  await authenticateNewUser(tester);
  expect(find.text('让easy更懂你'), findsOneWidget);
  final saveButton = find.widgetWithText(FilledButton, '保存档案');
  await tester.ensureVisible(saveButton);
  await tester.pumpAndSettle();
  await tester.tap(saveButton);
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('core flow stays stable at an iPhone-sized viewport',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpToDashboard(tester);
    expect(tester.takeException(), isNull);

    for (final tab in ['陪伴', '饮食', '我的', '首页']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('core flow stays stable at an iPad-sized viewport',
      (tester) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpToDashboard(tester);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('饮食').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop layout uses side navigation without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpToDashboard(tester);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('快捷记录'), findsOneWidget);
    expect(find.text('记录心情'), findsOneWidget);

    await tester.tap(find.text('我的').last);
    await tester.pumpAndSettle();
    expect(find.text('长期记忆'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('birthday uses one five-column iOS wheel picker', (tester) async {
    MockPetProfileService.resetMockProfile();
    await tester.pumpWidget(const CompanyApp());
    await tester.pumpAndSettle();
    await authenticateNewUser(tester);

    expect(find.text('出生日期'), findsNothing);
    await tester.tap(find.text('出生时间'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoPicker), findsNWidgets(5));
    expect(find.text('出生日期与时间'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('完成'), findsOneWidget);
  });

  testWidgets('region picker uses one text size for province city and area',
      (tester) async {
    MockPetProfileService.resetMockProfile();
    await tester.pumpWidget(const CompanyApp());
    await tester.pumpAndSettle();
    await authenticateNewUser(tester);

    final birthPlaceTile = find.text('出生地');
    await tester.ensureVisible(birthPlaceTile);
    await tester.pumpAndSettle();
    await tester.tap(birthPlaceTile);
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoPicker), findsNWidgets(3));
    final pickerTexts = tester.widgetList<Text>(
      find.descendant(
        of: find.byType(CupertinoPicker),
        matching: find.byType(Text),
      ),
    );
    expect(pickerTexts, isNotEmpty);
    expect(
      pickerTexts.every(
        (widget) => widget.style?.fontSize == regionPickerTextStyle.fontSize,
      ),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard renders core companion content', (tester) async {
    await pumpToDashboard(tester);

    expect(find.text('Easylife'), findsOneWidget);
    expect(find.text('创建伙伴档案'), findsOneWidget);
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
    await authenticateNewUser(tester);
    final saveButton = find.widgetWithText(FilledButton, '保存档案');
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Easylife'), findsOneWidget);
    expect(find.text('创建你的专属陪伴伙伴'), findsNothing);
    expect(find.text('创建伙伴档案'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('basic info provides occupation, MBTI and tag selectors',
      (tester) async {
    MockPetProfileService.resetMockProfile();
    await tester.pumpWidget(const CompanyApp());
    await tester.pumpAndSettle();
    await authenticateNewUser(tester);

    final occupationTile = find.text('职业');
    await tester.ensureVisible(occupationTile);
    await tester.pumpAndSettle();
    await tester.tap(occupationTile);
    await tester.pumpAndSettle();
    expect(find.text('选择职业类别'), findsOneWidget);
    expect(find.text('互联网与科技'), findsOneWidget);
    await tester.tap(find.text('互联网与科技'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('产品经理'));
    await tester.pumpAndSettle();
    expect(find.text('产品经理'), findsOneWidget);

    final birthPlaceTile = find.text('出生地');
    await tester.ensureVisible(birthPlaceTile);
    await tester.pumpAndSettle();
    await tester.tap(birthPlaceTile);
    await tester.pumpAndSettle();
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('完成'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    final mbtiTile = find.text('MBTI');
    await tester.ensureVisible(mbtiTile);
    await tester.pumpAndSettle();
    await tester.tap(mbtiTile);
    await tester.pumpAndSettle();
    expect(find.text('选择人格类型'), findsOneWidget);
    expect(find.text('ENFP'), findsOneWidget);
    expect(find.text('快乐小狗'), findsOneWidget);
    expect(
      tester
          .widget<Material>(find.byKey(const ValueKey('mbti-card-INTJ')))
          .color,
      AppColors.mbtiPurple,
    );
    expect(
      tester
          .widget<Material>(find.byKey(const ValueKey('mbti-card-INFJ')))
          .color,
      AppColors.mbtiGreen,
    );
    expect(
      tester
          .widget<Material>(find.byKey(const ValueKey('mbti-card-ISTJ')))
          .color,
      AppColors.mbtiBlue,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('mbti-card-ISTP')),
      120,
      scrollable: find.descendant(
        of: find.byType(GridView),
        matching: find.byType(Scrollable),
      ),
    );
    expect(
      tester
          .widget<Material>(find.byKey(const ValueKey('mbti-card-ISTP')))
          .color,
      AppColors.mbtiYellow,
    );
    await tester.tap(find.text('ISTP'));
    await tester.pumpAndSettle();
    expect(find.text('ISTP'), findsOneWidget);

    final tagsTile = find.text('添加标签');
    await tester.ensureVisible(tagsTile);
    await tester.pumpAndSettle();
    await tester.tap(tagsTile);
    await tester.pumpAndSettle();
    expect(find.text('热门标签'), findsOneWidget);
    expect(find.text('工作狂'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.widgetWithText(FilledButton, '完成'),
      ),
    );
    await tester.pumpAndSettle();
    final dietTile = find.text('饮食偏好');
    await tester.ensureVisible(dietTile);
    await tester.pumpAndSettle();
    await tester.tap(dietTile);
    await tester.pumpAndSettle();
    expect(find.text('不吃香菜'), findsOneWidget);
    expect(find.text('爱吃辣'), findsOneWidget);
    expect(find.text('少油少盐'), findsOneWidget);
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    final goalTile = find.text('近期目标');
    await tester.ensureVisible(goalTile);
    await tester.pumpAndSettle();
    await tester.tap(goalTile);
    await tester.pumpAndSettle();
    expect(find.text('减脂'), findsOneWidget);
    expect(find.text('健身'), findsOneWidget);
    expect(find.text('创作'), findsOneWidget);
    expect(find.text('抗炎'), findsOneWidget);
    expect(find.text('无'), findsOneWidget);
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

    expect(find.textContaining('我听见你已经撑着走了很久'), findsOneWidget);
  });

  testWidgets('companion profile supports flexible identity and analysis',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PetProfileFormPage(
          petProfileService: const MockPetProfileService(),
          onCompleted: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('填写伙伴信息'), findsOneWidget);
    expect(find.text('伙伴名字'), findsOneWidget);
    expect(find.text('Ta 的生日'), findsOneWidget);
    expect(find.text('Ta 的出生时间'), findsNothing);
    expect(find.text('Ta 的性别（可选）'), findsOneWidget);
    expect(find.text('关系'), findsOneWidget);
    expect(find.text('性格标签'), findsOneWidget);
    expect(find.text('档案分析'), findsOneWidget);
    expect(find.text('可通过网页或文档资料生成一版性格分析。'), findsNothing);
    expect(find.byIcon(Icons.calendar_month_outlined), findsNothing);
    expect(find.byIcon(Icons.schedule_rounded), findsNothing);
    expect(find.byIcon(Icons.sell_outlined), findsNothing);
    expect(find.byIcon(Icons.auto_awesome_outlined), findsNothing);
    expect(find.byIcon(Icons.arrow_drop_down), findsNothing);

    final genderField = find.text('Ta 的性别（可选）');
    await tester.ensureVisible(genderField);
    await tester.tap(genderField);
    await tester.pumpAndSettle();
    expect(find.text('男'), findsOneWidget);
    expect(find.text('女'), findsOneWidget);
    expect(find.text('非二元'), findsOneWidget);
    expect(find.text('保密'), findsOneWidget);
    expect(find.text('不适用'), findsNothing);
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    final birthdayField = find.text('Ta 的生日');
    await tester.ensureVisible(birthdayField);
    await tester.pumpAndSettle();
    await tester.tap(birthdayField);
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoDatePicker), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    final personalityTags = find.text('性格标签');
    await tester.ensureVisible(personalityTags);
    await tester.pumpAndSettle();
    await tester.tap(personalityTags);
    await tester.pumpAndSettle();
    expect(find.text('输入自定义性格标签'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.widgetWithText(FilledButton, '完成'),
      ),
    );
    await tester.pumpAndSettle();

    final profileAnalysis = find.text('档案分析');
    await tester.ensureVisible(profileAnalysis);
    await tester.pumpAndSettle();
    await tester.tap(profileAnalysis);
    await tester.pumpAndSettle();
    expect(find.text('伙伴档案分析'), findsOneWidget);
    expect(find.text('开始分析'), findsOneWidget);
    expect(find.text('网页链接'), findsOneWidget);
    expect(find.text('导入文档'), findsOneWidget);
    expect(find.textContaining('支持 PDF、Word、Markdown 和 TXT'), findsOneWidget);
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    final submitButton = find.widgetWithText(FilledButton, '完成');
    await tester.scrollUntilVisible(
      submitButton,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(submitButton);
    await tester.pumpAndSettle();
    expect(find.text('请先填写伙伴名字'), findsWidgets);
  });

  testWidgets('editing companion profile saves and returns', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = MemoryLocalStore();
    final petProfileService = LocalPetProfileService(store);
    final initialProfile = PetProfile(
      id: 'pet-edit',
      name: '旧伙伴',
      birthday: DateTime(2022, 6, 1),
      gender: '女',
      personalityTags: const ['温柔'],
      relationshipNote: '朋友',
      originalPhotoUrl: null,
      generatedAvatarUrl: null,
      createdAt: DateTime(2026, 6, 1),
    );
    await petProfileService.savePetProfile(initialProfile);
    PetProfile? completedProfile;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PetProfileFormPage(
                  petProfileService: petProfileService,
                  initialProfile: initialProfile,
                  onCompleted: (profile) => completedProfile = profile,
                ),
              ),
            ),
            child: const Text('打开伙伴编辑'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('打开伙伴编辑'));
    await tester.pumpAndSettle();

    expect(find.text('编辑伙伴档案'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '新伙伴');
    final submitButton = find.widgetWithText(FilledButton, '完成');
    await tester.scrollUntilVisible(
      submitButton,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(find.text('打开伙伴编辑'), findsOneWidget);
    expect(completedProfile?.name, '新伙伴');
    expect((await petProfileService.getPetProfile())?.name, '新伙伴');
  });

  testWidgets('legacy pet gender opens in companion profile without assertion',
      (tester) async {
    final legacyProfile = PetProfile(
      id: 'legacy',
      name: '糯米',
      birthday: DateTime(2022, 6, 1),
      gender: '弟弟',
      personalityTags: const ['粘人'],
      relationshipNote: '我的猫',
      originalPhotoUrl: null,
      generatedAvatarUrl: null,
      createdAt: DateTime(2026, 6, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PetProfileFormPage(
          petProfileService: const MockPetProfileService(),
          initialProfile: legacyProfile,
          onCompleted: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('编辑伙伴档案'), findsOneWidget);
    expect(find.text('男'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
    expect(find.text('伙伴档案'), findsOneWidget);
    expect(find.text('饮食偏好'), findsOneWidget);
    expect(find.text('系统偏好'), findsOneWidget);
    expect(find.text('权限、通知、隐私与陪伴方式'), findsOneWidget);
    expect(find.text('内容创作偏好'), findsNothing);
  });

  testWidgets('quick mood action opens the real companion flow',
      (tester) async {
    await pumpToDashboard(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(QuickActionFab),
        matching: find.byIcon(Icons.sentiment_satisfied_alt_rounded),
      ),
    );
    await tester.pumpAndSettle();

    final input = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == '例如：今天事情很多，我有点累，也担心做得不够好…',
    );
    expect(input, findsOneWidget);
    await tester.enterText(input, '今天有一点累');
    expect(find.text('安静听你说'), findsNothing);
    expect(find.byTooltip('语音输入'), findsOneWidget);
    await tester.ensureVisible(find.text('发送'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('发送'));
    await tester.pumpAndSettle();

    expect(find.text('今天有一点累'), findsOneWidget);
    expect((tester.widget<TextField>(input).controller?.text ?? ''), isEmpty);
    expect(find.text('情绪洞察'), findsNothing);
    expect(find.text('压力'), findsNothing);
    expect(find.textContaining('我听见你已经撑着走了很久'), findsWidgets);
    expect(find.text('保存情绪日记'), findsOneWidget);
    expect(find.text('保存并查看'), findsNothing);

    await tester.ensureVisible(find.text('保存情绪日记'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存情绪日记'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('已保存情绪日记'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.text('本轮对话'), findsNothing);
    expect(find.text('保存情绪日记'), findsNothing);
    expect(find.text('今天有一点累'), findsOneWidget);

    final journalCard = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key as ValueKey<String>).value.startsWith(
                'mood-journal-card-',
              ),
    );
    expect(journalCard, findsWidgets);
    await tester.ensureVisible(journalCard.first);
    await tester.pumpAndSettle();
    tester.widget<SoftCard>(journalCard.first).onTap?.call();
    await tester.pumpAndSettle();

    expect(find.textContaining('今天聊到的是'), findsOneWidget);
    expect(find.textContaining('它可能从这里来'), findsOneWidget);
    expect(find.textContaining('你慢慢看见了'), findsOneWidget);
    expect(find.textContaining('这些感受可以被允许'), findsOneWidget);
    expect(find.textContaining('可以试试的小事'), findsOneWidget);
    expect(find.textContaining('留给现在的你'), findsOneWidget);
    expect(find.text('本轮摘要'), findsNothing);
    expect(find.text('可能原因'), findsNothing);
    expect(find.text('用户情绪及变化'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('weight dialog closes without lifecycle errors', (tester) async {
    await pumpToDashboard(tester);

    await tester.tap(find.text('饮食'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('拍照或写一句话记录'), findsNothing);
    expect(find.text('新增体重'), findsOneWidget);
    expect(find.byTooltip('新增体重'), findsOneWidget);
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

  testWidgets('recording weight on a new day preserves prior history',
      (tester) async {
    final store = MemoryLocalStore();
    final repository = LocalJournalRepository(store);
    final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    await repository.saveMealRecords(const []);
    await repository.saveWeightRecords([
      WeightRecord(date: twoDaysAgo, weight: 52.6),
      WeightRecord(date: yesterday, weight: 52.4),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: HealthPage(
          agentService: const MockAgentService(),
          userProfileService: const MockUserProfileService(),
          journalRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('拍照或写一句话记录'), findsNothing);
    expect(find.text('新增体重'), findsOneWidget);
    await tester.tap(find.byTooltip('新增体重'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '52.1');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final weights = await repository.loadWeightRecords();
    expect(weights, hasLength(3));
    expect(weights[1].weight, 52.4);
    expect(weights.last.weight, 52.1);
  });

  testWidgets('diet guide is marked seen only after capture starts',
      (tester) async {
    final store = MemoryLocalStore();
    final repository = LocalJournalRepository(store);
    final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    await repository.saveMealRecords(const []);
    await repository.saveWeightRecords([
      WeightRecord(date: twoDaysAgo, weight: 52.6),
      WeightRecord(date: yesterday, weight: 52.4),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: HealthPage(
          agentService: const MockAgentService(),
          userProfileService: const MockUserProfileService(),
          journalRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester.state<HealthPageState>(find.byType(HealthPage)).startQuickMeal();
    await tester.pumpAndSettle();
    expect(find.text('一句话，也能轻松记录'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(await repository.hasSeenDietGuide(), isFalse);

    tester.state<HealthPageState>(find.byType(HealthPage)).startQuickMeal();
    await tester.pumpAndSettle();
    await tester.tap(find.text('跳过'));
    await tester.pumpAndSettle();

    expect(find.text('记录今天吃了什么'), findsOneWidget);
    expect(await repository.hasSeenDietGuide(), isTrue);
  });

  testWidgets('diet timeline shows daily weekly and monthly summaries',
      (tester) async {
    await pumpToDashboard(tester);

    await tester.tap(find.text('饮食'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('饮食回顾'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('饮食回顾'), findsOneWidget);
    expect(find.text('按日、周、月查看复盘和下一期建议'), findsOneWidget);
    await tester.tap(find.text('饮食回顾'));
    await tester.pumpAndSettle();

    expect(find.text('前一日数据总结'), findsOneWidget);
    expect(find.text('当日数据总结'), findsOneWidget);
    expect(find.text('下一日饮食建议'), findsOneWidget);
    expect(find.text('最常吃'), findsWidgets);
    expect(find.text('热量最高'), findsWidgets);
    expect(find.text('吃了什么'), findsNothing);

    await tester.tap(find.text('周'));
    await tester.pumpAndSettle();
    expect(find.text('前一周数据总结'), findsOneWidget);
    expect(find.text('当周数据总结'), findsOneWidget);
    expect(find.text('下一周饮食建议'), findsOneWidget);

    await tester.tap(find.text('月'));
    await tester.pumpAndSettle();
    expect(find.text('前一月数据总结'), findsOneWidget);
    expect(find.text('当月数据总结'), findsOneWidget);
    expect(find.text('下一月饮食建议'), findsOneWidget);
  });

  testWidgets('app shell reloads pet profile after settings closes',
      (tester) async {
    final store = MemoryLocalStore();
    final petProfileService = LocalPetProfileService(store);

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          agentService: const MockAgentService(),
          petProfileService: petProfileService,
          userProfileService: LocalUserProfileService(store),
          journalRepository: LocalJournalRepository(store),
          onLogout: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('系统偏好'));
    await tester.pumpAndSettle();

    await petProfileService.savePetProfile(
      PetProfile(
        id: 'pet-from-settings',
        name: '设置页伙伴',
        birthday: DateTime(2022, 6, 1),
        gender: null,
        personalityTags: const ['治愈'],
        relationshipNote: '伙伴',
        originalPhotoUrl: null,
        generatedAvatarUrl: null,
        createdAt: DateTime.now(),
      ),
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('首页'));
    await tester.pumpAndSettle();

    expect(find.text('设置页伙伴'), findsOneWidget);
    expect(find.text('创建伙伴档案'), findsNothing);
  });

  testWidgets('settings page edits local permission preferences',
      (tester) async {
    final store = MemoryLocalStore();
    final userProfileService = LocalUserProfileService(store);
    await userProfileService.saveProfile(
      MockUserProfileService.currentProfile.copyWith(
        notificationsEnabled: true,
        locationAccessEnabled: false,
        cameraPhotoAccessEnabled: false,
        cloudSyncEnabled: false,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          agentService: const MockAgentService(),
          petProfileService: LocalPetProfileService(store),
          userProfileService: userProfileService,
          onLogout: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('权限与通知'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('通知提醒'), findsOneWidget);
    expect(find.text('定位服务'), findsOneWidget);
    expect(find.text('麦克风与语音输入'), findsOneWidget);
    expect(find.text('相机与相册'), findsOneWidget);
    expect(find.text('健康数据'), findsNothing);
    expect(find.textContaining('允许发送记录提醒'), findsNothing);
    expect(find.textContaining('城市节律'), findsNothing);
    expect(find.textContaining('语音转文字'), findsNothing);
    expect(find.textContaining('伙伴照片'), findsNothing);

    final locationTile = find.widgetWithText(SwitchListTile, '定位服务');
    await tester.ensureVisible(locationTile);
    await tester.pumpAndSettle();
    await tester.tap(locationTile);
    await tester.pumpAndSettle();
    final cameraTile = find.widgetWithText(SwitchListTile, '相机与相册');
    await tester.ensureVisible(cameraTile);
    await tester.pumpAndSettle();
    await tester.tap(cameraTile);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('隐私与数据'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('云端同步'), findsOneWidget);
    expect(find.text('长期记忆个性化'), findsOneWidget);
    expect(find.text('诊断日志'), findsOneWidget);
    final cloudSyncTile = find.widgetWithText(SwitchListTile, '云端同步');
    await tester.ensureVisible(cloudSyncTile);
    await tester.pumpAndSettle();
    await tester.tap(cloudSyncTile);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();

    final restored = await userProfileService.loadProfile();
    expect(restored.locationAccessEnabled, isTrue);
    expect(restored.cameraPhotoAccessEnabled, isTrue);
    expect(restored.cloudSyncEnabled, isTrue);
  });

  testWidgets('zodiac selector scrolls without overflowing on phone',
      (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = MemoryLocalStore();
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          agentService: const MockAgentService(),
          petProfileService: LocalPetProfileService(store),
          userProfileService: LocalUserProfileService(store),
          onLogout: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final zodiacTile = find.widgetWithText(ListTile, '星座');
    await tester.ensureVisible(zodiacTile);
    await tester.pumpAndSettle();
    await tester.tap(zodiacTile);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('白羊座'), findsOneWidget);
    final optionList = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('双鱼座'),
      180,
      scrollable: optionList,
    );
    await tester.drag(optionList, const Offset(0, -80));
    await tester.pumpAndSettle();
    final piscesTile = find.widgetWithText(ListTile, '双鱼座');
    await tester.tap(piscesTile);
    await tester.pumpAndSettle();

    expect(find.text('双鱼座'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long-term memories can be added, edited and deleted',
      (tester) async {
    final store = MemoryLocalStore();
    final userProfileService = LocalUserProfileService(store);
    final initialProfile = MockUserProfileService.currentProfile.copyWith(
      memoryNotes: const ['压力大时希望先被倾听'],
    );
    await userProfileService.saveProfile(initialProfile);

    await tester.pumpWidget(
      MaterialApp(
        home: MemoryManagementPage(
          initialProfile: initialProfile,
          agentService: const MockAgentService(),
          userProfileService: userProfileService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-memory-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('memory-editor-field')),
      '饮食建议希望简单易执行',
    );
    await tester.tap(find.byKey(const Key('confirm-memory-button')));
    await tester.pumpAndSettle();

    expect(find.text('饮食建议希望简单易执行'), findsOneWidget);
    expect(
      (await userProfileService.loadProfile()).memoryNotes,
      ['压力大时希望先被倾听', '饮食建议希望简单易执行'],
    );

    final addedMemory = find.byKey(const ValueKey('memory-item-1'));
    await tester.tap(
      find.descendant(
        of: addedMemory,
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('修改'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('memory-editor-field')),
      '饮食建议希望温和且容易执行',
    );
    await tester.tap(find.byKey(const Key('confirm-memory-button')));
    await tester.pumpAndSettle();

    expect(find.text('饮食建议希望温和且容易执行'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('memory-item-1')),
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete-memory-button')));
    await tester.pumpAndSettle();

    expect(find.text('饮食建议希望温和且容易执行'), findsNothing);
    expect(
      (await userProfileService.loadProfile()).memoryNotes,
      ['压力大时希望先被倾听'],
    );
  });

  testWidgets('long-term memory cards hide original journal text',
      (tester) async {
    final store = MemoryLocalStore();
    final userProfileService = LocalUserProfileService(store);
    const rawMemory = '低落、委屈、需要被理解：今天睡了好久，有点焦虑，听我讲经过';
    final initialProfile = MockUserProfileService.currentProfile.copyWith(
      memoryNotes: const [rawMemory],
    );
    await userProfileService.saveProfile(initialProfile);

    await tester.pumpWidget(
      MaterialApp(
        home: MemoryManagementPage(
          initialProfile: initialProfile,
          agentService: const MockAgentService(),
          userProfileService: userProfileService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('低落、委屈、需要被理解'), findsOneWidget);
    expect(find.textContaining('今天睡了好久'), findsNothing);
    expect(
      (await userProfileService.loadProfile()).memoryNotes,
      const [rawMemory],
    );
  });

  testWidgets('diet record can become a sticker in today journal',
      (tester) async {
    await pumpToDashboard(tester);

    await tester.tap(find.text('饮食'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(QuickActionFab),
        matching: find.byIcon(Icons.ramen_dining_rounded),
      ),
    );
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
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(find.text('AI 估算热量'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AI 估算热量'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(find.text('确认识别结果'), findsOneWidget);
    expect(find.text('约 250 kcal'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -650));
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
