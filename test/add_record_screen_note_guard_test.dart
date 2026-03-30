import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gift_ledger/models/gift.dart';
import 'package:gift_ledger/models/guest.dart';
import 'package:gift_ledger/screens/add_record_screen.dart';
import 'package:gift_ledger/widgets/add_record/record_note_field.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecordingStorageService implements AddRecordStorage {
  Gift? lastUpdatedGift;
  Guest? lastUpdatedGuest;
  Gift? lastCreatedGift;
  Guest? lastCreatedGuest;

  @override
  Future<List<Guest>> getAllGuests() async => [];

  @override
  Future<int> updateGift(Gift gift) async {
    lastUpdatedGift = gift;
    return 1;
  }

  @override
  Future<int> updateGuest(Guest guest) async {
    lastUpdatedGuest = guest;
    return 1;
  }

  @override
  Future<void> saveGiftWithGuest(Gift gift, Guest guest) async {
    lastCreatedGift = gift;
    lastCreatedGuest = guest;
  }

  @override
  Future<int> updateReturnStatus(
    int giftId, {
    required bool isReturned,
    int? relatedRecordId,
  }) async {
    return 1;
  }

  @override
  Future<List<Gift>> getUnreturnedGifts() async => [];

  @override
  Future<List<Gift>> getPendingReceipts() async => [];
}

Gift fakeGift({String? note}) {
  return Gift(
    id: 1,
    guestId: 1,
    amount: 200,
    isReceived: true,
    eventType: EventTypes.wedding,
    date: DateTime(2026, 3, 24),
    note: note,
  );
}

Guest fakeGuest() {
  return Guest(
    id: 1,
    name: '张三',
    relationship: RelationshipTypes.friend,
  );
}

Widget buildTestApp({required Widget child}) {
  return MaterialApp(home: child);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final noteFieldFinder = find.byKey(RecordNoteField.fieldKey);

  setUpAll(() async {
    await initializeDateFormatting('zh_CN');
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('AddRecordScreen 编辑 legacy 超长备注时：原文可见、超限时禁止保存、删减后允许保存',
      (WidgetTester tester) async {
    final legacyNote = List.filled(130, '旧').join();
    final fakeDb = RecordingStorageService();

    await tester.pumpWidget(
      buildTestApp(
        child: AddRecordScreen(
          editingGift: fakeGift(note: legacyNote),
          editingGuest: fakeGuest(),
          storageService: fakeDb,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('/120'), findsOneWidget);
    expect(find.text('已超出 120 字，请先删减后再保存'), findsOneWidget);
    expect(find.textContaining(legacyNote.substring(0, 20)), findsWidgets);

    await tester.tap(find.text('保存记录'));
    await tester.pump();

    expect(find.text('备注最多 120 字，请先删减'), findsOneWidget);
    expect(fakeDb.lastUpdatedGift, isNull);
    await tester.pump(const Duration(seconds: 2));

    final withinLimitNote = List.filled(120, '旧').join();
    await tester.enterText(noteFieldFinder, withinLimitNote);
    await tester.pump();

    await tester.tap(find.text('保存记录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认写入'));
    await tester.pumpAndSettle();

    expect(find.text('备注最多 120 字，请先删减'), findsNothing);
    expect(fakeDb.lastUpdatedGift?.note, withinLimitNote);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('AddRecordScreen 保存非空备注时不静默 trim', (WidgetTester tester) async {
    final fakeDb = RecordingStorageService();

    await tester.pumpWidget(
      buildTestApp(
        child: AddRecordScreen(
          editingGift: fakeGift(note: '原备注'),
          editingGuest: fakeGuest(),
          storageService: fakeDb,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(noteFieldFinder, '  保留前后空格  ');
    await tester.pump();

    await tester.tap(find.text('保存记录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认写入'));
    await tester.pumpAndSettle();

    expect(fakeDb.lastUpdatedGift?.note, '  保留前后空格  ');
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('AddRecordScreen 纯空白备注在确认弹窗中不展示备注行，最终保存为 null',
      (WidgetTester tester) async {
    final fakeDb = RecordingStorageService();

    await tester.pumpWidget(
      buildTestApp(
        child: AddRecordScreen(
          editingGift: fakeGift(note: '原备注'),
          editingGuest: fakeGuest(),
          storageService: fakeDb,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(noteFieldFinder, '   ');
    await tester.pump();

    await tester.tap(find.text('保存记录'));
    await tester.pumpAndSettle();

    expect(find.text('备注'), findsNothing);

    await tester.tap(find.text('确认写入'));
    await tester.pumpAndSettle();

    expect(fakeDb.lastUpdatedGift?.note, isNull);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('AddRecordScreen 新增分支保存备注时会把合法备注写入真实存储链路',
      (WidgetTester tester) async {
    final fakeDb = RecordingStorageService();

    await tester.pumpWidget(
      buildTestApp(
        child: AddRecordScreen(
          prefillGuestName: '张三',
          prefillAmount: 200,
          prefillIsReceived: true,
          storageService: fakeDb,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(noteFieldFinder, '新增分支备注');
    await tester.pump();

    await tester.tap(find.text('保存记录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认写入'));
    await tester.pumpAndSettle();

    expect(fakeDb.lastCreatedGift?.note, '新增分支备注');
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('AddRecordScreen 新增分支的纯空白备注在确认弹窗中不展示，最终保存为 null',
      (WidgetTester tester) async {
    final fakeDb = RecordingStorageService();

    await tester.pumpWidget(
      buildTestApp(
        child: AddRecordScreen(
          prefillGuestName: '张三',
          prefillAmount: 200,
          prefillIsReceived: true,
          storageService: fakeDb,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(noteFieldFinder, '   ');
    await tester.pump();

    await tester.tap(find.text('保存记录'));
    await tester.pumpAndSettle();

    expect(find.text('备注'), findsNothing);

    await tester.tap(find.text('确认写入'));
    await tester.pumpAndSettle();

    expect(fakeDb.lastCreatedGift?.note, isNull);
    await tester.pump(const Duration(seconds: 2));
  });
}
