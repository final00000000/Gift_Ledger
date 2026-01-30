import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 智能洞察数据模型
class InsightData {
  final String title;
  final String value;
  final String description;
  final IconData icon;

  const InsightData({
    required this.title,
    required this.value,
    required this.description,
    required this.icon,
  });
}

/// 简约风格智能洞察卡片
class InsightCard extends StatefulWidget {
  final List<InsightData> insights;
  final Duration animationDelay;

  const InsightCard({
    super.key,
    required this.insights,
    this.animationDelay = Duration.zero,
  });

  @override
  State<InsightCard> createState() => _InsightCardState();
}

class _InsightCardState extends State<InsightCard> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.insights.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              itemCount: widget.insights.length,
              itemBuilder: (context, index) {
                return _buildInsightPage(widget.insights[index]);
              },
            ),
          ),
          // 页面指示器
          if (widget.insights.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.insights.length,
                  (index) => _buildDot(index),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInsightPage(InsightData insight) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          // 图标
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              insight.icon,
              color: AppTheme.primaryColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          // 内容
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            color: AppTheme.primaryColor,
                            size: 10,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '洞察',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        insight.title,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  insight.value,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    final isActive = index == _currentPage;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 3),
      width: isActive ? 14 : 6,
      height: 6,
      decoration: BoxDecoration(
        color: isActive ? AppTheme.primaryColor : AppTheme.primaryColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
