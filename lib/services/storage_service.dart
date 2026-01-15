// 条件导入 - Web平台使用 database_service_web.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'database_service_native.dart' if (dart.library.js_interop) 'database_service_web.dart';
import '../models/event_book.dart';
import '../models/gift.dart';
import '../models/guest.dart';

/// 统一存储服务 - 跨平台支持 (Use SQLite for all platforms)
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _statsIncludeEventBooksKey = 'stats_include_event_books';

  // Guest CRUD
  Future<int> insertGuest(Guest guest) {
    return nativeDb.insertGuest(guest);
  }

  Future<List<Guest>> getAllGuests() {
    return nativeDb.getAllGuests();
  }

  Future<Guest?> getGuestById(int id) {
    return nativeDb.getGuestById(id);
  }

  Future<Guest?> getGuestByName(String name) {
    return nativeDb.getGuestByName(name);
  }

  Future<int> updateGuest(Guest guest) {
    return nativeDb.updateGuest(guest);
  }

  Future<int> deleteGuest(int id) {
    return nativeDb.deleteGuest(id);
  }

  Future<int> insertEventBook(EventBook eventBook) {
    return nativeDb.insertEventBook(eventBook);
  }

  Future<List<EventBook>> getAllEventBooks() {
    return nativeDb.getAllEventBooks();
  }

  Future<EventBook?> getEventBookById(int id) {
    return nativeDb.getEventBookById(id);
  }

  Future<int> updateEventBook(EventBook eventBook) {
    return nativeDb.updateEventBook(eventBook);
  }

  Future<int> deleteEventBook(int id) {
    return nativeDb.deleteEventBook(id);
  }

  // Gift CRUD
  Future<int> insertGift(Gift gift) {
    return nativeDb.insertGift(gift);
  }

  Future<void> insertGiftsBatch(List<Gift> gifts) {
    return nativeDb.insertGiftsBatch(gifts);
  }

  Future<List<Gift>> getAllGifts() {
    return nativeDb.getAllGifts();
  }

  Future<List<Gift>> getGiftsByGuest(int guestId) {
    return nativeDb.getGiftsByGuest(guestId);
  }

  Future<List<Gift>> getGiftsByEventBook(int eventBookId) {
    return nativeDb.getGiftsByEventBook(eventBookId);
  }

  Future<List<Gift>> getRecentGifts({int limit = 10}) {
    return nativeDb.getRecentGifts(limit: limit);
  }

  Future<int> updateGift(Gift gift) {
    return nativeDb.updateGift(gift);
  }

  Future<int> deleteGift(int id) {
    return nativeDb.deleteGift(id);
  }

  Future<double> getEventBookReceivedTotal(int eventBookId) {
    return nativeDb.getEventBookReceivedTotal(eventBookId);
  }

  Future<double> getEventBookSentTotal(int eventBookId) {
    return nativeDb.getEventBookSentTotal(eventBookId);
  }

  Future<int> getEventBookGiftCount(int eventBookId) {
    return nativeDb.getEventBookGiftCount(eventBookId);
  }

  Future<bool> getStatsIncludeEventBooks() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_statsIncludeEventBooksKey) ?? true;
  }

  Future<void> setStatsIncludeEventBooks(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_statsIncludeEventBooksKey, value);
  }

  // 统计
  Future<double> getTotalReceived({bool includeEventBooks = true}) {
    return nativeDb.getTotalReceived(includeEventBooks: includeEventBooks);
  }

  Future<double> getTotalSent({bool includeEventBooks = true}) {
    return nativeDb.getTotalSent(includeEventBooks: includeEventBooks);
  }

  Future<Map<int, double>> getGuestReceivedTotals({bool includeEventBooks = true}) {
    return nativeDb.getGuestReceivedTotals(includeEventBooks: includeEventBooks);
  }

  Future<Map<int, double>> getGuestSentTotals({bool includeEventBooks = true}) {
    return nativeDb.getGuestSentTotals(includeEventBooks: includeEventBooks);
  }

  // Transactional or Combined operations
  Future<void> saveGiftWithGuest(Gift gift, Guest guest) async {
    return nativeDb.saveGiftWithGuest(gift, guest);
  }

  // 还礼追踪方法
  Future<List<Gift>> getUnreturnedGifts({bool includeEventBooks = true}) {
    return nativeDb.getUnreturnedGifts(includeEventBooks: includeEventBooks);
  }

  Future<List<Gift>> getPendingReceipts({bool includeEventBooks = true}) {
    return nativeDb.getPendingReceipts(includeEventBooks: includeEventBooks);
  }

  Future<int> updateReturnStatus(int giftId, {required bool isReturned, int? relatedRecordId}) {
    return nativeDb.updateReturnStatus(giftId, isReturned: isReturned, relatedRecordId: relatedRecordId);
  }

  Future<int> incrementRemindedCount(int giftId) {
    return nativeDb.incrementRemindedCount(giftId);
  }

  Future<void> linkGiftRecords(int giftId1, int giftId2) {
    return nativeDb.linkGiftRecords(giftId1, giftId2);
  }

  Future<int> getPendingCount({bool includeEventBooks = true}) {
    return nativeDb.getPendingCount(includeEventBooks: includeEventBooks);
  }
}
