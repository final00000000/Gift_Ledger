import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gift_ledger/models/gift.dart';
import 'package:gift_ledger/models/guest.dart';
import 'package:gift_ledger/widgets/records/record_summary_card.dart';

Gift fakeGift({String? note}) {
  return Gift(
    id: 1,
    guestId: 1,
    amount: 520,
    isReceived: true,
    eventType: EventTypes.wedding,
    date: DateTime(2026, 3, 24),
    note: note,
  );
}

Guest fakeGuest({String name = '王五'}) {
  return Guest(id: 1, name: name, relationship: '亲戚');
}

void main() {
  testWidgets('RecordSummaryCard 只展示单行备注并使用省略策略', (WidgetTester tester) async {
    const note = '这是一个很长很长的备注，用来验证记录列表只走单行展示';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordSummaryCard(
            gift: fakeGift(note: note),
            guest: fakeGuest(),
            solarDate: '03-24',
            lunarDate: '二月廿五',
            itemColor: Colors.red,
          ),
        ),
      ),
    );

    final text = tester.widget<Text>(find.text(note));
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
  });

  testWidgets('RecordSummaryCard 在窄宽度下会压缩姓名与日期而不产生溢出',
      (WidgetTester tester) async {
    const longName = '这是一个非常非常长的联系人姓名，用来验证记录卡片在窄屏下不会溢出';
    const dateLabel = '03-24 · 二月廿五是一个很长的农历描述';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            child: RecordSummaryCard(
              gift: fakeGift(note: '备注'),
              guest: fakeGuest(name: longName),
              solarDate: '03-24',
              lunarDate: '二月廿五是一个很长的农历描述',
              itemColor: Colors.red,
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
