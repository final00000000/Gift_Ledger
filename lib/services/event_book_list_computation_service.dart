import '../models/event_book.dart';

class EventBookListSnapshot {
  const EventBookListSnapshot({
    required this.eventBooks,
    required this.giftCounts,
  });

  final List<EventBook> eventBooks;
  final Map<int, int> giftCounts;
}

class EventBookListComputationService {
  const EventBookListComputationService();

  EventBookListSnapshot buildSnapshot({
    required List<EventBook> eventBooks,
    required Map<int, int> giftCounts,
  }) {
    return EventBookListSnapshot(
      eventBooks: eventBooks,
      giftCounts: giftCounts,
    );
  }
}
