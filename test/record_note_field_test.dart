import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gift_ledger/widgets/add_record/record_note_field.dart';

void main() {
  testWidgets('RecordNoteField 会展示实时计数，并在超限初始值时进入警示态',
      (WidgetTester tester) async {
    final controller = TextEditingController(
      text: List.filled(50, '旧备注').join(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordNoteField(controller: controller),
        ),
      ),
    );

    expect(find.textContaining('/120'), findsOneWidget);
    expect(find.text('已超出 120 字，请先删减后再保存'), findsOneWidget);
  });

  testWidgets('RecordNoteField 支持多行输入并使用换行键', (WidgetTester tester) async {
    final controller = TextEditingController(text: '第一行\n第二行');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordNoteField(controller: controller),
        ),
      ),
    );

    final textField = tester.widget<TextField>(
      find.byKey(RecordNoteField.fieldKey),
    );

    expect(textField.keyboardType, TextInputType.multiline);
    expect(textField.textInputAction, TextInputAction.newline);
    expect(textField.minLines, 2);
    expect(textField.maxLines, 4);
  });

  testWidgets('RecordNoteField 接近与达到上限时会展示提示文案', (WidgetTester tester) async {
    final controller =
        TextEditingController(text: List.filled(100, '字').join());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordNoteField(controller: controller),
        ),
      ),
    );

    expect(find.text('还可输入 20 字'), findsOneWidget);

    controller.text = List.filled(120, '字').join();
    await tester.pump();

    expect(find.text('已达到 120 字上限'), findsOneWidget);
    expect(find.text('已超出 120 字，请先删减后再保存'), findsNothing);
  });

  testWidgets('RecordNoteField 会随着 controller 变化实时刷新计数',
      (WidgetTester tester) async {
    final controller = TextEditingController(text: '旧备注');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordNoteField(controller: controller),
        ),
      ),
    );

    controller.text = '新的备注内容';
    await tester.pump();

    expect(find.text('6/120'), findsOneWidget);
    expect(find.text('已超出 120 字，请先删减后再保存'), findsNothing);
  });
}
