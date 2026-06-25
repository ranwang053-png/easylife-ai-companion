import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/auth_models.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/companion_pet.dart';
import '../widgets/responsive_page.dart';

typedef MockAuthCallback = void Function({
  required String accountIdentifier,
  required String nickname,
});

class LoginPage extends StatefulWidget {
  const LoginPage({
    required this.authService,
    required this.deviceId,
    required this.showExampleCode,
    required this.demoMode,
    required this.onEnterDemo,
    required this.onAuthenticated,
    super.key,
  });

  final AuthService authService;
  final Future<String> deviceId;
  final bool showExampleCode;
  final bool demoMode;
  final Future<void> Function() onEnterDemo;
  final ValueChanged<LoginVerificationResponse> onAuthenticated;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  Timer? _resendTimer;
  String? _challengeId;
  String? _challengePhone;
  String? _errorMessage;
  int _expiresIn = 0;
  int _resendSeconds = 0;
  bool _isSending = false;
  bool _isVerifying = false;
  bool _isEnteringDemo = false;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String? get _normalizedPhone {
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (!RegExp(r'^1[3-9][0-9]{9}$').hasMatch(digits)) return null;
    return '+86$digits';
  }

  Future<void> _sendCode() async {
    final phone = _normalizedPhone;
    if (phone == null) {
      _showError(AuthErrorCode.validationError);
      return;
    }
    setState(() {
      _isSending = true;
      _errorMessage = null;
    });
    try {
      final response = await widget.authService.sendSmsCode(
        SendSmsCodeRequest(
          phone: phone,
          purpose: SmsPurpose.login,
          deviceId: await widget.deviceId,
        ),
      );
      if (!mounted) return;
      setState(() {
        _challengeId = response.challengeId;
        _challengePhone = phone;
        _expiresIn = response.expiresIn;
        _resendSeconds = response.resendAfter;
        _codeController.clear();
      });
      _startResendTimer();
    } on AuthException catch (error) {
      if (mounted) _showError(error.code);
    } catch (_) {
      if (mounted) _showError(AuthErrorCode.smsProviderUnavailable);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _verifyCode() async {
    final phone = _normalizedPhone;
    final code = _codeController.text.trim();
    if (phone == null ||
        phone != _challengePhone ||
        _challengeId == null ||
        !RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      _showError(AuthErrorCode.validationError);
      return;
    }
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });
    try {
      final response = await widget.authService.verifySmsCode(
        VerifySmsCodeRequest(
          challengeId: _challengeId!,
          phone: phone,
          code: code,
          deviceId: await widget.deviceId,
        ),
      );
      if (!mounted) return;
      widget.onAuthenticated(response);
    } on AuthException catch (error) {
      if (mounted) _showError(error.code);
    } catch (_) {
      if (mounted) _showError(AuthErrorCode.smsProviderUnavailable);
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds -= 1);
      }
    });
  }

  void _onPhoneChanged(String _) {
    if (_challengeId == null) return;
    setState(() {
      _challengeId = null;
      _challengePhone = null;
      _expiresIn = 0;
      _resendSeconds = 0;
      _errorMessage = null;
      _codeController.clear();
    });
    _resendTimer?.cancel();
  }

  void _showError(AuthErrorCode code) {
    setState(() => _errorMessage = switch (code) {
          AuthErrorCode.validationError => '请输入有效手机号和 6 位验证码。',
          AuthErrorCode.smsCodeExpired => '验证码已失效，请重新获取。',
          AuthErrorCode.smsCodeInvalid => '验证码错误，请检查后重试。',
          AuthErrorCode.verificationAttemptsExceeded => '验证次数过多，请重新获取验证码。',
          AuthErrorCode.rateLimited => '发送过于频繁，请稍后再试。',
          AuthErrorCode.smsProviderUnavailable => '短信服务暂时不可用，请稍后再试。',
          AuthErrorCode.unauthorized ||
          AuthErrorCode.invalidRefreshToken =>
            '登录状态已失效，请重新登录。',
        });
  }

  Future<void> _enterDemo() async {
    if (_isEnteringDemo) return;
    setState(() => _isEnteringDemo = true);
    try {
      await widget.onEnterDemo();
    } finally {
      if (mounted) setState(() => _isEnteringDemo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final split = constraints.maxWidth >= 840;
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: ResponsivePage(
                maxWidth: 1080,
                child: split
                    ? SizedBox(
                        height: constraints.maxHeight - 48,
                        child: Row(
                          children: [
                            const Expanded(flex: 6, child: _LoginHero()),
                            const SizedBox(width: 56),
                            Expanded(
                              flex: 4,
                              child: _LoginForm(
                                phoneController: _phoneController,
                                codeController: _codeController,
                                demoMode: widget.demoMode,
                                isEnteringDemo: _isEnteringDemo,
                                challengeCreated: _challengeId != null,
                                showExampleCode: widget.showExampleCode,
                                expiresIn: _expiresIn,
                                resendSeconds: _resendSeconds,
                                isSending: _isSending,
                                isVerifying: _isVerifying,
                                errorMessage: _errorMessage,
                                onPhoneChanged: _onPhoneChanged,
                                onSendCode: _sendCode,
                                onVerifyCode: _verifyCode,
                                onEnterDemo: _enterDemo,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _LoginHero(),
                          const SizedBox(height: 28),
                          _LoginForm(
                            phoneController: _phoneController,
                            codeController: _codeController,
                            demoMode: widget.demoMode,
                            isEnteringDemo: _isEnteringDemo,
                            challengeCreated: _challengeId != null,
                            showExampleCode: widget.showExampleCode,
                            expiresIn: _expiresIn,
                            resendSeconds: _resendSeconds,
                            isSending: _isSending,
                            isVerifying: _isVerifying,
                            errorMessage: _errorMessage,
                            onPhoneChanged: _onPhoneChanged,
                            onSendCode: _sendCode,
                            onVerifyCode: _verifyCode,
                            onEnterDemo: _enterDemo,
                          ),
                        ],
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.phoneController,
    required this.codeController,
    required this.demoMode,
    required this.isEnteringDemo,
    required this.challengeCreated,
    required this.showExampleCode,
    required this.expiresIn,
    required this.resendSeconds,
    required this.isSending,
    required this.isVerifying,
    required this.errorMessage,
    required this.onPhoneChanged,
    required this.onSendCode,
    required this.onVerifyCode,
    required this.onEnterDemo,
  });

  final TextEditingController phoneController;
  final TextEditingController codeController;
  final bool demoMode;
  final bool isEnteringDemo;
  final bool challengeCreated;
  final bool showExampleCode;
  final int expiresIn;
  final int resendSeconds;
  final bool isSending;
  final bool isVerifying;
  final String? errorMessage;
  final ValueChanged<String> onPhoneChanged;
  final VoidCallback onSendCode;
  final VoidCallback onVerifyCode;
  final VoidCallback onEnterDemo;

  @override
  Widget build(BuildContext context) {
    if (demoMode) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('欢迎体验 Easylife',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          Text(
            '这是作品集演示版本。无需手机号或验证码，体验数据仅保存在当前设备。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            key: const Key('enter-demo-button'),
            onPressed: isEnteringDemo ? null : onEnterDemo,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(isEnteringDemo ? '正在进入…' : '进入作品演示'),
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('欢迎回来', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          '使用中国大陆手机号验证，新号码将自动注册',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 28),
        TextField(
          key: const Key('phone-field'),
          controller: phoneController,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
          onChanged: onPhoneChanged,
          decoration: const InputDecoration(
            labelText: '手机号',
            hintText: '请输入 11 位中国大陆手机号',
            prefixText: '+86 ',
          ),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                key: const Key('sms-code-field'),
                controller: codeController,
                enabled: challengeCreated,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(
                  labelText: '短信验证码',
                  hintText: '6 位数字',
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 56,
              child: OutlinedButton(
                key: const Key('send-code-button'),
                onPressed: isSending || resendSeconds > 0 ? null : onSendCode,
                child: Text(
                  isSending
                      ? '发送中'
                      : resendSeconds > 0
                          ? '${resendSeconds}s 后重发'
                          : challengeCreated
                              ? '重新发送'
                              : '获取验证码',
                ),
              ),
            ),
          ],
        ),
        if (challengeCreated) ...[
          const SizedBox(height: 10),
          Text(
            '验证码 ${expiresIn ~/ 60} 分钟内有效。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (errorMessage != null) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              errorMessage!,
              key: const Key('auth-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
        const SizedBox(height: 22),
        FilledButton(
          key: const Key('verify-code-button'),
          onPressed: challengeCreated && !isVerifying ? onVerifyCode : null,
          child: Text(isVerifying ? '验证中...' : '验证并登录'),
        ),
      ],
    );
  }
}

class _LoginHero extends StatelessWidget {
  const _LoginHero();

  @override
  Widget build(BuildContext context) {
    final wide = ResponsivePage.isWide(context);
    return Container(
      height: wide ? double.infinity : 236,
      constraints: const BoxConstraints(minHeight: 236),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.primaryMist,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.outline),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -34,
            top: -40,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: AppColors.champagneSoft.withValues(alpha: .68),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -26,
            bottom: -52,
            child: Container(
              width: 142,
              height: 142,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .65),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              wide ? 48 : 24,
              24,
              wide ? 34 : 14,
              16,
            ),
            child: wide
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '欢迎来到 Easylife',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '照顾生活，也照顾此刻的自己。',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 30),
                      const Align(
                        alignment: Alignment.center,
                        child: CompanionPet(size: 230),
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '欢迎来到 Easylife',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '照顾生活，也照顾\n此刻的自己。',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    color: AppColors.ink,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const CompanionPet(size: 142),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
