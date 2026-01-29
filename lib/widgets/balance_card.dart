import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'privacy_aware_text.dart';

class BalanceCard extends StatelessWidget {
  final double totalReceived;
  final double totalSent;
  final VoidCallback? onReceivedTap;
  final VoidCallback? onSentTap;

  const BalanceCard({
    super.key,
    required this.totalReceived,
    required this.totalSent,
    this.onReceivedTap,
    this.onSentTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL, vertical: AppTheme.spacingS),
      child: Row(
        children: [
          // 收礼卡片
          Expanded(
            child: _buildSingleCard(
              context,
              title: '收礼总额',
              amount: totalReceived,
              icon: Icons.move_to_inbox_rounded,
              color: AppTheme.primaryColor,
              backgroundColor: const Color(0xFFFFF1F2), // Very Light Red
              onTap: onReceivedTap,
            ),
          ),
          const SizedBox(width: 16),
          // 送礼卡片
          Expanded(
            child: _buildSingleCard(
              context,
              title: '送礼总额',
              amount: totalSent,
              icon: Icons.outbox_rounded,
              color: AppTheme.accentColor,
              backgroundColor: const Color(0xFFFFFBEB), // Very Light Amber
              onTap: onSentTap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleCard(
    BuildContext context, {
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
    required Color backgroundColor,
    required VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        color: color,
                        size: 20,
                      ),
                    ),
                    if (onTap != null)
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: AppTheme.textSecondary.withOpacity(0.3),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.textSecondary.withOpacity(0.8),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                PrivacyAwareText(
                  '¥${_formatAmount(amount)}',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 1000000) {
       return '${(amount / 10000).toStringAsFixed(1)}w';
    }
    if (amount >= 10000) {
      return '${(amount / 10000).toStringAsFixed(2)}w';
    }
    return amount.toStringAsFixed(0);
  }
}
