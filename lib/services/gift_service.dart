import '../models/gift.dart';
import '../models/guest.dart';
import 'database_service_native.dart' if (dart.library.js_interop) 'database_service_web_indexed.dart';

class GiftService {
  const GiftService();

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

  Future<void> saveGiftWithGuest(Gift gift, Guest guest) {
    return nativeDb.saveGiftWithGuest(gift, guest);
  }

  Future<Map<String, Guest>> insertGuestsAndBuildNameMap(
    List<Guest> guests,
  ) async {
    final guestMap = <String, Guest>{};
    for (final guest in guests) {
      final guestId = await nativeDb.insertGuest(guest);
      if (guestId > 0) {
        guestMap[guest.name] = guest.copyWith(id: guestId);
      }
    }
    return guestMap;
  }
}
