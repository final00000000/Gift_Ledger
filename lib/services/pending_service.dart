import '../models/gift.dart';
import 'database_service_native.dart' if (dart.library.js_interop) 'database_service_web_indexed.dart';

class PendingService {
  const PendingService();

  Future<List<Gift>> getUnreturnedGifts({bool includeEventBooks = true}) {
    return nativeDb.getUnreturnedGifts(includeEventBooks: includeEventBooks);
  }

  Future<List<Gift>> getPendingReceipts({bool includeEventBooks = true}) {
    return nativeDb.getPendingReceipts(includeEventBooks: includeEventBooks);
  }

  Future<int> updateReturnStatus(
    int giftId, {
    required bool isReturned,
    int? relatedRecordId,
  }) {
    return nativeDb.updateReturnStatus(
      giftId,
      isReturned: isReturned,
      relatedRecordId: relatedRecordId,
    );
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
