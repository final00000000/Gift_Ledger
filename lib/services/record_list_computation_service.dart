import '../models/gift.dart';
import '../models/guest.dart';

class RecordListSnapshot {
  const RecordListSnapshot({
    required this.allGifts,
    required this.filteredGifts,
    required this.guestMap,
    required this.filteredTotalAmount,
    required this.filteredCount,
  });

  final List<Gift> allGifts;
  final List<Gift> filteredGifts;
  final Map<int, Guest> guestMap;
  final double filteredTotalAmount;
  final int filteredCount;
}

class RecordListComputationService {
  const RecordListComputationService();

  RecordListSnapshot buildSnapshot({
    required List<Gift> gifts,
    required List<Guest> guests,
    required bool? isReceived,
    required String selectedCategory,
    required String searchQuery,
  }) {
    final guestMap = {for (final guest in guests) guest.id!: guest};
    final allGifts = (isReceived == null
            ? gifts
            : gifts.where((gift) => gift.isReceived == isReceived))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final normalizedQuery = searchQuery.trim().toLowerCase();
    final filteredGifts = allGifts.where((gift) {
      if (selectedCategory != 'all' && gift.eventType != selectedCategory) {
        return false;
      }

      if (normalizedQuery.isEmpty) {
        return true;
      }

      final guest = guestMap[gift.guestId];
      final nameMatch = guest?.name.toLowerCase().contains(normalizedQuery) ?? false;
      final noteMatch = gift.note?.toLowerCase().contains(normalizedQuery) ?? false;
      return nameMatch || noteMatch;
    }).toList(growable: false);

    final filteredTotalAmount = filteredGifts.fold<double>(
      0,
      (sum, gift) => sum + gift.amount,
    );

    return RecordListSnapshot(
      allGifts: allGifts,
      filteredGifts: filteredGifts,
      guestMap: guestMap,
      filteredTotalAmount: filteredTotalAmount,
      filteredCount: filteredGifts.length,
    );
  }
}
