import 'package:flutter_test/flutter_test.dart';
import 'package:gift_ledger/utils/record_note_policy.dart';

void main() {
  test('历史超长备注进入编辑时会被识别为超限态，但不被静默截断', () {
    final legacy = List.filled(50, '旧备注').join();

    expect(isRecordNoteOverflow(legacy), isTrue);
    expect(countRecordNoteCharacters(legacy), greaterThan(120));
  });

  test('normalizeRecordNoteForSave 仅把纯空白折叠为 null，不静默 trim 非空备注', () {
    expect(normalizeRecordNoteForSave('   '), isNull);
    expect(normalizeRecordNoteForSave('  保留前后空格  '), '  保留前后空格  ');
  });

  test('历史超长备注只有删减到 120 字内后才允许保存', () {
    final legacy = List.filled(130, '旧').join();

    expect(validateRecordNoteForSave(legacy), '备注最多 120 字，请先删减');
    expect(validateRecordNoteForSave(legacy.substring(0, 120)), isNull);
  });

  test('emoji 按用户感知字符计数：120 个可保存，121 个会被拦截', () {
    final withinLimit = List.filled(120, '🎁').join();
    final overflow = List.filled(121, '🎁').join();

    expect(countRecordNoteCharacters(withinLimit), 120);
    expect(validateRecordNoteForSave(withinLimit), isNull);
    expect(countRecordNoteCharacters(overflow), 121);
    expect(validateRecordNoteForSave(overflow), '备注最多 120 字，请先删减');
  });

  test('LegacyAwareNoteLengthFormatter 允许超长旧备注继续删减，但阻止继续增长', () {
    const formatter = LegacyAwareNoteLengthFormatter();
    final tooLong130 = List.filled(130, 'a').join();
    final tooLong131 = List.filled(131, 'a').join();
    final tooLong129 = List.filled(129, 'a').join();

    final expanded = formatter.formatEditUpdate(
      TextEditingValue(text: tooLong130),
      TextEditingValue(text: tooLong131),
    );
    final shrinked = formatter.formatEditUpdate(
      TextEditingValue(text: tooLong130),
      TextEditingValue(text: tooLong129),
    );

    expect(expanded.text.length, 130);
    expect(shrinked.text.length, 129);
  });

  test('LegacyAwareNoteLengthFormatter 对 emoji 超长旧备注也只允许删减，不允许继续增长', () {
    const formatter = LegacyAwareNoteLengthFormatter();
    final tooLong120 = List.filled(120, '🎁').join();
    final tooLong121 = List.filled(121, '🎁').join();
    final tooLong122 = List.filled(122, '🎁').join();

    final expanded = formatter.formatEditUpdate(
      TextEditingValue(text: tooLong121),
      TextEditingValue(text: tooLong122),
    );
    final shrinked = formatter.formatEditUpdate(
      TextEditingValue(text: tooLong121),
      TextEditingValue(text: tooLong120),
    );

    expect(countRecordNoteCharacters(expanded.text), 121);
    expect(countRecordNoteCharacters(shrinked.text), 120);
  });
}
