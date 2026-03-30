import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gift_ledger/widgets/gift_note_preview.dart';

void main() {
  testWidgets('GiftNotePreview 默认按单行省略展示备注', (WidgetTester tester) async {
    const note = '需要展示在外层列表的备注';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GiftNotePreview(
            note: note,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.notes_rounded), findsOneWidget);
    final noteText = tester.widget<Text>(find.text(note));
    expect(noteText.maxLines, 1);
    expect(noteText.overflow, TextOverflow.ellipsis);
  });

  testWidgets('GiftNotePreview 无备注时不占位', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GiftNotePreview(
            note: '   ',
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.notes_rounded), findsNothing);
    expect(find.text('   '), findsNothing);
  });
}
