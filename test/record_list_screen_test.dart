import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gift_ledger/models/gift.dart';
import 'package:gift_ledger/models/guest.dart';
import 'package:gift_ledger/screens/record_list_screen.dart';
import 'package:gift_ledger/widgets/records/record_summary_card.dart';

class FakeRecordListStorageService {
  FakeRecordListStorageService({
    required this.gifts,
    required this.guests,
  });

  final List<Gift> gifts;
  final List<Guest> guests;
  final List<VoidCallback> _listeners = [];

  void addListener(VoidCallback listener) => _listeners.add(listener);

  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  Future<List<Gift>> getAllGifts() async => gifts;

  Future<List<Guest>> getAllGuests() async => guests;
}

void main() {
  testWidgets('RecordListScreen 会通过真实页面接线展示备注摘要', (WidgetTester tester) async {
    final storage = FakeRecordListStorageService(
      gifts: [
        Gift(
          id: 1,
          guestId: 1,
          amount: 300,
          isReceived: true,
          eventType: EventTypes.wedding,
          date: DateTime(2026, 3, 24),
          note: '全部记录页的备注摘要',
        ),
      ],
      guests: [
        Guest(id: 1, name: '张三', relationship: '朋友'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RecordListScreen(storageService: storage),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(find.text('全部记录页的备注摘要'), findsOneWidget);
    expect(find.byType(RecordSummaryCard), findsOneWidget);
  });
}
