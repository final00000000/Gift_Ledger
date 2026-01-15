import 'package:lunar/lunar.dart';

/// 农历日期工具类
class LunarUtils {
  /// 获取农历日期字符串
  /// 如："腊月廿五" 或 "正月初一"
  static String getLunarDateString(DateTime date) {
    try {
      final solar = Solar.fromDate(date);
      final lunar = Lunar.fromSolar(solar);
      return '${lunar.getMonthInChinese()}月${lunar.getDayInChinese()}';
    } catch (e) {
      return '';
    }
  }
  
  /// 获取完整农历字符串
  /// 如："农历乙巳年腊月廿五"
  static String getFullLunarString(DateTime date) {
    try {
      final solar = Solar.fromDate(date);
      final lunar = Lunar.fromSolar(solar);
      return '农历${lunar.getYearInChinese()}年${lunar.getMonthInChinese()}月${lunar.getDayInChinese()}';
    } catch (e) {
      return '';
    }
  }

  /// 获取农历年份（如"乙巳年"）
  static String getLunarYear(DateTime date) {
    try {
      final solar = Solar.fromDate(date);
      final lunar = Lunar.fromSolar(solar);
      return '${lunar.getYearInChinese()}年';
    } catch (e) {
      return '';
    }
  }

  /// 获取农历月份（如"腊月"）
  static String getLunarMonth(DateTime date) {
    try {
      final solar = Solar.fromDate(date);
      final lunar = Lunar.fromSolar(solar);
      return '${lunar.getMonthInChinese()}月';
    } catch (e) {
      return '';
    }
  }

  /// 获取农历日期（如"廿五"）
  static String getLunarDay(DateTime date) {
    try {
      final solar = Solar.fromDate(date);
      final lunar = Lunar.fromSolar(solar);
      return lunar.getDayInChinese();
    } catch (e) {
      return '';
    }
  }
}
