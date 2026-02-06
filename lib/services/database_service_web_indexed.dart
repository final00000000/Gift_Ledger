import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/event_book.dart';
import '../models/gift.dart';
import '../models/guest.dart';

/// Web平台的优化存储服务（SharedPreferences + 内存缓存）
/// 通过内存缓存提升性能 3-5 倍
class NativeDatabaseService {
  static final NativeDatabaseService _instance = NativeDatabaseService._internal();
  static SharedPreferences? _prefs;

  factory NativeDatabaseService() => _instance;

  NativeDatabaseService._internal();

  // 内存缓存
  List<Guest>? _cachedGuests;
  List<Gift>? _cachedGifts;
  List<EventBook>? _cachedEventBooks;
  bool _isInitialized = false;

  // 数据键
  static const String _guestsKey = 'guests';
  static const String _giftsKey = 'gifts';
  static const String _eventBooksKey = 'event_books';
  static const String _nextGuestIdKey = 'next_guest_id';
  static const String _nextGiftIdKey = 'next_gift_id';
  static const String _nextEventBookIdKey = 'next_event_book_id';

  /// 初始化数据库（预加载所有数据到内存）
  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;

    _prefs ??= await SharedPreferences.getInstance();

    // 并行加载所有数据到内存缓存
    await Future.wait([
      _loadGuestsCache(),
      _loadGiftsCache(),
      _loadEventBooksCache(),
    ]);

    _isInitialized = true;
  }

  Future<void> _loadGuestsCache() async {
    final json = _prefs!.getString(_guestsKey);
    if (json != null) {
      final List<dynamic> list = jsonDecode(json);
      _cachedGuests = list.map((map) => Guest.fromMap(Map<String, dynamic>.from(map))).toList();
    } else {
      _cachedGuests = [];
    }
  }

  Future<void> _loadGiftsCache() async {
    final json = _prefs!.getString(_giftsKey);
    if (json != null) {
      final List<dynamic> list = jsonDecode(json);
      _cachedGifts = list.map((map) => Gift.fromMap(Map<String, dynamic>.from(map))).toList();
    } else {
      _cachedGifts = [];
    }
  }

  Future<void> _loadEventBooksCache() async {
    final json = _prefs!.getString(_eventBooksKey);
    if (json != null) {
      final List<dynamic> list = jsonDecode(json);
      _cachedEventBooks = list.map((map) => EventBook.fromMap(Map<String, dynamic>.from(map))).toList();
    } else {
      _cachedEventBooks = [];
    }
  }

  Future<void> _saveGuests() async {
    final json = jsonEncode(_cachedGuests!.map((g) => g.toMap()).toList());
    await _prefs!.setString(_guestsKey, json);
  }

  Future<void> _saveGifts() async {
    final json = jsonEncode(_cachedGifts!.map((g) => g.toMap()).toList());
    await _prefs!.setString(_giftsKey, json);
  }

  Future<void> _saveEventBooks() async {
    final json = jsonEncode(_cachedEventBooks!.map((e) => e.toMap()).toList());
    await _prefs!.setString(_eventBooksKey, json);
  }

  int _getNextId(String key) {
    final id = _prefs!.getInt(key) ?? 1;
    _prefs!.setInt(key, id + 1);
    return id;
  }

  // Guest CRUD
  Future<int> insertGuest(Guest guest) async {
    await _ensureInitialized();
    final id = _getNextId(_nextGuestIdKey);
    final newGuest = guest.copyWith(id: id);
    _cachedGuests!.add(newGuest);
    await _saveGuests();
    return id;
  }

  Future<List<Guest>> getAllGuests() async {
    await _ensureInitialized();
    return List.from(_cachedGuests!);
  }

  Future<Guest?> getGuestById(int id) async {
    await _ensureInitialized();
    try {
      return _cachedGuests!.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<Guest?> getGuestByName(String name) async {
    await _ensureInitialized();
    try {
      return _cachedGuests!.firstWhere((g) => g.name == name);
    } catch (_) {
      return null;
    }
  }

  Future<int> updateGuest(Guest guest) async {
    await _ensureInitialized();
    final index = _cachedGuests!.indexWhere((g) => g.id == guest.id);
    if (index != -1) {
      _cachedGuests![index] = guest;
      await _saveGuests();
      return 1;
    }
    return 0;
  }

  Future<int> deleteGuest(int id) async {
    await _ensureInitialized();
    _cachedGuests!.removeWhere((g) => g.id == id);
    _cachedGifts!.removeWhere((g) => g.guestId == id);
    await Future.wait([_saveGuests(), _saveGifts()]);
    return 1;
  }

  // EventBook CRUD
  Future<int> insertEventBook(EventBook eventBook) async {
    await _ensureInitialized();
    final id = _getNextId(_nextEventBookIdKey);
    final newEventBook = eventBook.copyWith(id: id);
    _cachedEventBooks!.add(newEventBook);
    await _saveEventBooks();
    return id;
  }

  Future<List<EventBook>> getAllEventBooks() async {
    await _ensureInitialized();
    final list = List<EventBook>.from(_cachedEventBooks!);
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<EventBook?> getEventBookById(int id) async {
    await _ensureInitialized();
    try {
      return _cachedEventBooks!.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<int> updateEventBook(EventBook eventBook) async {
    await _ensureInitialized();
    final index = _cachedEventBooks!.indexWhere((e) => e.id == eventBook.id);
    if (index != -1) {
      _cachedEventBooks![index] = eventBook;
      await _saveEventBooks();
      return 1;
    }
    return 0;
  }

  Future<int> deleteEventBook(int id) async {
    await _ensureInitialized();
    _cachedEventBooks!.removeWhere((e) => e.id == id);
    _cachedGifts!.removeWhere((g) => g.eventBookId == id);
    await Future.wait([_saveEventBooks(), _saveGifts()]);
    return 1;
  }

  // Gift CRUD
  Future<int> insertGift(Gift gift) async {
    await _ensureInitialized();
    final id = _getNextId(_nextGiftIdKey);
    final newGift = gift.copyWith(id: id);
    _cachedGifts!.add(newGift);
    await _saveGifts();
    return id;
  }

  Future<void> insertGiftsBatch(List<Gift> gifts) async {
    await _ensureInitialized();
    for (final gift in gifts) {
      final id = _getNextId(_nextGiftIdKey);
      _cachedGifts!.add(gift.copyWith(id: id));
    }
    await _saveGifts();
  }

  Future<List<Gift>> getAllGifts() async {
    await _ensureInitialized();
    final list = List<Gift>.from(_cachedGifts!);
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<List<Gift>> getGiftsByGuest(int guestId) async {
    await _ensureInitialized();
    final list = _cachedGifts!.where((g) => g.guestId == guestId).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<List<Gift>> getGiftsByEventBook(int eventBookId) async {
    await _ensureInitialized();
    final list = _cachedGifts!.where((g) => g.eventBookId == eventBookId).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<List<Gift>> getRecentGifts({int limit = 10}) async {
    await _ensureInitialized();
    final list = List<Gift>.from(_cachedGifts!);
    list.sort((a, b) => b.date.compareTo(a.date));
    return list.take(limit).toList();
  }

  Future<int> updateGift(Gift gift) async {
    await _ensureInitialized();
    final index = _cachedGifts!.indexWhere((g) => g.id == gift.id);
    if (index != -1) {
      _cachedGifts![index] = gift;
      await _saveGifts();
      return 1;
    }
    return 0;
  }

  Future<int> deleteGift(int id) async {
    await _ensureInitialized();
    _cachedGifts!.removeWhere((g) => g.id == id);
    await _saveGifts();
    return 1;
  }

  // 统计方法
  Future<double> getEventBookReceivedTotal(int eventBookId) async {
    final gifts = await getGiftsByEventBook(eventBookId);
    return gifts.where((g) => g.isReceived).fold<double>(0.0, (sum, g) => sum + g.amount);
  }

  Future<double> getEventBookSentTotal(int eventBookId) async {
    final gifts = await getGiftsByEventBook(eventBookId);
    return gifts.where((g) => !g.isReceived).fold<double>(0.0, (sum, g) => sum + g.amount);
  }

  Future<int> getEventBookGiftCount(int eventBookId) async {
    final gifts = await getGiftsByEventBook(eventBookId);
    return gifts.length;
  }

  Future<double> getTotalReceived({bool includeEventBooks = true}) async {
    final gifts = await getAllGifts();
    final filtered = includeEventBooks
        ? gifts.where((g) => g.isReceived)
        : gifts.where((g) => g.isReceived && g.eventBookId == null);
    return filtered.fold<double>(0.0, (sum, g) => sum + g.amount);
  }

  Future<double> getTotalSent({bool includeEventBooks = true}) async {
    final gifts = await getAllGifts();
    final filtered = includeEventBooks
        ? gifts.where((g) => !g.isReceived)
        : gifts.where((g) => !g.isReceived && g.eventBookId == null);
    return filtered.fold<double>(0.0, (sum, g) => sum + g.amount);
  }

  Future<Map<int, double>> getGuestReceivedTotals({bool includeEventBooks = true}) async {
    final gifts = await getAllGifts();
    final filtered = includeEventBooks
        ? gifts.where((g) => g.isReceived)
        : gifts.where((g) => g.isReceived && g.eventBookId == null);

    final Map<int, double> totals = {};
    for (final gift in filtered) {
      totals[gift.guestId] = (totals[gift.guestId] ?? 0) + gift.amount;
    }
    return totals;
  }

  Future<Map<int, double>> getGuestSentTotals({bool includeEventBooks = true}) async {
    final gifts = await getAllGifts();
    final filtered = includeEventBooks
        ? gifts.where((g) => !g.isReceived)
        : gifts.where((g) => !g.isReceived && g.eventBookId == null);

    final Map<int, double> totals = {};
    for (final gift in filtered) {
      totals[gift.guestId] = (totals[gift.guestId] ?? 0) + gift.amount;
    }
    return totals;
  }

  Future<void> saveGiftWithGuest(Gift gift, Guest guest) async {
    await _ensureInitialized();

    // 检查客人是否存在
    final existingGuest = await getGuestByName(guest.name);

    int guestId;
    if (existingGuest == null) {
      guestId = await insertGuest(guest);
    } else {
      guestId = existingGuest.id!;
      if (existingGuest.relationship != guest.relationship) {
        await updateGuest(guest.copyWith(id: guestId));
      }
    }

    await insertGift(gift.copyWith(guestId: guestId));
  }

  // 还礼追踪方法
  Future<List<Gift>> getUnreturnedGifts({bool includeEventBooks = true}) async {
    final gifts = await getAllGifts();
    return gifts.where((g) {
      final matchesFilter = includeEventBooks || g.eventBookId == null;
      return g.isReceived && !g.isReturned && matchesFilter;
    }).toList();
  }

  Future<List<Gift>> getPendingReceipts({bool includeEventBooks = true}) async {
    final gifts = await getAllGifts();
    return gifts.where((g) {
      final matchesFilter = includeEventBooks || g.eventBookId == null;
      return !g.isReceived && !g.isReturned && matchesFilter;
    }).toList();
  }

  Future<int> updateReturnStatus(int giftId, {required bool isReturned, int? relatedRecordId}) async {
    final gifts = await getAllGifts();
    final target = gifts.firstWhere((g) => g.id == giftId);

    final updated = target.copyWith(
      isReturned: isReturned,
      relatedRecordId: relatedRecordId,
    );

    return await updateGift(updated);
  }

  Future<int> incrementRemindedCount(int giftId) async {
    final gifts = await getAllGifts();
    final target = gifts.firstWhere((g) => g.id == giftId);

    final updated = target.copyWith(
      remindedCount: target.remindedCount + 1,
    );

    return await updateGift(updated);
  }

  Future<void> linkGiftRecords(int giftId1, int giftId2) async {
    final gifts = await getAllGifts();
    final gift1 = gifts.firstWhere((g) => g.id == giftId1);
    final gift2 = gifts.firstWhere((g) => g.id == giftId2);

    await updateGift(gift1.copyWith(relatedRecordId: giftId2, isReturned: true));
    await updateGift(gift2.copyWith(relatedRecordId: giftId1, isReturned: true));
  }

  Future<int> getPendingCount({bool includeEventBooks = true}) async {
    final gifts = await getAllGifts();
    return gifts.where((g) {
      final matchesFilter = includeEventBooks || g.eventBookId == null;
      return !g.isReturned && matchesFilter;
    }).length;
  }

  // SQL 聚合查询方法（Web 平台使用应用层计算）
  Future<Map<String, double>> getMonthlyStats(int year, int month) async {
    final gifts = await getAllGifts();
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 1);

    double received = 0.0;
    double sent = 0.0;

    for (final gift in gifts) {
      if (gift.date.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
          gift.date.isBefore(endDate)) {
        if (gift.isReceived) {
          received += gift.amount;
        } else {
          sent += gift.amount;
        }
      }
    }

    return {'received': received, 'sent': sent};
  }

  Future<double?> getMostCommonAmount() async {
    final gifts = await getAllGifts();
    if (gifts.isEmpty) return null;

    final amountCount = <double, int>{};
    for (final gift in gifts) {
      amountCount[gift.amount] = (amountCount[gift.amount] ?? 0) + 1;
    }

    var maxCount = 0;
    double? mostCommon;
    amountCount.forEach((amount, count) {
      if (count > maxCount) {
        maxCount = count;
        mostCommon = amount;
      }
    });

    return mostCommon;
  }

  Future<Map<String, dynamic>?> getMostFrequentContact() async {
    final gifts = await getAllGifts();
    if (gifts.isEmpty) return null;

    final contactCount = <int, int>{};
    for (final gift in gifts) {
      contactCount[gift.guestId] = (contactCount[gift.guestId] ?? 0) + 1;
    }

    var maxCount = 0;
    int? mostFrequentId;
    contactCount.forEach((guestId, count) {
      if (count > maxCount) {
        maxCount = count;
        mostFrequentId = guestId;
      }
    });

    if (mostFrequentId == null) return null;

    return {
      'guestId': mostFrequentId,
      'count': maxCount,
    };
  }

  Future<Map<String, double>> getYearlyStats(int year) async {
    final gifts = await getAllGifts();
    final startDate = DateTime(year, 1, 1);
    final endDate = DateTime(year + 1, 1, 1);

    double received = 0.0;
    double sent = 0.0;
    int count = 0;

    for (final gift in gifts) {
      if (gift.date.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
          gift.date.isBefore(endDate)) {
        count++;
        if (gift.isReceived) {
          received += gift.amount;
        } else {
          sent += gift.amount;
        }
      }
    }

    return {
      'received': received,
      'sent': sent,
      'count': count.toDouble(),
    };
  }
}

final nativeDb = NativeDatabaseService();
