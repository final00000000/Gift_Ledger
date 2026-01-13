import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/gift.dart';
import '../models/guest.dart';
import 'web_storage_service.dart';

// 条件导入 - 仅在非 Web 平台导入 sqflite
import 'database_service_native.dart' if (dart.library.html) 'database_service_stub.dart';

/// 统一存储服务 - 根据平台自动选择存储方式
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  // Guest CRUD
  Future<int> insertGuest(Guest guest) {
    if (kIsWeb) return webStorage.insertGuest(guest);
    return nativeDb.insertGuest(guest);
  }

  Future<List<Guest>> getAllGuests() {
    if (kIsWeb) return webStorage.getAllGuests();
    return nativeDb.getAllGuests();
  }

  Future<Guest?> getGuestById(int id) {
    if (kIsWeb) return webStorage.getGuestById(id);
    return nativeDb.getGuestById(id);
  }

  Future<Guest?> getGuestByName(String name) {
    if (kIsWeb) return webStorage.getGuestByName(name);
    return nativeDb.getGuestByName(name);
  }

  Future<int> updateGuest(Guest guest) {
    if (kIsWeb) return webStorage.updateGuest(guest);
    return nativeDb.updateGuest(guest);
  }

  Future<int> deleteGuest(int id) {
    if (kIsWeb) return webStorage.deleteGuest(id);
    return nativeDb.deleteGuest(id);
  }

  // Gift CRUD
  Future<int> insertGift(Gift gift) {
    if (kIsWeb) return webStorage.insertGift(gift);
    return nativeDb.insertGift(gift);
  }

  Future<List<Gift>> getAllGifts() {
    if (kIsWeb) return webStorage.getAllGifts();
    return nativeDb.getAllGifts();
  }

  Future<List<Gift>> getGiftsByGuest(int guestId) {
    if (kIsWeb) return webStorage.getGiftsByGuest(guestId);
    return nativeDb.getGiftsByGuest(guestId);
  }

  Future<List<Gift>> getRecentGifts({int limit = 10}) {
    if (kIsWeb) return webStorage.getRecentGifts(limit: limit);
    return nativeDb.getRecentGifts(limit: limit);
  }

  Future<int> updateGift(Gift gift) {
    if (kIsWeb) return webStorage.updateGift(gift);
    return nativeDb.updateGift(gift);
  }

  Future<int> deleteGift(int id) {
    if (kIsWeb) return webStorage.deleteGift(id);
    return nativeDb.deleteGift(id);
  }

  // 统计
  Future<double> getTotalReceived() {
    if (kIsWeb) return webStorage.getTotalReceived();
    return nativeDb.getTotalReceived();
  }

  Future<double> getTotalSent() {
    if (kIsWeb) return webStorage.getTotalSent();
    return nativeDb.getTotalSent();
  }

  Future<Map<int, double>> getGuestReceivedTotals() {
    if (kIsWeb) return webStorage.getGuestReceivedTotals();
    return nativeDb.getGuestReceivedTotals();
  }

  Future<Map<int, double>> getGuestSentTotals() {
    if (kIsWeb) return webStorage.getGuestSentTotals();
    return nativeDb.getGuestSentTotals();
  }

  // Transactional or Combined operations
  Future<void> saveGiftWithGuest(Gift gift, Guest guest) async {
    if (kIsWeb) return webStorage.saveGiftWithGuest(gift, guest);
    return nativeDb.saveGiftWithGuest(gift, guest);
  }
}
