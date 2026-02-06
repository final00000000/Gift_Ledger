import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';

/// 安全服务 - 继承 ChangeNotifier 以支持 Provider 状态管理
class SecurityService extends ChangeNotifier with WidgetsBindingObserver {
  // 单例模式
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  final _storage = const FlutterSecureStorage();

  // 状态 - 使用 ValueNotifier 以支持 ValueListenableBuilder
  final ValueNotifier<bool> isUnlocked = ValueNotifier<bool>(false);
  
  // 配置常量
  static const _keyMode = 'sec_mode';
  static const _keySalt = 'sec_salt';
  static const _keyHash = 'sec_hash';
  static const _keyFailCount = 'sec_fail_count';
  static const _keyLockUntil = 'sec_lock_until';
  static const _keyHintQuestion = 'sec_hint_question';  // 密码提示问题
  static const _keyHintAnswerHash = 'sec_hint_answer';  // 答案哈希
  static const _keyHintSalt = 'sec_hint_salt';          // 答案盐值
  // 后台超时自动上锁的阈值：30s（更符合“快速离开就锁”的安全预期）
  static const _lockTimeout = Duration(seconds: 30);
  static const int _maxAttempts = 5;

  // 运行时状态
  DateTime? _pausedTimestamp;
  bool _isInitialized = false;
  Future<void>? _initFuture;

  // 内存缓存（避免频繁读取 FlutterSecureStorage）
  String? _cachedSecurityMode;
  DateTime? _cacheExpiry;
  static const _cacheDuration = Duration(seconds: 30);

  // 安全模式枚举
  static const modeNone = 'none';
  static const modeFortress = 'fortress'; // 启动即锁
  static const modeInvisible = 'invisible'; // 隐形模式

  Future<void> init() {
    // 多页面/多组件可能并发触发 init：缓存 Future，避免重复 addObserver 与状态抖动。
    _initFuture ??= _initInternal();
    return _initFuture!;
  }

  Future<void> _initInternal() async {
    if (_isInitialized) return;

    // 监听 App 生命周期
    WidgetsBinding.instance.addObserver(this);

    // 初始化锁定状态
    final mode = await getSecurityMode();
    isUnlocked.value = (mode == modeNone);
    notifyListeners();

    _isInitialized = true;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedTimestamp = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      _checkLockTimeout();
    }
  }

  Future<void> _checkLockTimeout() async {
    // 优化: 如果已经锁定，无需再次检查
    if (!isUnlocked.value) return;

    final mode = await getSecurityMode();
    if (mode == modeNone) return;

    // 堡垒模式：从后台切回时强制上锁（不依赖超时）
    if (mode == modeFortress) {
      lock();
      _pausedTimestamp = null;
      return;
    }

    if (_pausedTimestamp != null) {
      final difference = DateTime.now().difference(_pausedTimestamp!);
      if (difference > _lockTimeout) {
        // 超时自动上锁
        lock();
      }
      _pausedTimestamp = null;
    }
  }

  // --- 核心 API ---

  /// 获取当前安全模式（带内存缓存）
  Future<String> getSecurityMode() async {
    // 检查缓存是否有效
    if (_cachedSecurityMode != null &&
        _cacheExpiry != null &&
        DateTime.now().isBefore(_cacheExpiry!)) {
      return _cachedSecurityMode!;
    }

    // 缓存失效，从存储读取
    final mode = await _storage.read(key: _keyMode) ?? modeNone;

    // 更新缓存
    _cachedSecurityMode = mode;
    _cacheExpiry = DateTime.now().add(_cacheDuration);

    return mode;
  }

  /// 获取剩余尝试次数
  Future<int> getRemainingAttempts() async {
    final countStr = await _storage.read(key: _keyFailCount) ?? '0';
    final count = int.tryParse(countStr) ?? 0;
    return _maxAttempts - count;
  }

  /// 清除锁定状态与错误计数（不影响 PIN/提示问题/安全模式）
  Future<void> clearLockout() async {
    await _storage.delete(key: _keyFailCount);
    await _storage.delete(key: _keyLockUntil);
  }

  /// 获取锁定截止时间（如果没被锁定则返回 null）
  Future<DateTime?> getLockUntil() async {
    final timeStr = await _storage.read(key: _keyLockUntil);
    if (timeStr == null) return null;
    final time = DateTime.tryParse(timeStr);
    if (time != null && time.isAfter(DateTime.now())) {
      return time;
    }
    return null;
  }

  /// 设置安全模式
  Future<void> setSecurityMode(String mode) async {
    await _storage.write(key: _keyMode, value: mode);

    // 清除缓存，确保下次读取最新值
    _cachedSecurityMode = null;
    _cacheExpiry = null;

    if (mode == modeNone) {
      // 关闭安全锁时，只清除失败计数和锁定时间，保留密码和提示数据
      await _storage.delete(key: _keyFailCount);
      await _storage.delete(key: _keyLockUntil);
      isUnlocked.value = true;
      notifyListeners();
    } else {
      // 切换到有锁模式，立即上锁
      lock();
    }
  }

  /// 清除所有安全数据（密码和提示）
  Future<void> clearAllSecurityData() async {
    await _storage.delete(key: _keySalt);
    await _storage.delete(key: _keyHash);
    await _storage.delete(key: _keyFailCount);
    await _storage.delete(key: _keyLockUntil);
    await _storage.delete(key: _keyHintQuestion);
    await _storage.delete(key: _keyHintSalt);
    await _storage.delete(key: _keyHintAnswerHash);
  }

  /// 验证密码
  Future<bool> verifyPin(String inputPin) async {
    // 1. 检查是否在锁定中
    final lockUntil = await getLockUntil();
    if (lockUntil != null) return false;

    try {
      final salt = await _storage.read(key: _keySalt);
      final storedHash = await _storage.read(key: _keyHash);
      
      if (salt == null || storedHash == null) return false;
      
      final inputHash = _generateHash(inputPin, salt);
      final isValid = inputHash == storedHash;
      
      if (isValid) {
        // 成功：重置计数和锁定
        await _storage.delete(key: _keyFailCount);
        await _storage.delete(key: _keyLockUntil);
        unlock();
      } else {
        // 失败：增加计数
        final countStr = await _storage.read(key: _keyFailCount) ?? '0';
        final newCount = (int.tryParse(countStr) ?? 0) + 1;
        
        if (newCount >= _maxAttempts) {
          // 达到上限：设置锁定时间
          // 输错次数达到上限后的锁定时长：30s
          final lockTime = DateTime.now().add(const Duration(seconds: 30));
          await _storage.write(key: _keyLockUntil, value: lockTime.toIso8601String());
          await _storage.delete(key: _keyFailCount); // 锁定后重置计数
        } else {
          await _storage.write(key: _keyFailCount, value: newCount.toString());
        }
      }
      
      return isValid;
    } catch (e) {
      debugPrint('Error verifying PIN: $e');
      return false;
    }
  }

  /// 设置新密码
  Future<void> setPin(String newPin) async {
    // 1. 生成随机盐 (使用时间戳模拟，生产环境可用更强的随机源)
    final salt = DateTime.now().toIso8601String() + newPin.length.toString();
    
    // 2. 计算哈希
    final hash = _generateHash(newPin, salt);
    
    // 3. 存储
    await _storage.write(key: _keySalt, value: salt);
    await _storage.write(key: _keyHash, value: hash);
    // 重置之前的失败计数
    await _storage.delete(key: _keyFailCount);
    await _storage.delete(key: _keyLockUntil);
  }

  /// 是否已设置密码
  Future<bool> hasPin() async {
    final hash = await _storage.read(key: _keyHash);
    return hash != null;
  }

  /// 手动解锁
  void unlock() {
    if (!isUnlocked.value) {
      isUnlocked.value = true;
      notifyListeners();
    }
  }

  /// 手动上锁
  void lock() {
    if (isUnlocked.value) {
      isUnlocked.value = false;
      notifyListeners();
    }
  }

  /// 内部哈希生成
  String _generateHash(String pin, String salt) {
    var bytes = utf8.encode(pin + salt);
    return sha256.convert(bytes).toString();
  }

  // --- 密码提示功能 ---

  /// 设置密码提示问题和答案
  Future<void> setSecurityHint(String question, String answer) async {
    // 生成答案的盐和哈希（答案不区分大小写）
    final salt = DateTime.now().toIso8601String() + question.length.toString();
    final normalizedAnswer = answer.trim().toLowerCase();
    final hash = _generateHash(normalizedAnswer, salt);

    await _storage.write(key: _keyHintQuestion, value: question);
    await _storage.write(key: _keyHintSalt, value: salt);
    await _storage.write(key: _keyHintAnswerHash, value: hash);
  }

  /// 获取密码提示问题
  Future<String?> getSecurityQuestion() async {
    return await _storage.read(key: _keyHintQuestion);
  }

  /// 是否已设置密码提示
  Future<bool> hasSecurityHint() async {
    final question = await _storage.read(key: _keyHintQuestion);
    final hash = await _storage.read(key: _keyHintAnswerHash);
    return question != null && hash != null;
  }

  /// 验证密码提示答案
  Future<bool> verifySecurityAnswer(String answer) async {
    try {
      final salt = await _storage.read(key: _keyHintSalt);
      final storedHash = await _storage.read(key: _keyHintAnswerHash);

      if (salt == null || storedHash == null) return false;

      final normalizedAnswer = answer.trim().toLowerCase();
      final inputHash = _generateHash(normalizedAnswer, salt);
      return inputHash == storedHash;
    } catch (e) {
      debugPrint('Error verifying security answer: $e');
      return false;
    }
  }

  /// 重置密码（清除密码但保留提示问题）
  Future<void> resetPassword() async {
    await _storage.delete(key: _keySalt);
    await _storage.delete(key: _keyHash);
    await _storage.delete(key: _keyFailCount);
    await _storage.delete(key: _keyLockUntil);
    // 重置安全模式为无锁
    await _storage.write(key: _keyMode, value: modeNone);
    isUnlocked.value = true;
    notifyListeners();
  }

  /// 清除密码提示
  Future<void> clearSecurityHint() async {
    await _storage.delete(key: _keyHintQuestion);
    await _storage.delete(key: _keyHintSalt);
    await _storage.delete(key: _keyHintAnswerHash);
  }
}
