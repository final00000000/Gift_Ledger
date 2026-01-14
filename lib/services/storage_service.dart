// 条件导入 - Web平台使用 database_service_web.dart
import 'database_service_native.dart' if (dart.library.js_interop) 'database_service_web.dart';
import '../models/gift.dart';
import '../models/guest.dart';

/// 统一存储服务 - 跨平台支持 (Use SQLite for all platforms)
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

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

  // Gift CRUD
  Future<int> insertGift(Gift gift) {
    return nativeDb.insertGift(gift);
  }

  Future<List<Gift>> getAllGifts() {
    return nativeDb.getAllGifts();
  }

  Future<List<Gift>> getGiftsByGuest(int guestId) {
    return nativeDb.getGiftsByGuest(guestId);
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

  // 统计
  Future<double> getTotalReceived() {
    return nativeDb.getTotalReceived();
  }

  Future<double> getTotalSent() {
    return nativeDb.getTotalSent();
  }

  Future<Map<int, double>> getGuestReceivedTotals() {
    return nativeDb.getGuestReceivedTotals();
  }

  Future<Map<int, double>> getGuestSentTotals() {
    return nativeDb.getGuestSentTotals();
  }

  // Transactional or Combined operations
  Future<void> saveGiftWithGuest(Gift gift, Guest guest) async {
    return nativeDb.saveGiftWithGuest(gift, guest);
  }
}
