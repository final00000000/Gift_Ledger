import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gift_ledger/models/gift.dart';
import 'package:gift_ledger/models/guest.dart';
import 'package:gift_ledger/widgets/gift_list_item.dart';

void main() {
  testWidgets('GiftListItem 会以单行省略方式展示备注摘要', (WidgetTester tester) async {
    const note = '活动簿中的备注摘要需要展示出来';
    final gift = Gift(
      id: 1,
      guestId: 1,
      amount: 520,
      isReceived: true,
      eventType: '婚礼',
      date: DateTime(2026, 3, 23),
      note: note,
    );

    final guest = Guest(
      id: 1,
      name: '王五',
      relationship: '亲戚',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GiftListItem(
            gift: gift,
            guest: guest,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.notes_rounded), findsOneWidget);
    final noteText = tester.widget<Text>(find.text(note));
    expect(noteText.maxLines, 1);
    expect(noteText.overflow, TextOverflow.ellipsis);
  });

  testWidgets('GiftListItem 在 320 宽窄屏下遇到长姓名和长事由时不再发生溢出',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final gift = Gift(
      id: 2,
      guestId: 1,
      amount: 1314,
      isReceived: true,
      eventType: '这是一个非常非常长的事由标签用于验证窄屏省略策略',
      date: DateTime(2026, 3, 23),
      note: '窄屏下备注也需要稳定展示',
    );

    final guest = Guest(
      id: 1,
      name: '这是一个非常非常长的联系人姓名用于验证窄屏不会再发生横向溢出',
      relationship: '亲戚',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: GiftListItem(
              gift: gift,
              guest: guest,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    final nameText = tester.widget<Text>(find.text(guest.name));
    final eventTypeText = tester.widget<Text>(find.text(gift.eventType));
    expect(nameText.maxLines, 1);
    expect(nameText.overflow, TextOverflow.ellipsis);
    expect(eventTypeText.maxLines, 1);
    expect(eventTypeText.overflow, TextOverflow.ellipsis);
  });
}
