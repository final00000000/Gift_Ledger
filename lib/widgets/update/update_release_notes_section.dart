import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class UpdateReleaseNotesSection extends StatefulWidget {
  const UpdateReleaseNotesSection({
    super.key,
    required this.notes,
  });

  final String notes;

  @override
  State<UpdateReleaseNotesSection> createState() =>
      _UpdateReleaseNotesSectionState();
}

class _UpdateReleaseNotesSectionState extends State<UpdateReleaseNotesSection> {
  bool _expanded = false;

  bool get _canExpand {
    final normalized = widget.notes.trim();
    if (normalized.isEmpty) {
      return false;
    }

    return normalized.split('\n').length > 3 || normalized.length > 90;
  }

  @override
  Widget build(BuildContext context) {
    final normalizedNotes = widget.notes.trim();
    if (normalizedNotes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '更新说明',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            normalizedNotes,
            maxLines: _expanded || !_canExpand ? null : 3,
            overflow: _expanded || !_canExpand ? TextOverflow.visible : TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              height: 1.6,
              color: AppTheme.textSecondary,
            ),
          ),
          if (_canExpand) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  _expanded = !_expanded;
                });
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(_expanded ? '收起' : '展开'),
            ),
          ],
        ],
      ),
    );
  }
}
