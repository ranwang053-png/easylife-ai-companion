import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/companion_pet.dart';

typedef MockAuthCallback = void Function({
  required String accountIdentifier,
  required String nickname,
});

class LoginPage extends StatefulWidget {
  const LoginPage({
    required this.onLogin,
    required this.onRegister,
    super.key,
  });

  final MockAuthCallback onLogin;
  final VoidCallback onRegister;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _accountController = TextEditingController();
  final _nicknameController = TextEditingController();

  @override
  void dispose() {
    _accountController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  void _submit() {
    final account = _accountController.text.trim();
    final nickname = _nicknameController.text.trim();
    widget.onLogin(
      accountIdentifier: account.isEmpty ? 'mock@example.com' : account,
      nickname: nickname,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 28),
          children: [
            const Center(child: CompanionPet(size: 138)),
            const SizedBox(height: 24),
            Text(
              '欢迎来到 Easylife',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              '先用 Mock 账号登录，开始你的陪伴体验',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _accountController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: '手机号或邮箱',
                hintText: '仅作本地演示，不会发送验证码',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _nicknameController,
              decoration: const InputDecoration(
                labelText: '昵称（可稍后填写）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(backgroundColor: AppColors.ink),
                child: const Text('登录'),
              ),
            ),
            TextButton(
              onPressed: widget.onRegister,
              child: const Text('还没有账号？注册'),
            ),
          ],
        ),
      ),
    );
  }
}
