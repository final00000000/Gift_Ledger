import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CustomNumpad extends StatelessWidget {
  final Function(String) onDigitPressed;
  final VoidCallback onDelete;
  final VoidCallback? onDone;

  const CustomNumpad({
    super.key,
    required this.onDigitPressed,
    required this.onDelete,
    this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildRow(['1', '2', '3']),
          const SizedBox(height: AppTheme.spacingS),
          _buildRow(['4', '5', '6']),
          const SizedBox(height: AppTheme.spacingS),
          _buildRow(['7', '8', '9']),
          const SizedBox(height: AppTheme.spacingS),
          _buildBottomRow(),
        ],
      ),
    );
  }

  Widget _buildRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((digit) => _buildDigitButton(digit)).toList(),
    );
  }

  Widget _buildBottomRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildDigitButton('.'),
        _buildDigitButton('0'),
        _buildActionButton(
          icon: Icons.backspace_outlined,
          onPressed: onDelete,
          color: AppTheme.textSecondary,
        ),
      ],
    );
  }

  Widget _buildDigitButton(String digit) {
    return SizedBox(
      width: 80,
      height: 56,
      child: Material(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: InkWell(
          onTap: () => onDigitPressed(digit),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          child: Center(
            child: Text(
              digit,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return SizedBox(
      width: 80,
      height: 56,
      child: Material(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          child: Center(
            child: Icon(icon, color: color, size: 28),
          ),
        ),
      ),
    );
  }
}
