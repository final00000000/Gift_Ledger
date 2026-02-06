import 'package:lunar/lunar.dart';

/// 农历日期工具类（带缓存优化）
class LunarUtils {
  // 缓存：key = "yyyy-MM-dd", value = Lunar对象
  static final Map<String, Lunar> _lunarCache = {};
  static const int _maxCacheSize = 100; // 最多缓存100个日期

  /// 获取或创建 Lunar 对象（带缓存）
  static Lunar _getLunar(DateTime date) {
    final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    // 检查缓存
    if (_lunarCache.containsKey(key)) {
      return _lunarCache[key]!;
    }

    // 缓存未命中，计算并缓存
    final solar = Solar.fromDate(date);
    final lunar = Lunar.fromSolar(solar);

    // 缓存大小控制：超过限制时清除最早的一半
    if (_lunarCache.length >= _maxCacheSize) {
      final keysToRemove = _lunarCache.keys.take(_maxCacheSize ~/ 2).toList();
      for (final k in keysToRemove) {
        _lunarCache.remove(k);
      }
    }

    _lunarCache[key] = lunar;
    return lunar;
  }

  /// 获取农历日期字符串
  /// 如："腊月廿五" 或 "正月初一"
  static String getLunarDateString(DateTime date) {
    try {
      final lunar = _getLunar(date);
      return '${lunar.getMonthInChinese()}月${lunar.getDayInChinese()}';
    } catch (e) {
      return '';
    }
  }

  /// 获取完整农历字符串
  /// 如："农历乙巳年腊月廿五"
  static String getFullLunarString(DateTime date) {
    try {
      final lunar = _getLunar(date);
      return '农历${lunar.getYearInChinese()}年${lunar.getMonthInChinese()}月${lunar.getDayInChinese()}';
    } catch (e) {
      return '';
    }
  }

  /// 获取农历年份（如"乙巳年"）
  static String getLunarYear(DateTime date) {
    try {
      final lunar = _getLunar(date);
      return '${lunar.getYearInChinese()}年';
    } catch (e) {
      return '';
    }
  }

  /// 获取农历月份（如"腊月"）
  static String getLunarMonth(DateTime date) {
    try {
      final lunar = _getLunar(date);
      return '${lunar.getMonthInChinese()}月';
    } catch (e) {
      return '';
    }
  }

  /// 获取农历日期（如"廿五"）
  static String getLunarDay(DateTime date) {
    try {
      final lunar = _getLunar(date);
      return lunar.getDayInChinese();
    } catch (e) {
      return '';
    }
  }

  /// 清除缓存（可选，用于内存管理）
  static void clearCache() {
    _lunarCache.clear();
  }
}
