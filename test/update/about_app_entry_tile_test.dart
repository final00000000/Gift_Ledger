import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gift_ledger/widgets/update/about_app_entry_tile.dart';

void main() {
  testWidgets('AboutAppEntryTile 在有更新时展示红点、版本信息和发现新版本胶囊',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AboutAppEntryTile(
            currentVersion: '1.2.8',
            showRedDot: true,
            showUpdateChip: true,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('关于随礼记'), findsOneWidget);
    expect(find.text('当前版本 v1.2.8'), findsOneWidget);
    expect(find.text('发现新版本'), findsOneWidget);
    expect(find.byKey(const ValueKey('about-app-red-dot')), findsOneWidget);
  });
}
