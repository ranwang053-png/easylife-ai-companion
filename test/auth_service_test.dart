import 'dart:convert';
import 'dart:io';

import 'package:company_app/models/auth_models.dart';
import 'package:company_app/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = FixedExampleAuthService();

  test('fixed auth service matches the V1.1.0 SMS examples', () async {
    final sendExample = jsonDecode(
      File(
        'contracts/examples/sms-code-response.json',
      ).readAsStringSync(),
    ) as Map<String, dynamic>;
    final verifyExample = jsonDecode(
      File(
        'contracts/examples/sms-verify-response.json',
      ).readAsStringSync(),
    ) as Map<String, dynamic>;

    final sent = await service.sendSmsCode(
      const SendSmsCodeRequest(
        phone: '+8613812345678',
        purpose: SmsPurpose.login,
        deviceId: FixedExampleAuthService.deviceId,
      ),
    );

    expect(sent.challengeId, sendExample['challengeId']);
    expect(sent.expiresIn, sendExample['expiresIn']);
    expect(sent.resendAfter, sendExample['resendAfter']);

    final verified = await service.verifySmsCode(
      VerifySmsCodeRequest(
        challengeId: sent.challengeId,
        phone: '+8613812345678',
        code: FixedExampleAuthService.exampleCode,
        deviceId: FixedExampleAuthService.deviceId,
      ),
    );

    expect(verified.purpose.wireValue, verifyExample['purpose']);
    expect(verified.isNewUser, verifyExample['isNewUser']);
    expect(
      verified.user.phoneMasked,
      (verifyExample['user'] as Map<String, dynamic>)['phoneMasked'],
    );
    expect(
      verified.tokens.accessTokenExpiresIn,
      (verifyExample['tokens'] as Map<String, dynamic>)['accessTokenExpiresIn'],
    );
    expect(
      verified.tokens.refreshTokenExpiresIn,
      (verifyExample['tokens']
          as Map<String, dynamic>)['refreshTokenExpiresIn'],
    );
  });

  test('fixed auth service validates phone and verification code', () async {
    expect(
      () => service.sendSmsCode(
        const SendSmsCodeRequest(
          phone: '+8612812345678',
          purpose: SmsPurpose.login,
          deviceId: FixedExampleAuthService.deviceId,
        ),
      ),
      throwsA(
        isA<AuthException>().having(
          (error) => error.code,
          'code',
          AuthErrorCode.validationError,
        ),
      ),
    );

    expect(
      () => service.verifySmsCode(
        const VerifySmsCodeRequest(
          challengeId: '984e6346-f8a1-4511-8ec2-a960bc338705',
          phone: '+8613812345678',
          code: '000000',
          deviceId: FixedExampleAuthService.deviceId,
        ),
      ),
      throwsA(
        isA<AuthException>().having(
          (error) => error.code,
          'code',
          AuthErrorCode.smsCodeInvalid,
        ),
      ),
    );
  });
}
