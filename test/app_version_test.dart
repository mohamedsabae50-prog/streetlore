import 'package:flutter_test/flutter_test.dart';
import 'package:streetlore/core/constants/app_version.dart';

void main() {
  test('user-facing app version omits the platform build number', () {
    expect(kAppVersion, '2.1.45');
    expect(kAppBuildNumber, 248);
    expect(formatAppVersionLabel(), 'Version 2.1.45');
    expect(formatAppVersionLabel(), isNot(contains('+')));
  });
}
