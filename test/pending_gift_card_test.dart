import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gift_ledger/models/gift.dart';
import 'package:gift_ledger/models/guest.dart';
import 'package:gift_ledger/widgets/records/pending_gift_card.dart';

Gift fakeGift({String? note}) {
  return Gift(
    id: 1,
    guestId: 1,
    amount: 888,
    isReceived: false,
    eventType: EventTypes.wedding,
    date: DateTime(2026, 3, 24),
    note: note,
  );
}

Guest fakeGuest({String name = '李四'}) {
  return Guest(id: 1, name: name, relationship: '朋友');
}

void main() {
  testWidgets('PendingGiftCard 会展示备注摘要，并锁定单行省略语义', (WidgetTester tester) async {
    const note = '待还列表也要展示备注';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PendingGiftCard(
            gift: fakeGift(note: note),
            guest: fakeGuest(),
            lunarDate: '二月廿五',
            daysText: '已过120天',
            statusColor: Colors.orange,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.notes_rounded), findsOneWidget);
    final noteText = tester.widget<Text>(find.text(note));
    expect(noteText.maxLines, 1);
    expect(noteText.overflow, TextOverflow.ellipsis);
  });

  testWidgets('PendingGiftCard 在窄屏下会压缩姓名与日期而不产生溢出',
      (WidgetTester tester) async {
    const longName = '待还联系人姓名特别长特别长，需要在卡片里做省略处理';
    const dateLabel = '03月24日 (二月廿五是一个很长的农历描述)';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            child: PendingGiftCard(
              gift: fakeGift(note: '备注'),
              guest: fakeGuest(name: longName),
              lunarDate: '二月廿五是一个很长的农历描述',
              daysText: '已过120天',
              statusColor: Colors.orange,
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);

    final nameText = tester.widget<Text>(find.text(longName));
    final dateText = tester.widget<Text>(find.text(dateLabel));
    expect(nameText.maxLines, 1);
    expect(nameText.overflow, TextOverflow.ellipsis);
    expect(dateText.maxLines, 1);
    expect(dateText.overflow, TextOverflow.ellipsis);
  });
}
