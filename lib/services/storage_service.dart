// 条件导入 - Web平台使用 IndexedDB 实现
import 'package:flutter/foundation.dart';
import '../models/event_book.dart';
import '../models/gift.dart';
import '../models/guest.dart';
import 'app_settings_service.dart';
import 'event_book_service.dart';
import 'gift_service.dart';
import 'guest_service.dart';
import 'pending_service.dart';
import 'stats_service.dart';

/// 统一存储服务 - 跨平台支持
/// Native: SQLite, Web: IndexedDB
/// 继承 ChangeNotifier 以支持 Provider 状态管理
class StorageService extends ChangeNotifier {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final _settingsService = AppSettingsService();
  final _eventBookService = const EventBookService();
  final _giftService = const GiftService();
  final _guestService = const GuestService();
  final _pendingService = const PendingService();
  final _statsService = const StatsService();

  // 防抖通知：避免短时间内多次通知
  bool _isNotifying = false;



  /// 通知数据变更（带防抖）
  void _notifyDataChanged() {
    if (_isNotifying) return;
    _isNotifying = true;

    // 使用 microtask 合并多个连续的通知
    Future.microtask(() {
      if (_isNotifying) {
        notifyListeners();
        _isNotifying = false;
      }
    });
  }

  // Guest CRUD
  Future<int> insertGuest(Guest guest) async {
    final result = await _guestService.insertGuest(guest);
    _notifyDataChanged();
    return result;
  }

  Future<List<Guest>> getAllGuests() {
    return _guestService.getAllGuests();
  }

  Future<Guest?> getGuestById(int id) {
    return _guestService.getGuestById(id);
  }

  Future<Guest?> getGuestByName(String name) {
    return _guestService.getGuestByName(name);
  }

  Future<int> updateGuest(Guest guest) async {
    final result = await _guestService.updateGuest(guest);
    _notifyDataChanged();
    return result;
  }

  Future<int> deleteGuest(int id) async {
    final result = await _guestService.deleteGuest(id);
    _notifyDataChanged();
    return result;
  }

  Future<int> insertEventBook(EventBook eventBook) async {
    final result = await _eventBookService.insertEventBook(eventBook);
    _notifyDataChanged();
    return result;
  }

  Future<List<EventBook>> getAllEventBooks() {
    return _eventBookService.getAllEventBooks();
  }

  Future<EventBook?> getEventBookById(int id) {
    return _eventBookService.getEventBookById(id);
  }

  Future<int> updateEventBook(EventBook eventBook) async {
    final result = await _eventBookService.updateEventBook(eventBook);
    _notifyDataChanged();
    return result;
  }

  Future<int> deleteEventBook(int id) async {
    final result = await _eventBookService.deleteEventBook(id);
    _notifyDataChanged();
    return result;
  }

  // Gift CRUD
  Future<int> insertGift(Gift gift) async {
    final result = await _giftService.insertGift(gift);
    _notifyDataChanged();
    return result;
  }

  Future<void> insertGiftsBatch(List<Gift> gifts) async {
    await _giftService.insertGiftsBatch(gifts);
    _notifyDataChanged();
  }

  Future<List<Gift>> getAllGifts() {
    return _giftService.getAllGifts();
  }

  Future<List<Gift>> getGiftsByGuest(int guestId) {
    return _giftService.getGiftsByGuest(guestId);
  }

  Future<List<Gift>> getGiftsByEventBook(int eventBookId) {
    return _giftService.getGiftsByEventBook(eventBookId);
  }

  Future<List<Gift>> getRecentGifts({int limit = 10}) {
    return _giftService.getRecentGifts(limit: limit);
  }

  Future<int> updateGift(Gift gift) async {
    final result = await _giftService.updateGift(gift);
    _notifyDataChanged();
    return result;
  }

  Future<int> deleteGift(int id) async {
    final result = await _giftService.deleteGift(id);
    _notifyDataChanged();
    return result;
  }

  Future<double> getEventBookReceivedTotal(int eventBookId) {
    return _eventBookService.getEventBookReceivedTotal(eventBookId);
  }

  Future<double> getEventBookSentTotal(int eventBookId) {
    return _eventBookService.getEventBookSentTotal(eventBookId);
  }

  Future<int> getEventBookGiftCount(int eventBookId) {
    return _eventBookService.getEventBookGiftCount(eventBookId);
  }

  Future<Map<int, int>> getEventBookGiftCounts(List<int> eventBookIds) {
    return _eventBookService.getEventBookGiftCounts(eventBookIds);
  }

  Future<bool> getStatsIncludeEventBooks() async {
    return _settingsService.getStatsIncludeEventBooks();
  }

  Future<void> setStatsIncludeEventBooks(bool value) async {
    await _settingsService.setStatsIncludeEventBooks(value);
    _notifyDataChanged();
  }

  Future<bool> getEventBooksEnabled() async {
    return _settingsService.getEventBooksEnabled();
  }

  Future<void> setEventBooksEnabled(bool value) async {
    await _settingsService.setEventBooksEnabled(value);
    _notifyDataChanged();
  }

  Future<bool> getShowHomeAmounts() async {
    return _settingsService.getShowHomeAmounts();
  }

  Future<void> setShowHomeAmounts(bool value) async {
    await _settingsService.setShowHomeAmounts(value);
    _notifyDataChanged();
  }

  // 统计
  Future<double> getTotalReceived({bool includeEventBooks = true}) {
    return _statsService.getTotalReceived(includeEventBooks: includeEventBooks);
  }

  Future<double> getTotalSent({bool includeEventBooks = true}) {
    return _statsService.getTotalSent(includeEventBooks: includeEventBooks);
  }

  Future<Map<int, double>> getGuestReceivedTotals({bool includeEventBooks = true}) {
    return _statsService.getGuestReceivedTotals(includeEventBooks: includeEventBooks);
  }

  Future<Map<int, double>> getGuestSentTotals({bool includeEventBooks = true}) {
    return _statsService.getGuestSentTotals(includeEventBooks: includeEventBooks);
  }

  // Transactional or Combined operations
  Future<void> saveGiftWithGuest(Gift gift, Guest guest) async {
    await _giftService.saveGiftWithGuest(gift, guest);
    _notifyDataChanged();
  }

  Future<Map<String, Guest>> insertGuestsAndBuildNameMap(List<Guest> guests) {
    return _giftService.insertGuestsAndBuildNameMap(guests);
  }

  // 还礼追踪方法
  Future<List<Gift>> getUnreturnedGifts({bool includeEventBooks = true}) {
    return _pendingService.getUnreturnedGifts(includeEventBooks: includeEventBooks);
  }

  Future<List<Gift>> getPendingReceipts({bool includeEventBooks = true}) {
    return _pendingService.getPendingReceipts(includeEventBooks: includeEventBooks);
  }

  Future<int> updateReturnStatus(int giftId, {required bool isReturned, int? relatedRecordId}) async {
    final result = await _pendingService.updateReturnStatus(
      giftId,
      isReturned: isReturned,
      relatedRecordId: relatedRecordId,
    );
    _notifyDataChanged();
    return result;
  }

  Future<int> incrementRemindedCount(int giftId) async {
    final result = await _pendingService.incrementRemindedCount(giftId);
    _notifyDataChanged();
    return result;
  }

  Future<void> linkGiftRecords(int giftId1, int giftId2) async {
    await _pendingService.linkGiftRecords(giftId1, giftId2);
    _notifyDataChanged();
  }

  Future<int> getPendingCount({bool includeEventBooks = true}) {
    return _pendingService.getPendingCount(includeEventBooks: includeEventBooks);
  }

  /// 数据库预热：预加载常用数据到内存，提升首次访问速度
  /// 在应用启动后台调用，不阻塞 UI
  Future<void> warmup() async {
    try {
      // 并行预加载常用数据
      await Future.wait([
        getAllGuests(),           // 预加载所有宾客（通常数量不多）
        getRecentGifts(limit: 20), // 预加载最近20条记录
        getStatsIncludeEventBooks(), // 预加载配置
        getEventBooksEnabled(),
      ]);

      debugPrint('✅ 数据库预热完成');
    } catch (e) {
      debugPrint('⚠️ 数据库预热失败: $e');
    }
  }

  // ==================== SQL 聚合查询（统计页面性能优化）====================

  /// 按月份统计收礼/送礼总额（SQL 聚合，性能提升 5-10 倍）
  Future<Map<String, double>> getMonthlyStats(int year, int month) {
    return _statsService.getMonthlyStats(year, month);
  }

  /// 获取最常见的金额（SQL 聚合）
  Future<double?> getMostCommonAmount() {
    return _statsService.getMostCommonAmount();
  }

  /// 获取最频繁的联系人（SQL 聚合）
  Future<Map<String, dynamic>?> getMostFrequentContact() {
    return _statsService.getMostFrequentContact();
  }

  /// 按年份统计（SQL 聚合）
  Future<Map<String, double>> getYearlyStats(int year) {
    return _statsService.getYearlyStats(year);
  }

  Future<bool> getDefaultIsReceived() => _settingsService.getDefaultIsReceived();

  Future<void> setDefaultIsReceived(bool value) => _settingsService.setDefaultIsReceived(value);
}
