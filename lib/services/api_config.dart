/// API 配置
class ApiConfig {
  // 编译时可通过 --dart-define=API_BASE_URL=http://xxx 覆盖
  // Android 真机：flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8081
  // Android 模拟器默认：http://10.0.2.2:8081
  // Windows 桌面端：http://localhost:8081
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8081',
  );

  // 超时配置
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);

  // API 端点
  static const String auth = '/auth';
  static const String gifts = '/gifts';
  static const String guests = '/guests';
  static const String eventBooks = '/event-books';
  static const String reports = '/reports';
  static const String reminders = '/reminders';
  static const String exports = '/exports';

  // 认证端点
  static const String login = '$auth/login';
  static const String register = '$auth/register';
  static const String refresh = '$auth/refresh';
  static const String logout = '$auth/logout';
  static const String changePassword = '$auth/change-password';

  // 用户端点
  static const String userMe = '/users/me';

  // 统计端点
  static const String reportsSummary = '$reports/summary';

  // 提醒端点
  static const String remindersPending = '$reminders/pending';

  // 导出端点
  static const String exportsJson = '$exports/json';
  static const String exportsExcel = '$exports/excel';
}
