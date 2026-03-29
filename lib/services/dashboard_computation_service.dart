import '../models/gift.dart';
import '../models/guest.dart';

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.totalReceived,
    required this.totalSent,
    required this.recentGifts,
    required this.guestMap,
    required this.pendingCount,
    required this.eventBooksEnabled,
  });

  final double totalReceived;
  final double totalSent;
  final List<Gift> recentGifts;
  final Map<int, Guest> guestMap;
  final int pendingCount;
  final bool eventBooksEnabled;
}

class DashboardComputationService {
  const DashboardComputationService();

  DashboardSnapshot buildSnapshot({
    required double totalReceived,
    required double totalSent,
    required List<Gift> recentGifts,
    required List<Guest> guests,
    required int pendingCount,
    required bool eventBooksEnabled,
  }) {
    final guestMap = {for (final guest in guests) guest.id!: guest};
    return DashboardSnapshot(
      totalReceived: totalReceived,
      totalSent: totalSent,
      recentGifts: recentGifts.take(10).toList(growable: false),
      guestMap: guestMap,
      pendingCount: pendingCount,
      eventBooksEnabled: eventBooksEnabled,
    );
  }
}
