/// API 配置
class ApiConfig {
  // 后端 API 地址（修改为实际地址）
  static const String baseUrl = 'http://localhost:8081';

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
