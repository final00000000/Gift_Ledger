import '../models/gift.dart';
import '../models/guest.dart';

class AddRecordMatchResult {
  const AddRecordMatchResult({
    required this.guestId,
    required this.matchedGift,
  });

  final int guestId;
  final Gift matchedGift;
}

class AddRecordAssistService {
  const AddRecordAssistService();

  List<Guest> filterGuests(
    List<Guest> guests,
    String query, {
    int limit = 5,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return const [];
    }

    return guests
        .where((guest) => guest.name.toLowerCase().contains(normalizedQuery))
        .take(limit)
        .toList(growable: false);
  }

  AddRecordMatchResult? findMatchingGift({
    required String guestName,
    required String eventType,
    required List<Gift> pendingGifts,
    required List<Guest> guests,
  }) {
    final matchedGuest = guests.where((guest) => guest.name == guestName).toList();
    if (matchedGuest.isEmpty) {
      return null;
    }

    final guestId = matchedGuest.first.id;
    if (guestId == null) {
      return null;
    }

    final matchedGifts = pendingGifts.where((gift) {
      return gift.guestId == guestId &&
          gift.eventType == eventType &&
          gift.relatedRecordId == null;
    }).toList(growable: false);

    if (matchedGifts.isEmpty) {
      return null;
    }

    return AddRecordMatchResult(
      guestId: guestId,
      matchedGift: matchedGifts.first,
    );
  }
}
