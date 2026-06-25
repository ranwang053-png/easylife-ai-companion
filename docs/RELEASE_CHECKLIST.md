# MVP 内测发布验收

版本：`0.3.0+3`

首发平台：iOS。Android 环境与发布暂缓，不作为本阶段阻塞项。

## 已完成

- 前端功能冻结已于 2026-06-14 解除；UI 可持续优化，新增功能需同步更新项目规划。
- 用户画像、宠物档案、情绪、饮食、体重和饮食引导状态使用本机持久化。
- 核心 models 支持版本化 JSON 键名与兼容默认值。
- 损坏或不兼容的本地 JSON 会回退到可用初始数据，不阻塞启动。
- 情绪分析支持真实 HTTP 后端，并在异常时回退本地 Mock。
- PostgreSQL 认证后端支持短信 challenge、自动注册、会话校验、Refresh Token
  轮换、退出和账号注销任务。
- 作品集构建可使用 `EASYLIFE_DEMO_MODE=true` 无手机号进入本地演示。
- 长期记忆支持用户查看、添加、修改和删除；原始情绪日记不在记忆卡片中展示。
- 陪伴、饮食回顾、每日运势和 AI Prompt 已完成本轮产品与成本优化。
- Android 正式 Manifest 已声明网络权限。
- `flutter analyze` 通过。
- `flutter test` 通过。
- `flutter build web --release` 通过。
- `flutter build web --release --dart-define=EASYLIFE_DEMO_MODE=true` 作为
  `v0.3.0-portfolio` 的可复现作品集构建命令。

## 外部环境阻塞

### iOS

当前机器运行 macOS 14.6，只有 Command Line Tools，没有完整 Xcode，也未安装
CocoaPods。自 2026-04-28 起，App Store Connect 上传要求使用 Xcode 26 或更高版本
及 iOS 26 SDK；当前系统不能运行满足该要求的 Xcode。

1. 先将 macOS 升级到可运行 Xcode 26 的版本；至少 macOS 15.6 可运行
   Xcode 26.3，若设备支持则优先安装当前可用的新系统。
2. 从 App Store 或 Apple Developer Downloads 安装兼容系统的 Xcode 26 或更高版本。
3. 至少启动一次 Xcode，等待附加组件安装完成。
4. 在终端执行：

```bash
sudo sh -c 'xcode-select -s /Applications/Xcode.app/Contents/Developer && xcodebuild -runFirstLaunch'
sudo xcodebuild -license
xcodebuild -downloadPlatform iOS
```

若尚未安装 Homebrew，先按 <https://brew.sh> 的官方命令安装，然后执行：

```bash
brew install cocoapods
pod --version
flutter doctor -v
open -a Simulator
flutter devices
flutter build ios --release --no-codesign
```

真机或 TestFlight 发布还需要 Apple Developer Team、签名证书、Provisioning Profile、
唯一 Bundle ID、隐私说明和应用图标。

### Android（暂缓）

当前机器未安装 Android SDK。iOS 首发完成前不要求安装 Android Studio 或执行
Android release 构建。

## 内测前人工检查

- 新安装后完成登录、基础资料、宠物档案创建。
- 完全关闭并重新打开 App，确认上述数据仍存在。
- 新增情绪、饮食和体重记录后重启，确认记录恢复。
- 断网时确认情绪分析可回退，界面不崩溃。
- 配置测试后端后确认真实情绪分析返回可展示。
- 检查个人信息说明、删除数据入口和测试账号说明。
