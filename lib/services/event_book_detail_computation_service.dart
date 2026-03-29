import '../models/gift.dart';
import '../models/guest.dart';

class EventBookDetailSnapshot {
  const EventBookDetailSnapshot({
    required this.gifts,
    required this.guestMap,
    required this.totalReceived,
    required this.totalSent,
  });

  final List<Gift> gifts;
  final Map<int, Guest> guestMap;
  final double totalReceived;
  final double totalSent;
}

class EventBookDetailComputationService {
  const EventBookDetailComputationService();

  EventBookDetailSnapshot buildSnapshot({
    required List<Gift> gifts,
    required List<Guest> guests,
    required double totalReceived,
    required double totalSent,
  }) {
    final guestMap = {for (final guest in guests) guest.id!: guest};
    return EventBookDetailSnapshot(
      gifts: gifts,
      guestMap: guestMap,
      totalReceived: totalReceived,
      totalSent: totalSent,
    );
  }
}
