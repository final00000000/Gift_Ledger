import 'package:flutter/material.dart';
import '../models/gift.dart';
import '../models/guest.dart';

class StatisticsSnapshot {
  const StatisticsSnapshot({
    required this.allGifts,
    required this.guestMap,
    required this.availableYears,
    required this.selectedYear,
    required this.yearFilteredGifts,
    required this.insights,
  });

  final List<Gift> allGifts;
  final Map<int, Guest> guestMap;
  final List<int> availableYears;
  final int? selectedYear;
  final List<Gift> yearFilteredGifts;
  final List<StatisticsInsight> insights;
}

class StatisticsInsight {
  const StatisticsInsight({
    required this.title,
    required this.value,
    required this.description,
    required this.icon,
  });

  final String title;
  final String value;
  final String description;
  final IconData icon;
}

class StatisticsComputationService {
  const StatisticsComputationService();

  StatisticsSnapshot buildSnapshot({
    required List<Gift> gifts,
    required List<Guest> guests,
    required int? selectedYear,
  }) {
    final guestMap = {for (final guest in guests) guest.id!: guest};
    final availableYears = gifts.map((gift) => gift.date.year).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    final resolvedYear = selectedYear != null && availableYears.contains(selectedYear)
        ? selectedYear
        : null;
    final yearFilteredGifts = resolvedYear == null
        ? gifts
        : gifts.where((gift) => gift.date.year == resolvedYear).toList();

    return StatisticsSnapshot(
      allGifts: gifts,
      guestMap: guestMap,
      availableYears: availableYears,
      selectedYear: resolvedYear,
      yearFilteredGifts: yearFilteredGifts,
      insights: _buildInsights(gifts, guestMap),
    );
  }

  List<StatisticsInsight> _buildInsights(
    List<Gift> allGifts,
    Map<int, Guest> guestMap,
  ) {
    if (allGifts.isEmpty) {
      return const [
        StatisticsInsight(
          title: '开始记录',
          value: '添加更多记录解锁洞察',
          description: '智能分析您的礼金往来',
          icon: Icons.auto_awesome,
        ),
      ];
    }

    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month, 1);
    final lastMonth = DateTime(now.year, now.month - 1, 1);
    final lastMonthEnd = thisMonth.subtract(const Duration(days: 1));

    double thisMonthReceived = 0;
    double lastMonthReceived = 0;
    final amountCount = <double, int>{};
    final contactCount = <int, int>{};

    for (final gift in allGifts) {
      if (gift.date.isAfter(thisMonth.subtract(const Duration(seconds: 1)))) {
        if (gift.isReceived) {
          thisMonthReceived += gift.amount;
        }
      } else if (gift.date.isAfter(lastMonth.subtract(const Duration(seconds: 1))) &&
          gift.date.isBefore(lastMonthEnd.add(const Duration(days: 1)))) {
        if (gift.isReceived) {
          lastMonthReceived += gift.amount;
        }
      }

      amountCount[gift.amount] = (amountCount[gift.amount] ?? 0) + 1;
      contactCount[gift.guestId] = (contactCount[gift.guestId] ?? 0) + 1;
    }

    double? receivedTrend;
    if (lastMonthReceived > 0) {
      receivedTrend = ((thisMonthReceived - lastMonthReceived) / lastMonthReceived) * 100;
    } else if (thisMonthReceived > 0) {
      receivedTrend = 100;
    }

    double? mostCommonAmount;
    if (amountCount.isNotEmpty) {
      var maxCount = 0;
      amountCount.forEach((amount, count) {
        if (count > maxCount) {
          maxCount = count;
          mostCommonAmount = amount;
        }
      });
    }

    String? mostFrequentContact;
    var mostFrequentContactCount = 0;
    if (contactCount.isNotEmpty) {
      int? mostFrequentId;
      contactCount.forEach((guestId, count) {
        if (count > mostFrequentContactCount) {
          mostFrequentContactCount = count;
          mostFrequentId = guestId;
        }
      });
      if (mostFrequentId != null && guestMap.containsKey(mostFrequentId)) {
        mostFrequentContact = guestMap[mostFrequentId]!.name;
      }
    }

    final insights = <StatisticsInsight>[];
    if (receivedTrend != null) {
      final isUp = receivedTrend >= 0;
      insights.add(
        StatisticsInsight(
          title: '本月收礼趋势',
          value: '${isUp ? '增长' : '下降'} ${receivedTrend.abs().toStringAsFixed(1)}%',
          description: '相比上月',
          icon: isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
        ),
      );
    }

    if (mostCommonAmount != null) {
      insights.add(
        StatisticsInsight(
          title: '最常见礼金金额',
          value: '¥${mostCommonAmount!.toStringAsFixed(0)}',
          description: '出现频率最高',
          icon: Icons.attach_money_rounded,
        ),
      );
    }

    if (mostFrequentContact != null) {
      insights.add(
        StatisticsInsight(
          title: '最常往来联系人',
          value: mostFrequentContact,
          description: '共 $mostFrequentContactCount 次往来',
          icon: Icons.person_rounded,
        ),
      );
    }

    if (insights.isEmpty) {
      insights.add(
        const StatisticsInsight(
          title: '开始记录',
          value: '添加更多记录解锁洞察',
          description: '智能分析您的礼金往来',
          icon: Icons.auto_awesome,
        ),
      );
    }

    return insights;
  }
}
