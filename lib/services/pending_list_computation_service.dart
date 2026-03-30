import '../models/gift.dart';
import '../models/guest.dart';

class PendingListSnapshot {
  const PendingListSnapshot({
    required this.unreturnedGifts,
    required this.pendingReceipts,
    required this.guestMap,
  });

  final List<Gift> unreturnedGifts;
  final List<Gift> pendingReceipts;
  final Map<int, Guest> guestMap;
}

class PendingListComputationService {
  const PendingListComputationService();

  PendingListSnapshot buildSnapshot({
    required List<Gift> unreturnedGifts,
    required List<Gift> pendingReceipts,
    required List<Guest> guests,
    required String sortBy,
    required bool sortAscending,
  }) {
    final guestMap = {for (final guest in guests) guest.id!: guest};

    return PendingListSnapshot(
      unreturnedGifts: _sortGiftList(
        unreturnedGifts,
        guestMap: guestMap,
        sortBy: sortBy,
        sortAscending: sortAscending,
      ),
      pendingReceipts: _sortGiftList(
        pendingReceipts,
        guestMap: guestMap,
        sortBy: sortBy,
        sortAscending: sortAscending,
      ),
      guestMap: guestMap,
    );
  }

  List<Gift> _sortGiftList(
    List<Gift> gifts, {
    required Map<int, Guest> guestMap,
    required String sortBy,
    required bool sortAscending,
  }) {
    final sorted = List<Gift>.from(gifts);
    sorted.sort((a, b) {
      int result;
      switch (sortBy) {
        case 'amount':
          result = a.amount.compareTo(b.amount);
          break;
        case 'relationship':
          final guestA = guestMap[a.guestId];
          final guestB = guestMap[b.guestId];
          result = (guestA?.relationship ?? '').compareTo(guestB?.relationship ?? '');
          break;
        case 'days':
        default:
          result = a.date.compareTo(b.date);
          break;
      }
      return sortAscending ? result : -result;
    });
    return sorted;
  }
}
