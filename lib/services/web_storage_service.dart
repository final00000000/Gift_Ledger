import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/gift.dart';
import '../models/guest.dart';

// Web 平台的内存存储实现
class WebStorageService {
  final List<Guest> _guests = [];
  final List<Gift> _gifts = [];
  int _guestIdCounter = 1;
  int _giftIdCounter = 1;

  // Guest CRUD
  Future<int> insertGuest(Guest guest) async {
    final newGuest = Guest(
      id: _guestIdCounter++,
      name: guest.name,
      relationship: guest.relationship,
      phone: guest.phone,
      note: guest.note,
    );
    _guests.add(newGuest);
    return newGuest.id!;
  }

  Future<List<Guest>> getAllGuests() async {
    return List.from(_guests)..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<Guest?> getGuestById(int id) async {
    try {
      return _guests.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<Guest?> getGuestByName(String name) async {
    try {
      return _guests.firstWhere((g) => g.name == name);
    } catch (_) {
      return null;
    }
  }

  Future<int> updateGuest(Guest guest) async {
    final index = _guests.indexWhere((g) => g.id == guest.id);
    if (index != -1) {
      _guests[index] = guest;
      return 1;
    }
    return 0;
  }

  Future<int> deleteGuest(int id) async {
    _gifts.removeWhere((g) => g.guestId == id);
    _guests.removeWhere((g) => g.id == id);
    return 1;
  }

  // Gift CRUD
  Future<int> insertGift(Gift gift) async {
    final newGift = Gift(
      id: _giftIdCounter++,
      guestId: gift.guestId,
      amount: gift.amount,
      isReceived: gift.isReceived,
      eventType: gift.eventType,
      date: gift.date,
      note: gift.note,
    );
    _gifts.add(newGift);
    return newGift.id!;
  }

  Future<List<Gift>> getAllGifts() async {
    return List.from(_gifts)..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<List<Gift>> getGiftsByGuest(int guestId) async {
    return _gifts.where((g) => g.guestId == guestId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<List<Gift>> getRecentGifts({int limit = 10}) async {
    final sorted = List<Gift>.from(_gifts)
      ..sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0)); // 按 ID 降序，确保新录入的在前
    return sorted.take(limit).toList();
  }

  Future<int> updateGift(Gift gift) async {
    final index = _gifts.indexWhere((g) => g.id == gift.id);
    if (index != -1) {
      _gifts[index] = gift;
      return 1;
    }
    return 0;
  }

  Future<int> deleteGift(int id) async {
    _gifts.removeWhere((g) => g.id == id);
    return 1;
  }

  // 统计
  Future<double> getTotalReceived() async {
    double total = 0;
    for (var g in _gifts.where((g) => g.isReceived)) {
      total += g.amount;
    }
    return total;
  }

  Future<double> getTotalSent() async {
    double total = 0;
    for (var g in _gifts.where((g) => !g.isReceived)) {
      total += g.amount;
    }
    return total;
  }

  Future<Map<int, double>> getGuestReceivedTotals() async {
    final Map<int, double> totals = {};
    for (var gift in _gifts.where((g) => g.isReceived)) {
      totals[gift.guestId] = (totals[gift.guestId] ?? 0) + gift.amount;
    }
    return totals;
  }

  Future<Map<int, double>> getGuestSentTotals() async {
    final Map<int, double> totals = {};
    for (var gift in _gifts.where((g) => !g.isReceived)) {
      totals[gift.guestId] = (totals[gift.guestId] ?? 0) + gift.amount;
    }
    return totals;
  }

  Future<void> saveGiftWithGuest(Gift gift, Guest guest) async {
    // 检查联系人是否存在
    final existingGuest = await getGuestByName(guest.name);
    int guestId;
    if (existingGuest == null) {
      guestId = await insertGuest(guest);
    } else {
      guestId = existingGuest.id!;
      if (existingGuest.relationship != guest.relationship) {
        await updateGuest(existingGuest.copyWith(relationship: guest.relationship));
      }
    }
    // 保存礼金
    await insertGift(gift.copyWith(guestId: guestId));
  }
}

// 统一的存储服务接口
WebStorageService? _webStorage;

WebStorageService get webStorage {
  _webStorage ??= WebStorageService();
  return _webStorage!;
}

bool get isWeb => kIsWeb;
