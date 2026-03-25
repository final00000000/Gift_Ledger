import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gift_ledger/widgets/update/update_release_notes_section.dart';

void main() {
  testWidgets('UpdateReleaseNotesSection 在长文本时默认折叠 3 行，可展开再收起',
      (tester) async {
    const notes = '第一行\n第二行\n第三行\n第四行';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UpdateReleaseNotesSection(notes: notes),
        ),
      ),
    );

    expect(find.text('展开'), findsOneWidget);
    await tester.tap(find.text('展开'));
    await tester.pump();
    expect(find.text('收起'), findsOneWidget);
  });
}
