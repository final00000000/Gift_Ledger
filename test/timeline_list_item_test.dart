import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gift_ledger/models/gift.dart';
import 'package:gift_ledger/models/guest.dart';
import 'package:gift_ledger/widgets/timeline_list_item.dart';

void main() {
  testWidgets('TimelineListItem 会以单行省略方式展示备注摘要', (WidgetTester tester) async {
    const note = '这是首页需要展示的备注内容';
    final gift = Gift(
      id: 1,
      guestId: 1,
      amount: 200,
      isReceived: true,
      eventType: '婚礼',
      date: DateTime(2026, 3, 23),
      note: note,
    );

    final guest = Guest(
      id: 1,
      name: '张三',
      relationship: '朋友',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimelineListItem(
            gift: gift,
            guest: guest,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byIcon(Icons.notes_rounded), findsOneWidget);
    final noteText = tester.widget<Text>(find.text(note));
    expect(noteText.maxLines, 1);
    expect(noteText.overflow, TextOverflow.ellipsis);
  });

  testWidgets('TimelineListItem 在没有备注时不展示备注区域', (WidgetTester tester) async {
    final gift = Gift(
      id: 2,
      guestId: 1,
      amount: 300,
      isReceived: false,
      eventType: '生日',
      date: DateTime(2026, 3, 23),
    );

    final guest = Guest(
      id: 1,
      name: '李四',
      relationship: '同事',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimelineListItem(
            gift: gift,
            guest: guest,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byIcon(Icons.notes_rounded), findsNothing);
  });
}
