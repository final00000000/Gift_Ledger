import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gift_ledger/models/gift.dart';
import 'package:gift_ledger/models/guest.dart';
import 'package:gift_ledger/screens/pending_list_screen.dart';
import 'package:gift_ledger/widgets/records/pending_gift_card.dart';

class FakePendingListStorageService implements PendingListStorage {
  FakePendingListStorageService({
    required this.unreturnedGifts,
    required this.pendingReceipts,
    required this.guests,
  });

  final List<Gift> unreturnedGifts;
  final List<Gift> pendingReceipts;
  final List<Guest> guests;
  final List<VoidCallback> _listeners = [];

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  @override
  Future<List<Gift>> getUnreturnedGifts() async => unreturnedGifts;

  @override
  Future<List<Gift>> getPendingReceipts() async => pendingReceipts;

  @override
  Future<List<Guest>> getAllGuests() async => guests;

  @override
  Future<int> incrementRemindedCount(int giftId) async => 1;

  @override
  Future<int> updateReturnStatus(
    int giftId, {
    required bool isReturned,
    int? relatedRecordId,
  }) async => 1;
}

class DelayedPendingListStorageService extends FakePendingListStorageService {
  DelayedPendingListStorageService()
      : unreturnedCompleter = Completer<List<Gift>>(),
        pendingCompleter = Completer<List<Gift>>(),
        guestsCompleter = Completer<List<Guest>>(),
        super(
          unreturnedGifts: const <Gift>[],
          pendingReceipts: const <Gift>[],
          guests: const <Guest>[],
        );

  final Completer<List<Gift>> unreturnedCompleter;
  final Completer<List<Gift>> pendingCompleter;
  final Completer<List<Guest>> guestsCompleter;

  @override
  Future<List<Gift>> getUnreturnedGifts() => unreturnedCompleter.future;

  @override
  Future<List<Gift>> getPendingReceipts() => pendingCompleter.future;

  @override
  Future<List<Guest>> getAllGuests() => guestsCompleter.future;
}

void main() {
  testWidgets('PendingListScreen 会通过真实页面接线展示备注摘要', (WidgetTester tester) async {
    final storage = FakePendingListStorageService(
      unreturnedGifts: [
        Gift(
          id: 1,
          guestId: 1,
          amount: 666,
          isReceived: true,
          eventType: EventTypes.wedding,
          date: DateTime(2025, 12, 24),
          note: '待还页面的备注摘要',
        ),
      ],
      pendingReceipts: const [],
      guests: [
        Guest(id: 1, name: '赵六', relationship: '同事'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PendingListScreen(storageService: storage),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('待还页面的备注摘要'), findsOneWidget);
    expect(find.byType(PendingGiftCard), findsOneWidget);
  });

  testWidgets('PendingListScreen 在页面销毁后完成异步加载时，不应再触发 setState after dispose',
      (WidgetTester tester) async {
    final storage = DelayedPendingListStorageService();

    await tester.pumpWidget(
      MaterialApp(
        home: PendingListScreen(storageService: storage),
      ),
    );
    await tester.pump();

    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox.shrink(),
      ),
    );

    storage.unreturnedCompleter.complete(const <Gift>[]);
    storage.pendingCompleter.complete(const <Gift>[]);
    storage.guestsCompleter.complete(const <Guest>[]);

    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
