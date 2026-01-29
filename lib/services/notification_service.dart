import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:shared_preferences/shared_preferences.dart';
import 'storage_service.dart';

/// 本地推送通知服务
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final StorageService _storage = StorageService();
  
  static const String _enabledKey = 'notifications_enabled';
  static const int _monthlyReminderId = 1001;

  /// 初始化通知服务
  Future<void> initialize() async {
    // Web 和 Windows 不支持本地推送
    if (kIsWeb) return;
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      debugPrint('Local notifications not supported on this platform');
      return;
    }

    // 延迟时区初始化到后台，不阻塞启动
    Future.microtask(() => tz_data.initializeTimeZones());

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,  // 不在启动时请求权限
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // 延迟检查通知状态，不阻塞启动
    Future.microtask(() async {
      if (await isEnabled()) {
        await scheduleMonthlyReminder();
      }
    });
  }

  /// 处理通知点击
  void _onNotificationTapped(NotificationResponse response) {
    // 可以在这里处理通知点击后的导航
    debugPrint('Notification tapped: ${response.payload}');
  }

  /// 请求通知权限
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    if (Platform.isWindows || Platform.isLinux) return false;

    if (Platform.isAndroid) {
      final android = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? false;
    } else if (Platform.isIOS) {
      final ios = _notifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return false;
  }

  /// 检查是否已启用通知
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  /// 设置通知开关
  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);

    if (enabled) {
      final granted = await requestPermission();
      if (granted) {
        await scheduleMonthlyReminder();
      }
    } else {
      await cancelMonthlyReminder();
    }
  }

  /// 调度每月提醒（每月1号上午10点）
  Future<void> scheduleMonthlyReminder() async {
    if (kIsWeb) return;
    if (Platform.isWindows || Platform.isLinux) return;

    await cancelMonthlyReminder();

    // 计算下一个月1号10:00
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.month == 12 ? now.year + 1 : now.year,
      now.month == 12 ? 1 : now.month + 1,
      10, // 10:00 AM
    );

    // 如果当前就是1号且还没到10点，则今天就发
    if (now.day == 1 && now.hour < 10) {
      scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, 1, 10);
    }

    await _notifications.zonedSchedule(
      _monthlyReminderId,
      '随礼记提醒',
      '您有待处理的人情，点击查看详情',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'monthly_reminder',
          '每月提醒',
          channelDescription: '每月初提醒未还人情',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
    );
  }

  /// 取消每月提醒
  Future<void> cancelMonthlyReminder() async {
    await _notifications.cancel(_monthlyReminderId);
  }

  /// 立即发送通知（测试用）
  Future<void> showTestNotification() async {
    if (kIsWeb) return;

    // 获取未还Top3
    final unreturnedGifts = await _storage.getUnreturnedGifts();
    final guests = await _storage.getAllGuests();
    final guestMap = {for (var g in guests) g.id!: g};

    // 按天数排序取前3
    unreturnedGifts.sort((a, b) => a.date.compareTo(b.date));
    final top3 = unreturnedGifts.take(3).toList();

    String body;
    if (top3.isEmpty) {
      body = '太棒了！您没有待处理的人情';
    } else {
      final names = top3.map((g) {
        final guest = guestMap[g.guestId];
        return guest?.name ?? '未知';
      }).join('、');
      body = '待还人情Top3：$names';
    }

    await _notifications.show(
      0,
      '随礼记提醒',
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test_notification',
          '测试通知',
          channelDescription: '测试通知渠道',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: 'pending_list',
    );
  }
}
