import 'package:shared_preferences/shared_preferences.dart';

/// 配置服务 - 预加载并缓存 SharedPreferences 数据
///
/// 解决问题：
/// - SharedPreferences 每次异步读取耗时 50-150ms
/// - 多个服务重复读取相同配置
///
/// 优化方案：
/// - 应用启动时一次性预加载所有配置
/// - 内存缓存，同步读取
/// - 写入时同时更新缓存和持久化存储
class ConfigService {
  // 单例模式
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal();

  SharedPreferences? _prefs;
  bool _isInitialized = false;

  // 内存缓存
  final Map<String, dynamic> _cache = {};

  /// 初始化并预加载所有配置
  Future<void> init() async {
    if (_isInitialized) return;

    _prefs = await SharedPreferences.getInstance();

    // 预加载所有配置到内存缓存
    final keys = _prefs!.getKeys();
    for (final key in keys) {
      final value = _prefs!.get(key);
      _cache[key] = value;
    }

    _isInitialized = true;
  }

  /// 确保已初始化
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError('ConfigService not initialized. Call init() first.');
    }
  }

  // --- 同步读取方法（从内存缓存） ---

  /// 获取字符串配置（同步）
  String? getString(String key) {
    _ensureInitialized();
    return _cache[key] as String?;
  }

  /// 获取整数配置（同步）
  int? getInt(String key) {
    _ensureInitialized();
    return _cache[key] as int?;
  }

  /// 获取布尔配置（同步）
  bool? getBool(String key) {
    _ensureInitialized();
    return _cache[key] as bool?;
  }

  /// 获取双精度配置（同步）
  double? getDouble(String key) {
    _ensureInitialized();
    return _cache[key] as double?;
  }

  /// 获取字符串列表配置（同步）
  List<String>? getStringList(String key) {
    _ensureInitialized();
    return _cache[key] as List<String>?;
  }

  // --- 写入方法（同时更新缓存和持久化） ---

  /// 设置字符串配置
  Future<bool> setString(String key, String value) async {
    _ensureInitialized();
    _cache[key] = value;
    return await _prefs!.setString(key, value);
  }

  /// 设置整数配置
  Future<bool> setInt(String key, int value) async {
    _ensureInitialized();
    _cache[key] = value;
    return await _prefs!.setInt(key, value);
  }

  /// 设置布尔配置
  Future<bool> setBool(String key, bool value) async {
    _ensureInitialized();
    _cache[key] = value;
    return await _prefs!.setBool(key, value);
  }

  /// 设置双精度配置
  Future<bool> setDouble(String key, double value) async {
    _ensureInitialized();
    _cache[key] = value;
    return await _prefs!.setDouble(key, value);
  }

  /// 设置字符串列表配置
  Future<bool> setStringList(String key, List<String> value) async {
    _ensureInitialized();
    _cache[key] = value;
    return await _prefs!.setStringList(key, value);
  }

  /// 删除配置
  Future<bool> remove(String key) async {
    _ensureInitialized();
    _cache.remove(key);
    return await _prefs!.remove(key);
  }

  /// 清除所有配置
  Future<bool> clear() async {
    _ensureInitialized();
    _cache.clear();
    return await _prefs!.clear();
  }

  /// 检查配置是否存在
  bool containsKey(String key) {
    _ensureInitialized();
    return _cache.containsKey(key);
  }

  /// 获取所有配置键
  Set<String> getKeys() {
    _ensureInitialized();
    return _cache.keys.toSet();
  }
}
