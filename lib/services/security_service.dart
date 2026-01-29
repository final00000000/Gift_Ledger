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
  static const _lockTimeout = Duration(minutes: 1);
  static const int _maxAttempts = 5;

  // 运行时状态
  DateTime? _pausedTimestamp;
  bool _isInitialized = false;

  // 安全模式枚举
  static const modeNone = 'none';
  static const modeFortress = 'fortress'; // 启动即锁
  static const modeInvisible = 'invisible'; // 隐形模式

  Future<void> init() async {
    if (_isInitialized) return;
    
    // 监听 App 生命周期
    WidgetsBinding.instance.addObserver(this);
    
    // 初始化锁定状态
    final mode = await getSecurityMode();
    isUnlocked.value = (mode == modeNone);
    notifyListeners();
    
    _isInitialized = true;
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

  /// 获取当前安全模式
  Future<String> getSecurityMode() async {
    return await _storage.read(key: _keyMode) ?? modeNone;
  }

  /// 获取剩余尝试次数
  Future<int> getRemainingAttempts() async {
    final countStr = await _storage.read(key: _keyFailCount) ?? '0';
    final count = int.tryParse(countStr) ?? 0;
    return _maxAttempts - count;
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
    if (mode == modeNone) {
      isUnlocked.value = true;
      notifyListeners();
    } else {
      // 切换到有锁模式，立即上锁
      lock();
    }
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
          final lockTime = DateTime.now().add(const Duration(minutes: 1));
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
}