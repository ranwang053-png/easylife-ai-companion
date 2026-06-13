import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({
    required this.onRegister,
    required this.onBackToLogin,
    super.key,
  });

  final MockAuthCallback onRegister;
  final VoidCallback onBackToLogin;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nicknameController = TextEditingController();
  final _accountController = TextEditingController();

  @override
  void dispose() {
    _nicknameController.dispose();
    _accountController.dispose();
    super.dispose();
  }

  void _submit() {
    final nickname = _nicknameController.text.trim();
    final account = _accountController.text.trim();
    widget.onRegister(
      accountIdentifier: account.isEmpty ? 'new-user@example.com' : account,
      nickname: nickname,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        leading: BackButton(onPressed: widget.onBackToLogin),
        title: const Text('注册'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
        children: [
          Text('创建 Mock 账号', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text('当前为本地账号体验，不接验证码或远程账号系统。'),
          const SizedBox(height: 28),
          TextField(
            controller: _nicknameController,
            decoration: const InputDecoration(
              labelText: '昵称',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _accountController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: '手机号或邮箱',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(backgroundColor: AppColors.ink),
              child: const Text('注册并继续'),
            ),
          ),
          TextButton(
            onPressed: widget.onBackToLogin,
            child: const Text('已有账号，返回登录'),
          ),
        ],
      ),
    );
  }
}
