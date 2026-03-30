import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gift_ledger/models/update_target.dart';
import 'package:gift_ledger/widgets/update/update_channel_section.dart';

void main() {
  testWidgets('UpdateChannelSection 在 checking / installing 时禁用切换',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UpdateChannelSection(
            selectedChannel: UpdateChannel.stable,
            enabled: false,
            onBetaChanged: (_) {},
          ),
        ),
      ),
    );

    final switchWidget = tester.widget<Switch>(find.byType(Switch));
    expect(switchWidget.onChanged, isNull);
  });
}
