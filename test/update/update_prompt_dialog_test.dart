import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gift_ledger/models/update_target.dart';
import 'package:gift_ledger/widgets/update/update_prompt_dialog.dart';

void main() {
  testWidgets('勾选不再提示后提交回调结果为 true', (tester) async {
    const target = UpdateTarget(
      channel: UpdateChannel.stable,
      platform: UpdatePlatform.android,
      version: '1.3.0',
      buildNumber: 13,
      notes: '修复若干问题并优化体验',
    );

    UpdatePromptDialogResult? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await showDialog<UpdatePromptDialogResult>(
                    context: context,
                    builder: (_) => const UpdatePromptDialog(target: target),
                  );
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('这个版本不再提示'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('稍后再说'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.ignoreCurrentVersion, isTrue);
    expect(result!.action, UpdatePromptDialogAction.later);
  });

  testWidgets('仅在弹窗真正显示后触发 onShown 回调', (tester) async {
    const target = UpdateTarget(
      channel: UpdateChannel.stable,
      platform: UpdatePlatform.android,
      version: '1.3.0',
      buildNumber: 13,
      notes: '修复若干问题并优化体验',
    );

    var shownCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (_) => UpdatePromptDialog(
                      target: target,
                      onShown: () {
                        shownCount += 1;
                      },
                    ),
                  );
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    );

    expect(shownCount, 0);

    await tester.tap(find.text('open'));
    expect(shownCount, 0);

    await tester.pumpAndSettle();

    expect(find.text('发现新版本'), findsOneWidget);
    expect(shownCount, 1);
  });
}
