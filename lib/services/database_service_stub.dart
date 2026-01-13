import '../models/gift.dart';
import '../models/guest.dart';
import 'web_storage_service.dart';

/// Web 平台的存根实现 - 实际使用 web_storage_service
class NativeDatabaseService {
  Future<int> insertGuest(Guest guest) => webStorage.insertGuest(guest);
  Future<List<Guest>> getAllGuests() => webStorage.getAllGuests();
  Future<Guest?> getGuestById(int id) => webStorage.getGuestById(id);
  Future<Guest?> getGuestByName(String name) => webStorage.getGuestByName(name);
  Future<int> updateGuest(Guest guest) => webStorage.updateGuest(guest);
  Future<int> deleteGuest(int id) => webStorage.deleteGuest(id);
  Future<int> insertGift(Gift gift) => webStorage.insertGift(gift);
  Future<List<Gift>> getAllGifts() => webStorage.getAllGifts();
  Future<List<Gift>> getGiftsByGuest(int guestId) => webStorage.getGiftsByGuest(guestId);
  Future<List<Gift>> getRecentGifts({int limit = 10}) => webStorage.getRecentGifts(limit: limit);
  Future<int> updateGift(Gift gift) => webStorage.updateGift(gift);
  Future<int> deleteGift(int id) => webStorage.deleteGift(id);
  Future<double> getTotalReceived() => webStorage.getTotalReceived();
  Future<double> getTotalSent() => webStorage.getTotalSent();
  Future<Map<int, double>> getGuestReceivedTotals() => webStorage.getGuestReceivedTotals();
  Future<Map<int, double>> getGuestSentTotals() => webStorage.getGuestSentTotals();
}

final nativeDb = NativeDatabaseService();
