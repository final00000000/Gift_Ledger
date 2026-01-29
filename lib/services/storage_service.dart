// 条件导入 - Web平台使用 database_service_web.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_service_native.dart' if (dart.library.js_interop) 'database_service_web.dart';
import '../models/event_book.dart';
import '../models/gift.dart';
import '../models/guest.dart';

/// 统一存储服务 - 跨平台支持 (Use SQLite for all platforms)
/// 继承 ChangeNotifier 以支持 Provider 状态管理
class StorageService extends ChangeNotifier {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _statsIncludeEventBooksKey = 'stats_include_event_books';
  static const String _eventBooksEnabledKey = 'event_books_enabled';
  static const String _showAmountsKey = 'show_home_amounts';

  /// 通知数据变更
  void _notifyDataChanged() {
    notifyListeners();
  }

  // Guest CRUD
  Future<int> insertGuest(Guest guest) async {
    final result = await nativeDb.insertGuest(guest);
    _notifyDataChanged();
    return result;
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

  Future<int> updateGuest(Guest guest) async {
    final result = await nativeDb.updateGuest(guest);
    _notifyDataChanged();
    return result;
  }

  Future<int> deleteGuest(int id) async {
    final result = await nativeDb.deleteGuest(id);
    _notifyDataChanged();
    return result;
  }

  Future<int> insertEventBook(EventBook eventBook) async {
    final result = await nativeDb.insertEventBook(eventBook);
    _notifyDataChanged();
    return result;
  }

  Future<List<EventBook>> getAllEventBooks() {
    return nativeDb.getAllEventBooks();
  }

  Future<EventBook?> getEventBookById(int id) {
    return nativeDb.getEventBookById(id);
  }

  Future<int> updateEventBook(EventBook eventBook) async {
    final result = await nativeDb.updateEventBook(eventBook);
    _notifyDataChanged();
    return result;
  }

  Future<int> deleteEventBook(int id) async {
    final result = await nativeDb.deleteEventBook(id);
    _notifyDataChanged();
    return result;
  }

  // Gift CRUD
  Future<int> insertGift(Gift gift) async {
    final result = await nativeDb.insertGift(gift);
    _notifyDataChanged();
    return result;
  }

  Future<void> insertGiftsBatch(List<Gift> gifts) async {
    await nativeDb.insertGiftsBatch(gifts);
    _notifyDataChanged();
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

  Future<int> updateGift(Gift gift) async {
    final result = await nativeDb.updateGift(gift);
    _notifyDataChanged();
    return result;
  }

  Future<int> deleteGift(int id) async {
    final result = await nativeDb.deleteGift(id);
    _notifyDataChanged();
    return result;
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
    _notifyDataChanged();
  }

  Future<bool> getEventBooksEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_eventBooksEnabledKey) ?? true;
  }

  Future<void> setEventBooksEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_eventBooksEnabledKey, value);
    _notifyDataChanged();
  }

  Future<bool> getShowHomeAmounts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showAmountsKey) ?? true;
  }

  Future<void> setShowHomeAmounts(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showAmountsKey, value);
    _notifyDataChanged();
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
    await nativeDb.saveGiftWithGuest(gift, guest);
    _notifyDataChanged();
  }

  // 还礼追踪方法
  Future<List<Gift>> getUnreturnedGifts({bool includeEventBooks = true}) {
    return nativeDb.getUnreturnedGifts(includeEventBooks: includeEventBooks);
  }

  Future<List<Gift>> getPendingReceipts({bool includeEventBooks = true}) {
    return nativeDb.getPendingReceipts(includeEventBooks: includeEventBooks);
  }

  Future<int> updateReturnStatus(int giftId, {required bool isReturned, int? relatedRecordId}) async {
    final result = await nativeDb.updateReturnStatus(giftId, isReturned: isReturned, relatedRecordId: relatedRecordId);
    _notifyDataChanged();
    return result;
  }

  Future<int> incrementRemindedCount(int giftId) async {
    final result = await nativeDb.incrementRemindedCount(giftId);
    _notifyDataChanged();
    return result;
  }

  Future<void> linkGiftRecords(int giftId1, int giftId2) async {
    await nativeDb.linkGiftRecords(giftId1, giftId2);
    _notifyDataChanged();
  }

  Future<int> getPendingCount({bool includeEventBooks = true}) {
    return nativeDb.getPendingCount(includeEventBooks: includeEventBooks);
  }
}
