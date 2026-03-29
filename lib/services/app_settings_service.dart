import 'config_service.dart';

class AppSettingsService {
  AppSettingsService({ConfigService? configService})
      : _config = configService ?? ConfigService();

  final ConfigService _config;

  static const String statsIncludeEventBooksKey = 'stats_include_event_books';
  static const String eventBooksEnabledKey = 'event_books_enabled';
  static const String showHomeAmountsKey = 'show_home_amounts';
  static const String defaultIsReceivedKey = 'default_is_received';

  Future<bool> getStatsIncludeEventBooks() async {
    return _config.getBool(statsIncludeEventBooksKey) ?? true;
  }

  Future<void> setStatsIncludeEventBooks(bool value) async {
    await _config.setBool(statsIncludeEventBooksKey, value);
  }

  Future<bool> getEventBooksEnabled() async {
    return _config.getBool(eventBooksEnabledKey) ?? true;
  }

  Future<void> setEventBooksEnabled(bool value) async {
    await _config.setBool(eventBooksEnabledKey, value);
  }

  Future<bool> getShowHomeAmounts() async {
    return _config.getBool(showHomeAmountsKey) ?? true;
  }

  Future<void> setShowHomeAmounts(bool value) async {
    await _config.setBool(showHomeAmountsKey, value);
  }

  Future<bool> getDefaultIsReceived() async {
    return _config.getBool(defaultIsReceivedKey) ?? true;
  }

  Future<void> setDefaultIsReceived(bool value) async {
    await _config.setBool(defaultIsReceivedKey, value);
  }
}
