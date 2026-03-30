import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gift_ledger/models/gift.dart';
import 'package:gift_ledger/models/guest.dart';
import 'package:gift_ledger/services/statistics_computation_service.dart';

void main() {
  const service = StatisticsComputationService();

  group('StatisticsComputationService.buildSnapshot', () {
    test('空数据返回默认洞察', () {
      final snapshot = service.buildSnapshot(
        gifts: [],
        guests: [],
        selectedYear: null,
      );

      expect(snapshot.allGifts, isEmpty);
      expect(snapshot.guestMap, isEmpty);
      expect(snapshot.availableYears, isEmpty);
      expect(snapshot.selectedYear, isNull);
      expect(snapshot.yearFilteredGifts, isEmpty);
      expect(snapshot.insights, hasLength(1));
      expect(snapshot.insights.first.title, '开始记录');
    });

    test('正确构建 guestMap', () {
      final guests = [
        Guest(id: 1, name: '张三', relationship: '朋友'),
        Guest(id: 2, name: '李四', relationship: '同事'),
      ];
      final snapshot = service.buildSnapshot(
        gifts: [],
        guests: guests,
        selectedYear: null,
      );

      expect(snapshot.guestMap[1]!.name, '张三');
      expect(snapshot.guestMap[2]!.name, '李四');
    });

    test('availableYears 降序排列', () {
      final gifts = [
        Gift(id: 1, guestId: 1, amount: 100, isReceived: true, eventType: '婚礼', date: DateTime(2023, 1, 1)),
        Gift(id: 2, guestId: 1, amount: 200, isReceived: true, eventType: '婚礼', date: DateTime(2025, 1, 1)),
        Gift(id: 3, guestId: 1, amount: 300, isReceived: true, eventType: '婚礼', date: DateTime(2024, 1, 1)),
      ];
      final snapshot = service.buildSnapshot(
        gifts: gifts,
        guests: [],
        selectedYear: null,
      );

      expect(snapshot.availableYears, [2025, 2024, 2023]);
    });

    test('selectedYear 过滤生效', () {
      final gifts = [
        Gift(id: 1, guestId: 1, amount: 100, isReceived: true, eventType: '婚礼', date: DateTime(2023, 6, 1)),
        Gift(id: 2, guestId: 1, amount: 200, isReceived: true, eventType: '婚礼', date: DateTime(2024, 6, 1)),
      ];
      final snapshot = service.buildSnapshot(
        gifts: gifts,
        guests: [],
        selectedYear: 2023,
      );

      expect(snapshot.selectedYear, 2023);
      expect(snapshot.yearFilteredGifts, hasLength(1));
      expect(snapshot.yearFilteredGifts.first.amount, 100);
    });

    test('不存在的 selectedYear 回退为 null', () {
      final gifts = [
        Gift(id: 1, guestId: 1, amount: 100, isReceived: true, eventType: '婚礼', date: DateTime(2023, 6, 1)),
      ];
      final snapshot = service.buildSnapshot(
        gifts: gifts,
        guests: [],
        selectedYear: 2099,
      );

      expect(snapshot.selectedYear, isNull);
      expect(snapshot.yearFilteredGifts, hasLength(1));
    });
  });

  group('StatisticsInsight.icon', () {
    test('icon 字段返回正确 IconData', () {
      const insight = StatisticsInsight(
        title: '测试',
        value: '100',
        description: '描述',
        icon: Icons.auto_awesome,
      );

      expect(insight.icon, isA<IconData>());
      expect(insight.icon, Icons.auto_awesome);
    });

    test('icon 字段保留 MaterialIcons 字体族', () {
      const insight = StatisticsInsight(
        title: '测试',
        value: '100',
        description: '描述',
        icon: Icons.auto_awesome,
      );

      expect(insight.icon.fontFamily, 'MaterialIcons');
    });
  });
}
