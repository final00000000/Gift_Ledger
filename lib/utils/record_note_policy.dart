import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const int kRecordNoteMaxLength = 120;

int countRecordNoteCharacters(String value) => value.characters.length;

bool isRecordNoteOverflow(String value) {
  return countRecordNoteCharacters(value) > kRecordNoteMaxLength;
}

String? validateRecordNoteForSave(String value) {
  if (isRecordNoteOverflow(value)) {
    return '备注最多 120 字，请先删减';
  }
  return null;
}

String? normalizeRecordNoteForSave(String value) {
  if (value.trim().isEmpty) {
    return null;
  }
  return value;
}

/// 允许 legacy 超长备注继续删减，但不允许再次增长。
class LegacyAwareNoteLengthFormatter extends TextInputFormatter {
  const LegacyAwareNoteLengthFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final oldCount = countRecordNoteCharacters(oldValue.text);
    final newCount = countRecordNoteCharacters(newValue.text);
    final isShrinking = newCount <= oldCount;

    if (newCount <= kRecordNoteMaxLength || isShrinking) {
      return newValue;
    }

    return oldValue;
  }
}
