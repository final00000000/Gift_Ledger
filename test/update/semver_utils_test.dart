import 'package:flutter_test/flutter_test.dart';
import 'package:gift_ledger/utils/semver_utils.dart';

void main() {
  group('compareSemver', () {
    test('预发布版本低于正式版', () {
      expect(compareSemver('1.3.0-beta.2', '1.3.0'), lessThan(0));
    });

    test('更高补丁版本的预发布版本高于较低正式版', () {
      expect(compareSemver('1.3.1-beta.1', '1.3.0'), greaterThan(0));
    });

    test('更高补丁版本的正式版高于较低正式版', () {
      expect(compareSemver('1.3.1', '1.3.0'), greaterThan(0));
    });

    test('相同版本返回零', () {
      expect(compareSemver('1.3.0', '1.3.0'), 0);
    });
  });
}
