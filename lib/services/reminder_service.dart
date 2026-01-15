import 'package:shared_preferences/shared_preferences.dart';
import '../models/gift.dart';
import '../models/guest.dart';
import 'storage_service.dart';

/// 自动关联校验服务
class ReminderService {
  static final ReminderService _instance = ReminderService._internal();
  factory ReminderService() => _instance;
  ReminderService._internal();

  final _storageService = StorageService();

  /// 运行自动关联校验（App启动/记录变更时调用）
  Future<void> runAutoLinkCheck() async {
    // 获取所有未还的收礼记录
    final unreturnedGifts = await _storageService.getUnreturnedGifts();
    // 获取所有未收的送礼记录
    final pendingReceipts = await _storageService.getPendingReceipts();
    // 获取所有联系人
    final guests = await _storageService.getAllGuests();
    final guestMap = {for (var g in guests) g.id!: g};

    // 为每个未还记录尝试找到匹配的送礼记录
    for (var received in unreturnedGifts) {
      if (received.relatedRecordId != null) continue;
      
      final match = await findMatchingRecord(
        received, 
        pendingReceipts, 
        lookForReceived: false,
      );
      
      if (match != null) {
        await _storageService.linkGiftRecords(received.id!, match.id!);
      }
    }

    // 为每个未收记录尝试找到匹配的收礼记录
    for (var sent in pendingReceipts) {
      if (sent.relatedRecordId != null) continue;
      
      final match = await findMatchingRecord(
        sent, 
        unreturnedGifts,
        lookForReceived: true,
      );
      
      if (match != null) {
        await _storageService.linkGiftRecords(sent.id!, match.id!);
      }
    }
  }

  /// 自动匹配算法
  /// 条件：同guestId + 同eventType + 时间差<365天
  Future<Gift?> findMatchingRecord(
    Gift gift, 
    List<Gift> candidates, 
    {required bool lookForReceived}
  ) async {
    for (var candidate in candidates) {
      if (candidate.relatedRecordId != null) continue;
      if (candidate.id == gift.id) continue;
      
      // 同一个联系人
      if (candidate.guestId != gift.guestId) continue;
      
      // 同一事件类型
      if (candidate.eventType != gift.eventType) continue;
      
      // 时间差在365天内
      final daysDiff = (candidate.date.difference(gift.date).inDays).abs();
      if (daysDiff > 365) continue;
      
      // 找到匹配
      return candidate;
    }
    return null;
  }

  /// 手动标记已还
  Future<void> markAsReturned(int giftId, {int? relatedId}) async {
    await _storageService.updateReturnStatus(
      giftId, 
      isReturned: true, 
      relatedRecordId: relatedId,
    );
  }

  /// 生成话术文本
  String generateReminderText(Gift gift, Guest guest, String template) {
    var text = template
        .replaceAll('{对方}', guest.name)
        .replaceAll('{事件}', gift.eventType)
        .replaceAll('{金额}', '${gift.amount.toStringAsFixed(0)}元')
        .replaceAll('{我的事件}', '活动'); // 可让用户自定义
    return text;
  }

  /// 模糊金额（如1200→"千把块"）
  String fuzzyAmount(double amount) {
    if (amount < 100) {
      return '几十块';
    } else if (amount < 200) {
      return '百来块';
    } else if (amount < 500) {
      return '几百块';
    } else if (amount < 1000) {
      return '大几百';
    } else if (amount < 2000) {
      return '千把块';
    } else if (amount < 5000) {
      return '几千块';
    } else if (amount < 10000) {
      return '大几千';
    } else {
      return '上万块';
    }
  }

  /// 计算已过天数
  int getDaysPassed(DateTime date) {
    return DateTime.now().difference(date).inDays;
  }

  /// 获取颜色状态：0=绿(<90天), 1=橙(90~180天), 2=红(>180天)
  int getStatusLevel(DateTime date) {
    final days = getDaysPassed(date);
    if (days < 90) return 0;
    if (days < 180) return 1;
    return 2;
  }
}
