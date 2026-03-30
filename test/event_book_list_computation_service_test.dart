import 'package:flutter_test/flutter_test.dart';
import 'package:gift_ledger/models/event_book.dart';
import 'package:gift_ledger/services/event_book_list_computation_service.dart';

void main() {
  const service = EventBookListComputationService();

  group('EventBookListComputationService.buildSnapshot', () {
    test('空数据正常工作', () {
      final snapshot = service.buildSnapshot(
        eventBooks: [],
        giftCounts: {},
      );

      expect(snapshot.eventBooks, isEmpty);
      expect(snapshot.giftCounts, isEmpty);
    });

    test('传递 eventBooks 和 giftCounts', () {
      final books = [
        EventBook(
          id: 1,
          name: '婚礼',
          type: '婚礼',
          date: DateTime(2025, 1, 1),
        ),
        EventBook(
          id: 2,
          name: '寿宴',
          type: '寿宴',
          date: DateTime(2025, 6, 1),
        ),
      ];
      final counts = {1: 10, 2: 5};

      final snapshot = service.buildSnapshot(
        eventBooks: books,
        giftCounts: counts,
      );

      expect(snapshot.eventBooks, hasLength(2));
      expect(snapshot.eventBooks.first.name, '婚礼');
      expect(snapshot.giftCounts[1], 10);
      expect(snapshot.giftCounts[2], 5);
    });

    test('giftCounts 中不存在的 id 返回 null', () {
      final books = [
        EventBook(
          id: 1,
          name: '婚礼',
          type: '婚礼',
          date: DateTime(2025, 1, 1),
        ),
      ];

      final snapshot = service.buildSnapshot(
        eventBooks: books,
        giftCounts: {},
      );

      expect(snapshot.giftCounts[1], isNull);
    });
  });
}
