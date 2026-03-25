import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../utils/record_note_policy.dart';

class RecordNoteField extends StatelessWidget {
  static const fieldKey = ValueKey('record-note-field');
  static const int _warningThreshold = 100;

  const RecordNoteField({
    super.key,
    required this.controller,
    this.focusNode,
    this.onTap,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final VoidCallback? onTap;

  bool _isNearLimit(int count) {
    return count >= _warningThreshold && count <= kRecordNoteMaxLength;
  }

  String? _buildLimitHint(int count) {
    if (count > kRecordNoteMaxLength) {
      return '已超出 120 字，请先删减后再保存';
    }

    if (count == kRecordNoteMaxLength) {
      return '已达到 120 字上限';
    }

    if (_isNearLimit(count)) {
      return '还可输入 ${kRecordNoteMaxLength - count} 字';
    }

    return null;
  }

  Color _buildCounterColor(int count) {
    if (count > kRecordNoteMaxLength) {
      return Colors.redAccent;
    }

    if (_isNearLimit(count)) {
      return Colors.orangeAccent;
    }

    return AppTheme.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final note = value.text;
        final count = countRecordNoteCharacters(note);
        final limitHint = _buildLimitHint(count);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: fieldKey,
              controller: controller,
              focusNode: focusNode,
              onTap: onTap,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              minLines: 2,
              maxLines: 4,
              inputFormatters: const [
                LegacyAwareNoteLengthFormatter(),
              ],
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                hintText: '添加备注...',
                hintStyle: TextStyle(
                  color: AppTheme.textSecondary.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 28),
                  child: Icon(
                    Icons.edit_note_rounded,
                    color: AppTheme.primaryColor,
                  ),
                ),
                alignLabelWithHint: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '$count/$kRecordNoteMaxLength',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _buildCounterColor(count),
                ),
              ),
            ),
            if (limitHint != null) ...[
              const SizedBox(height: 4),
              Text(
                limitHint,
                style: TextStyle(
                  color: count > kRecordNoteMaxLength
                      ? Colors.redAccent
                      : Colors.orangeAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
