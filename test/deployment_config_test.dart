import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GitHub Pages demo is built with a public backend API base URL', () {
    final workflow = File(
      '.github/workflows/deploy-web-demo.yml',
    ).readAsStringSync();

    expect(
      workflow,
      contains('EASYLIFE_API_BASE_URL: \${{ secrets.EASYLIFE_API_BASE_URL }}'),
    );
    expect(
      workflow,
      contains(r'--dart-define=EASYLIFE_API_BASE_URL=$EASYLIFE_API_BASE_URL'),
    );
  });
}
