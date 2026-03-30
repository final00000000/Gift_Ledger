import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 统一的备注预览组件
///
/// 设计原则：
/// 1. 列表中只展示单行/少量行摘要，避免撑坏卡片高度
/// 2. 使用弱化视觉层级，确保姓名、事由、金额仍是主信息
/// 3. 超长文本统一省略，点击卡片后在详情页查看完整内容
class GiftNotePreview extends StatelessWidget {
  final String? note;
  final int maxLines;
  final double fontSize;
  final double iconSize;
  final double topSpacing;
  final EdgeInsetsGeometry? padding;

  const GiftNotePreview({
    super.key,
    required this.note,
    this.maxLines = 1,
    this.fontSize = 11,
    this.iconSize = 14,
    this.topSpacing = 6,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedNote = note?.trim();
    if (normalizedNote == null || normalizedNote.isEmpty) {
      return const SizedBox.shrink();
    }

    final preview = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.notes_rounded,
          size: iconSize,
          color: AppTheme.textSecondary.withValues(alpha: 0.55),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            normalizedNote,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: fontSize,
              color: AppTheme.textSecondary.withValues(alpha: 0.72),
              height: 1.25,
            ),
          ),
        ),
      ],
    );

    return Padding(
      padding: padding ?? EdgeInsets.only(top: topSpacing),
      child: Tooltip(
        message: normalizedNote,
        waitDuration: const Duration(milliseconds: 500),
        child: preview,
      ),
    );
  }
}
