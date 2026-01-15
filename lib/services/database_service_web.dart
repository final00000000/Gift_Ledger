import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/event_book.dart';
import '../models/gift.dart';
import '../models/guest.dart';

/// Web平台的持久化存储服务 (使用 SharedPreferences + JSON)
class NativeDatabaseService {
  static final NativeDatabaseService _instance = NativeDatabaseService._internal();
  static SharedPreferences? _prefs;

  factory NativeDatabaseService() => _instance;

  NativeDatabaseService._internal();

  Future<SharedPreferences> get _storage async {
    if (_prefs != null) return _prefs!;
    _prefs = await SharedPreferences.getInstance();
    return _prefs!;
  }

  // 存储键
  static const String _guestsKey = 'guests';
  static const String _giftsKey = 'gifts';
  static const String _eventBooksKey = 'eventBooks';
  static const String _guestIdCounterKey = 'guestIdCounter';
  static const String _giftIdCounterKey = 'giftIdCounter';
  static const String _eventBookIdCounterKey = 'eventBookIdCounter';

  // 加载 Guests
  Future<List<Guest>> _loadGuests() async {
    final prefs = await _storage;
    final String? json = prefs.getString(_guestsKey);
    if (json == null) return [];
    
    final List<dynamic> list = jsonDecode(json);
    return list.map((item) => Guest.fromMap(item as Map<String, dynamic>)).toList();
  }

  // 保存 Guests
  Future<void> _saveGuests(List<Guest> guests) async {
    final prefs = await _storage;
    final String json = jsonEncode(guests.map((g) => g.toMap()).toList());
    await prefs.setString(_guestsKey, json);
  }

  Future<List<EventBook>> _loadEventBooks() async {
    final prefs = await _storage;
    final String? json = prefs.getString(_eventBooksKey);
    if (json == null) return [];

    final List<dynamic> list = jsonDecode(json);
    return list.map((item) => EventBook.fromMap(item as Map<String, dynamic>)).toList();
  }

  Future<void> _saveEventBooks(List<EventBook> eventBooks) async {
    final prefs = await _storage;
    final String json = jsonEncode(eventBooks.map((b) => b.toMap()).toList());
    await prefs.setString(_eventBooksKey, json);
  }

  // 加载 Gifts
  Future<List<Gift>> _loadGifts() async {
    final prefs = await _storage;
    final String? json = prefs.getString(_giftsKey);
    if (json == null) return [];
    
    final List<dynamic> list = jsonDecode(json);
    return list.map((item) => Gift.fromMap(item as Map<String, dynamic>)).toList();
  }

  // 保存 Gifts
  Future<void> _saveGifts(List<Gift> gifts) async {
    final prefs = await _storage;
    final String json = jsonEncode(gifts.map((g) => g.toMap()).toList());
    await prefs.setString(_giftsKey, json);
  }

  // ID 计数器
  Future<int> _getNextGuestId() async {
    final prefs = await _storage;
    final int current = prefs.getInt(_guestIdCounterKey) ?? 1;
    await prefs.setInt(_guestIdCounterKey, current + 1);
    return current;
  }

  Future<int> _getNextGiftId() async {
    final prefs = await _storage;
    final int current = prefs.getInt(_giftIdCounterKey) ?? 1;
    await prefs.setInt(_giftIdCounterKey, current + 1);
    return current;
  }

  Future<int> _getNextEventBookId() async {
    final prefs = await _storage;
    final int current = prefs.getInt(_eventBookIdCounterKey) ?? 1;
    await prefs.setInt(_eventBookIdCounterKey, current + 1);
    return current;
  }

  // Guest CRUD
  Future<int> insertGuest(Guest guest) async {
    final guests = await _loadGuests();
    final id = await _getNextGuestId();
    final newGuest = Guest(
      id: id,
      name: guest.name,
      relationship: guest.relationship,
      phone: guest.phone,
      note: guest.note,
    );
    guests.add(newGuest);
    await _saveGuests(guests);
    return id;
  }

  Future<List<Guest>> getAllGuests() async {
    final guests = await _loadGuests();
    guests.sort((a, b) => a.name.compareTo(b.name));
    return guests;
  }

  Future<Guest?> getGuestById(int id) async {
    final guests = await _loadGuests();
    try {
      return guests.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<Guest?> getGuestByName(String name) async {
    final guests = await _loadGuests();
    try {
      return guests.firstWhere((g) => g.name == name);
    } catch (_) {
      return null;
    }
  }

  Future<int> updateGuest(Guest guest) async {
    final guests = await _loadGuests();
    final index = guests.indexWhere((g) => g.id == guest.id);
    if (index != -1) {
      guests[index] = guest;
      await _saveGuests(guests);
      return 1;
    }
    return 0;
  }

  Future<int> deleteGuest(int id) async {
    final guests = await _loadGuests();
    final gifts = await _loadGifts();
    
    guests.removeWhere((g) => g.id == id);
    gifts.removeWhere((g) => g.guestId == id);
    
    await _saveGuests(guests);
    await _saveGifts(gifts);
    return 1;
  }

  Future<int> insertEventBook(EventBook eventBook) async {
    final eventBooks = await _loadEventBooks();
    final id = await _getNextEventBookId();
    final newEventBook = eventBook.copyWith(id: id);
    eventBooks.add(newEventBook);
    await _saveEventBooks(eventBooks);
    return id;
  }

  Future<List<EventBook>> getAllEventBooks() async {
    final eventBooks = await _loadEventBooks();
    eventBooks.sort((a, b) {
      final dateCompare = b.date.compareTo(a.date);
      if (dateCompare != 0) return dateCompare;
      return b.createdAt.compareTo(a.createdAt);
    });
    return eventBooks;
  }

  Future<EventBook?> getEventBookById(int id) async {
    final eventBooks = await _loadEventBooks();
    try {
      return eventBooks.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<int> updateEventBook(EventBook eventBook) async {
    final eventBooks = await _loadEventBooks();
    final index = eventBooks.indexWhere((b) => b.id == eventBook.id);
    if (index != -1) {
      eventBooks[index] = eventBook;
      await _saveEventBooks(eventBooks);
      return 1;
    }
    return 0;
  }

  Future<int> deleteEventBook(int id) async {
    final eventBooks = await _loadEventBooks();
    final gifts = await _loadGifts();
    eventBooks.removeWhere((b) => b.id == id);
    gifts.removeWhere((g) => g.eventBookId == id);
    await _saveEventBooks(eventBooks);
    await _saveGifts(gifts);
    return 1;
  }

  // Gift CRUD
  Future<int> insertGift(Gift gift) async {
    final gifts = await _loadGifts();
    final id = await _getNextGiftId();
    final newGift = Gift(
      id: id,
      guestId: gift.guestId,
      amount: gift.amount,
      isReceived: gift.isReceived,
      eventType: gift.eventType,
      eventBookId: gift.eventBookId,
      date: gift.date,
      note: gift.note,
      relatedRecordId: gift.relatedRecordId,
      isReturned: gift.isReturned,
      returnDueDate: gift.returnDueDate,
      remindedCount: gift.remindedCount,
    );
    gifts.add(newGift);
    await _saveGifts(gifts);
    return id;
  }

  Future<void> insertGiftsBatch(List<Gift> gifts) async {
    if (gifts.isEmpty) return;
    final storedGifts = await _loadGifts();
    final prefs = await _storage;
    int currentId = prefs.getInt(_giftIdCounterKey) ?? 1;
    for (final gift in gifts) {
      storedGifts.add(gift.copyWith(id: currentId));
      currentId += 1;
    }
    await prefs.setInt(_giftIdCounterKey, currentId);
    await _saveGifts(storedGifts);
  }

  Future<List<Gift>> getAllGifts() async {
    final gifts = await _loadGifts();
    gifts.sort((a, b) => b.date.compareTo(a.date));
    return gifts;
  }

  Future<List<Gift>> getGiftsByGuest(int guestId) async {
    final gifts = await _loadGifts();
    final filtered = gifts.where((g) => g.guestId == guestId).toList();
    filtered.sort((a, b) => b.date.compareTo(a.date));
    return filtered;
  }

  Future<List<Gift>> getGiftsByEventBook(int eventBookId) async {
    final gifts = await _loadGifts();
    final filtered = gifts.where((g) => g.eventBookId == eventBookId).toList();
    filtered.sort((a, b) => b.date.compareTo(a.date));
    return filtered;
  }

  Future<List<Gift>> getRecentGifts({int limit = 10}) async {
    final gifts = await _loadGifts();
    gifts.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
    return gifts.take(limit).toList();
  }

  Future<int> updateGift(Gift gift) async {
    final gifts = await _loadGifts();
    final index = gifts.indexWhere((g) => g.id == gift.id);
    if (index != -1) {
      gifts[index] = gift;
      await _saveGifts(gifts);
      return 1;
    }
    return 0;
  }

  Future<int> deleteGift(int id) async {
    final gifts = await _loadGifts();
    gifts.removeWhere((g) => g.id == id);
    await _saveGifts(gifts);
    return 1;
  }

  Future<double> getEventBookReceivedTotal(int eventBookId) async {
    final gifts = await _loadGifts();
    double total = 0;
    for (var gift in gifts.where((g) => g.isReceived && g.eventBookId == eventBookId)) {
      total += gift.amount;
    }
    return total;
  }

  Future<double> getEventBookSentTotal(int eventBookId) async {
    final gifts = await _loadGifts();
    double total = 0;
    for (var gift in gifts.where((g) => !g.isReceived && g.eventBookId == eventBookId)) {
      total += gift.amount;
    }
    return total;
  }

  Future<int> getEventBookGiftCount(int eventBookId) async {
    final gifts = await _loadGifts();
    return gifts.where((g) => g.eventBookId == eventBookId).length;
  }

  // 统计
  Future<double> getTotalReceived({bool includeEventBooks = true}) async {
    final gifts = await _loadGifts();
    double total = 0;
    for (var g in gifts.where((g) => g.isReceived && (includeEventBooks || g.eventBookId == null))) {
      total += g.amount;
    }
    return total;
  }

  Future<double> getTotalSent({bool includeEventBooks = true}) async {
    final gifts = await _loadGifts();
    double total = 0;
    for (var g in gifts.where((g) => !g.isReceived && (includeEventBooks || g.eventBookId == null))) {
      total += g.amount;
    }
    return total;
  }

  Future<Map<int, double>> getGuestReceivedTotals({bool includeEventBooks = true}) async {
    final gifts = await _loadGifts();
    final Map<int, double> totals = {};
    for (var gift in gifts.where((g) => g.isReceived && (includeEventBooks || g.eventBookId == null))) {
      totals[gift.guestId] = (totals[gift.guestId] ?? 0) + gift.amount;
    }
    return totals;
  }

  Future<Map<int, double>> getGuestSentTotals({bool includeEventBooks = true}) async {
    final gifts = await _loadGifts();
    final Map<int, double> totals = {};
    for (var gift in gifts.where((g) => !g.isReceived && (includeEventBooks || g.eventBookId == null))) {
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

  // 还礼追踪查询方法
  
  /// 获取未还清单：收礼且未还的记录
  Future<List<Gift>> getUnreturnedGifts({bool includeEventBooks = true}) async {
    final gifts = await _loadGifts();
    final filtered = gifts
        .where((g) => g.isReceived && !g.isReturned && (includeEventBooks || g.eventBookId == null))
        .toList();
    filtered.sort((a, b) => b.date.compareTo(a.date));
    return filtered;
  }

  /// 获取待收清单：送礼且未收的记录
  Future<List<Gift>> getPendingReceipts({bool includeEventBooks = true}) async {
    final gifts = await _loadGifts();
    final filtered = gifts
        .where((g) => !g.isReceived && !g.isReturned && (includeEventBooks || g.eventBookId == null))
        .toList();
    filtered.sort((a, b) => b.date.compareTo(a.date));
    return filtered;
  }

  /// 更新还礼状态
  Future<int> updateReturnStatus(int giftId, {required bool isReturned, int? relatedRecordId}) async {
    final gifts = await _loadGifts();
    final index = gifts.indexWhere((g) => g.id == giftId);
    if (index != -1) {
      gifts[index] = gifts[index].copyWith(
        isReturned: isReturned,
        relatedRecordId: relatedRecordId,
      );
      await _saveGifts(gifts);
      return 1;
    }
    return 0;
  }

  /// 增加提醒计数
  Future<int> incrementRemindedCount(int giftId) async {
    final gifts = await _loadGifts();
    final index = gifts.indexWhere((g) => g.id == giftId);
    if (index != -1) {
      gifts[index] = gifts[index].copyWith(
        remindedCount: gifts[index].remindedCount + 1,
      );
      await _saveGifts(gifts);
      return 1;
    }
    return 0;
  }

  /// 关联两条记录
  Future<void> linkGiftRecords(int giftId1, int giftId2) async {
    final gifts = await _loadGifts();
    final index1 = gifts.indexWhere((g) => g.id == giftId1);
    final index2 = gifts.indexWhere((g) => g.id == giftId2);
    if (index1 != -1 && index2 != -1) {
      gifts[index1] = gifts[index1].copyWith(relatedRecordId: giftId2, isReturned: true);
      gifts[index2] = gifts[index2].copyWith(relatedRecordId: giftId1, isReturned: true);
      await _saveGifts(gifts);
    }
  }

  /// 获取待处理记录数量
  Future<int> getPendingCount({bool includeEventBooks = true}) async {
    final gifts = await _loadGifts();
    return gifts.where((g) => !g.isReturned && (includeEventBooks || g.eventBookId == null)).length;
  }
}

final nativeDb = NativeDatabaseService();
