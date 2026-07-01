import '../models/app_models.dart';
import 'journal_repository.dart';
import 'local_store.dart';
import 'pet_profile_service.dart';
import 'user_profile_service.dart';

const portfolioDemoUserId = 'portfolio-demo-user';

class PortfolioDemoDataSeeder {
  const PortfolioDemoDataSeeder();

  static const _seedMarkerKey = 'easylife.demo.portfolio_seed.v1';

  Future<bool> seedIfNeeded({
    required String userId,
    required LocalStore store,
    DateTime? now,
  }) async {
    if (userId != portfolioDemoUserId) return false;
    if (await store.getString(_seedMarkerKey) != null) return false;

    final dataKeys = [
      LocalUserProfileService.profileKey,
      LocalPetProfileService.profileKey,
      LocalJournalRepository.moodLogsKey,
      LocalJournalRepository.mealRecordsKey,
      LocalJournalRepository.weightRecordsKey,
    ];
    for (final key in dataKeys) {
      if (await store.getString(key) != null) {
        await store.setString(_seedMarkerKey, 'existing-data');
        return false;
      }
    }

    final seedTime = now ?? DateTime.now();
    final userProfileService = LocalUserProfileService(store);
    final petProfileService = LocalPetProfileService(store);
    final journalRepository = LocalJournalRepository(store);

    await userProfileService.saveProfile(_profile);
    await petProfileService.savePetProfile(_petProfile(seedTime));
    await journalRepository.saveMoodLogs(_moodLogs(seedTime));
    await journalRepository.saveMealRecords(_mealRecords(seedTime));
    await journalRepository.saveWeightRecords(_weightRecords(seedTime));
    await store.setString(_seedMarkerKey, 'seeded');
    return true;
  }

  static final _profile = UserProfile(
    accountIdentifier: portfolioDemoUserId,
    nickname: '林夏',
    birthday: DateTime(1997, 9, 18, 8, 30),
    gender: '女',
    occupation: '产品经理',
    mbti: 'INFJ',
    zodiac: '处女座',
    goals: const ['规律作息', '保持情绪稳定', '吃得更均衡'],
    targetWeight: 51.5,
    dietPreference: '偏爱清淡家常菜，也喜欢咖啡和水果',
    foodRestrictions: '不吃香菜，乳制品适量',
    petReminderStyle: '温柔提醒',
    birthPlace: '浙江省杭州市西湖区',
    currentResidence: '上海市徐汇区',
    personalTags: const ['慢热', '咖啡爱好者', '周末散步'],
    memoryNotes: const [
      '工作节奏：忙起来容易忘记休息，希望被温柔提醒',
      '恢复方式：散步和听轻音乐能帮助自己慢慢放松',
      '饮食习惯：早餐偏简单，下午容易想喝咖啡',
    ],
    notificationsEnabled: true,
    locationAccessEnabled: false,
    microphoneAccessEnabled: true,
    cameraPhotoAccessEnabled: false,
    healthDataAccessEnabled: false,
    cloudSyncEnabled: false,
    aiMemoryEnabled: true,
    diagnosticsEnabled: false,
  );

  static PetProfile _petProfile(DateTime now) => PetProfile(
        id: 'portfolio-demo-pet',
        name: '一团',
        birthday: DateTime(2023, 3, 12),
        gender: '妹妹',
        personalityTags: const ['安静', '贴心', '有点好奇'],
        relationshipNote: '陪我把日子过得松一点',
        originalPhotoUrl: null,
        generatedAvatarUrl: 'mock://generated/pet-avatar',
        createdAt: now.subtract(const Duration(days: 120)),
        personalitySummary: '安静地陪在身边，会在你忙过头时轻轻提醒休息。',
      );

  static List<PetMoodLog> _moodLogs(DateTime now) => [
        PetMoodLog(
          id: 'portfolio-demo-mood-1',
          time: now.subtract(const Duration(hours: 3)),
          userText: '今天把最难的一项工作先完成了，虽然有点累，但心里踏实多了。',
          emotionLabel: '踏实',
          emotionLabels: const ['踏实', '疲惫', '成就感'],
          emotionScore: .68,
          petReply: '辛苦啦，最难的那一步已经被你稳稳接住了。',
          suggestion: '今晚给自己留一小段不处理任务的时间。',
          summary: '先完成最难的工作后，你从紧绷慢慢回到踏实，也感到一些疲惫。',
          warmSummary: '你没有催着自己跑完全部，而是认真接住了今天最重要的一步。',
          possibleReason: '高强度任务完成后，成就感和疲惫会同时出现。',
          emotionChange: '从任务压力带来的紧绷，慢慢转向踏实和成就感。',
          emotionValidation: '完成重要事情后觉得累很自然，这不影响你为自己感到骄傲。',
          actionSuggestion: '今晚给自己留一小段不处理任务的时间。',
          nextActions: const ['下班后散步十分钟', '睡前把明天第一件小事写下来'],
          closingMessage: '剩下的路可以慢一点，我会陪着你。',
        ),
        PetMoodLog(
          id: 'portfolio-demo-mood-2',
          time: now.subtract(const Duration(days: 1, hours: 2)),
          userText: '傍晚沿着江边走了一会儿，风很舒服，脑子终于安静下来。',
          emotionLabel: '放松',
          emotionLabels: const ['放松', '平静', '被治愈'],
          emotionScore: .82,
          petReply: '这阵晚风好像也替你把一天的杂音吹远了一点。',
          suggestion: '把散步继续留作忙碌日子里的小小缓冲。',
          summary: '傍晚的散步让你从白天的忙乱里恢复了平静。',
          warmSummary: '你找到了一种不费力、却很适合自己的恢复方式。',
          possibleReason: '离开工作环境和轻微运动，都有助于注意力慢慢松开。',
          emotionChange: '从脑内嘈杂转向放松、平静和被治愈。',
          emotionValidation: '短暂离开任务并不是逃避，而是在为自己补充能量。',
          actionSuggestion: '把散步继续留作忙碌日子里的小小缓冲。',
          nextActions: const ['收藏一首适合散步的歌', '本周再安排一次二十分钟散步'],
          closingMessage: '以后想安静一会儿，我们还可以一起去吹风。',
        ),
      ];

  static List<MealRecord> _mealRecords(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return [
      MealRecord(
        id: 'portfolio-demo-meal-1',
        date: today,
        mealType: MealType.breakfast,
        foodName: '燕麦拿铁与水煮蛋',
        description: '一杯燕麦拿铁和一个水煮蛋',
        estimatedCalories: 300,
        imageUrl: null,
        portionText: '一份',
        ingredientsText: '燕麦奶、咖啡、水煮蛋',
        note: '早上时间紧，先补一点蛋白质',
        recordTime: now.subtract(const Duration(hours: 7)),
        stickerStyle: '浅黄色描边',
        sourceType: 'text',
      ),
      MealRecord(
        id: 'portfolio-demo-meal-2',
        date: today,
        mealType: MealType.lunch,
        foodName: '番茄牛肉杂粮饭',
        description: '番茄炖牛肉、杂粮饭和一份时蔬',
        estimatedCalories: 610,
        imageUrl: null,
        portionText: '一整份',
        ingredientsText: '番茄、牛肉、杂粮饭、青菜',
        note: '午餐吃得比较完整',
        recordTime: now.subtract(const Duration(hours: 4)),
        stickerStyle: '浅绿色描边',
        sourceType: 'text',
      ),
      MealRecord(
        id: 'portfolio-demo-meal-3',
        date: today,
        mealType: MealType.snack,
        foodName: '苹果与一小把坚果',
        description: '一个苹果和少量原味坚果',
        estimatedCalories: 190,
        imageUrl: null,
        portionText: '一份',
        ingredientsText: '苹果、混合坚果',
        note: '下午嘴馋时换成轻一点的加餐',
        recordTime: now.subtract(const Duration(hours: 1)),
        stickerStyle: '白色描边',
        sourceType: 'text',
      ),
    ];
  }

  static List<WeightRecord> _weightRecords(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return [
      WeightRecord(date: today.subtract(const Duration(days: 6)), weight: 52.6),
      WeightRecord(date: today.subtract(const Duration(days: 3)), weight: 52.4),
      WeightRecord(date: today, weight: 52.3),
    ];
  }
}
