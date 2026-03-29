import 'package:flutter_test/flutter_test.dart';
import 'package:gift_ledger/services/app_settings_service.dart';
import 'package:gift_ledger/services/config_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppSettingsService', () {
    late AppSettingsService service;

    setUp(() async {
      final config = ConfigService();
      await config.init();
      service = AppSettingsService(configService: config);
    });

    test('getDefaultIsReceived 默认值为 true', () async {
      expect(await service.getDefaultIsReceived(), isTrue);
    });

    test('setDefaultIsReceived 持久化后 get 返回新值', () async {
      await service.setDefaultIsReceived(false);
      expect(await service.getDefaultIsReceived(), isFalse);
    });

    test('setDefaultIsReceived 为 true 后可读回', () async {
      await service.setDefaultIsReceived(false);
      await service.setDefaultIsReceived(true);
      expect(await service.getDefaultIsReceived(), isTrue);
    });

    test('getStatsIncludeEventBooks 默认值为 true', () async {
      expect(await service.getStatsIncludeEventBooks(), isTrue);
    });

    test('setStatsIncludeEventBooks 持久化', () async {
      await service.setStatsIncludeEventBooks(false);
      expect(await service.getStatsIncludeEventBooks(), isFalse);
    });

    test('getEventBooksEnabled 默认值为 true', () async {
      expect(await service.getEventBooksEnabled(), isTrue);
    });

    test('getShowHomeAmounts 默认值为 true', () async {
      expect(await service.getShowHomeAmounts(), isTrue);
    });
  });
}
