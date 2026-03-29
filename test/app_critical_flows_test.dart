import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gift_ledger/main.dart';
import 'package:gift_ledger/models/gift.dart';
import 'package:gift_ledger/models/guest.dart';
import 'package:gift_ledger/models/update_manifest.dart';
import 'package:gift_ledger/screens/about_app_screen.dart';
import 'package:gift_ledger/screens/add_record_screen.dart';
import 'package:gift_ledger/screens/dashboard_screen.dart';
import 'package:gift_ledger/screens/pending_list_screen.dart';
import 'package:gift_ledger/screens/record_list_screen.dart';
import 'package:gift_ledger/screens/settings_screen.dart';
import 'package:gift_ledger/screens/statistics_screen.dart';
import 'package:gift_ledger/services/config_service.dart';
import 'package:gift_ledger/services/security_service.dart';
import 'package:gift_ledger/services/update/app_build_info_service.dart';
import 'package:gift_ledger/services/update/update_controller.dart';
import 'package:gift_ledger/services/update/update_prompt_policy.dart';
import 'package:gift_ledger/services/update/update_repository.dart';
import 'package:gift_ledger/widgets/add_record/record_note_field.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoopUpdateRepository implements UpdateRepository {
  @override
  String? get cachedManifestJson => null;

  @override
  Future<UpdateManifest> fetchManifest() {
    throw UnimplementedError();
  }
}

class _NoopBuildInfoService implements AppBuildInfoService {
  const _NoopBuildInfoService();

  @override
  Future<AppBuildInfo> getCurrentBuildInfo() {
    throw UnimplementedError();
  }
}

class FakeUpdateController extends UpdateController {
  FakeUpdateController({
    UpdateState state = const UpdateState(),
  })  : _fakeState = state,
        super(
          repository: _NoopUpdateRepository(),
          appBuildInfoService: const _NoopBuildInfoService(),
          configService: ConfigService(),
        );

  factory FakeUpdateController.idle() {
    return FakeUpdateController(
      state: const UpdateState(status: UpdateStateStatus.idle),
    );
  }

  UpdateState _fakeState;

  @override
  UpdateState get state => _fakeState;

  void emit(UpdateState state) {
    _fakeState = state;
    notifyListeners();
  }

  @override
  Future<void> checkForUpdates({required UpdateCheckSource source}) async {}

  @override
  Future<void> markCurrentTargetPresented() async {}

  @override
  Future<void> ignoreCurrentTarget() async {}
}

class FakeSettingsStorageService {
  final List<VoidCallback> _listeners = [];

  void addListener(VoidCallback listener) => _listeners.add(listener);

  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  Future<bool> getStatsIncludeEventBooks() async => true;

  Future<bool> getEventBooksEnabled() async => true;

  Future<void> setShowHomeAmounts(bool value) async {}

  Future<bool> getDefaultIsReceived() async => true;

  Future<void> setDefaultIsReceived(bool value) async {}
}

class FakeTemplateService {
  Future<bool> getUseFuzzyAmount() async => false;

  Future<void> setUseFuzzyAmount(bool value) async {}
}

class FakeNotificationService {
  Future<bool> isEnabled() async => false;

  Future<void> setEnabled(bool value) async {}
}

class FakeSettingsSecurityService {
  Future<String> getSecurityMode() async => SecurityService.modeNone;

  Future<bool> hasPin() async => true;

  Future<void> setPin(String pin) async {}

  Future<void> setSecurityMode(String mode) async {}
}

class FakeStatisticsStorageService implements StatisticsStorage {
  FakeStatisticsStorageService({
    required this.gifts,
    required this.guests,
  });

  final List<Gift> gifts;
  final List<Guest> guests;
  final List<VoidCallback> _listeners = [];

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  Future<List<Gift>> getAllGifts() async => gifts;

  @override
  Future<List<Guest>> getAllGuests() async => guests;

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);
}

class RecordingAddRecordStorage implements AddRecordStorage {
  Gift? lastCreatedGift;
  Guest? lastCreatedGuest;

  @override
  Future<List<Guest>> getAllGuests() async => const <Guest>[];

  @override
  Future<List<Gift>> getPendingReceipts() async => const <Gift>[];

  @override
  Future<List<Gift>> getUnreturnedGifts() async => const <Gift>[];

  @override
  Future<void> saveGiftWithGuest(Gift gift, Guest guest) async {
    lastCreatedGift = gift;
    lastCreatedGuest = guest;
  }

  @override
  Future<int> updateGift(Gift gift) async => 1;

  @override
  Future<int> updateGuest(Guest guest) async => 1;

  @override
  Future<int> updateReturnStatus(
    int giftId, {
    required bool isReturned,
    int? relatedRecordId,
  }) async {
    return 1;
  }
}

class FakeRecordListStorageService implements RecordListStorage {
  FakeRecordListStorageService({
    required this.gifts,
    required this.guests,
  });

  final List<Gift> gifts;
  final List<Guest> guests;
  final List<VoidCallback> _listeners = [];

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  Future<int> deleteGift(int id) async => 1;

  @override
  Future<List<Gift>> getAllGifts() async => gifts;

  @override
  Future<List<Guest>> getAllGuests() async => guests;

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);
}

class FakePendingListStorageService implements PendingListStorage {
  FakePendingListStorageService({
    required this.unreturnedGifts,
    required this.pendingReceipts,
    required this.guests,
  });

  final List<Gift> unreturnedGifts;
  final List<Gift> pendingReceipts;
  final List<Guest> guests;
  final List<VoidCallback> _listeners = [];

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  Future<List<Guest>> getAllGuests() async => guests;

  @override
  Future<int> incrementRemindedCount(int giftId) async => 1;

  @override
  Future<List<Gift>> getPendingReceipts() async => pendingReceipts;

  @override
  Future<List<Gift>> getUnreturnedGifts() async => unreturnedGifts;

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  @override
  Future<int> updateReturnStatus(
    int giftId, {
    required bool isReturned,
    int? relatedRecordId,
  }) async {
    return 1;
  }
}

Widget _buildMainNavigationTestApp({
  required FakeUpdateController updateController,
  required FakeStatisticsStorageService statisticsStorage,
}) {
  final dashboardGuest = Guest(id: 1, name: '张三', relationship: '朋友');
  final dashboardGift = Gift(
    id: 1,
    guestId: 1,
    amount: 520,
    isReceived: true,
    eventType: EventTypes.wedding,
    date: DateTime(2026, 3, 29),
    note: '首页最近记录',
  );

  return ChangeNotifierProvider<UpdateController>.value(
    value: updateController,
    child: MaterialApp(
      home: MainNavigation(
        screens: [
          DashboardScreen(
            previewData: DashboardPreviewData(
              totalReceived: 520,
              totalSent: 1314,
              recentGifts: [dashboardGift],
              guestMap: {1: dashboardGuest},
              pendingCount: 2,
              eventBooksEnabled: true,
            ),
          ),
          StatisticsScreen(storageService: statisticsStorage),
          SettingsScreen(
            initialAppVersion: '1.3.2',
            storageService: FakeSettingsStorageService(),
            templateService: FakeTemplateService(),
            notificationService: FakeNotificationService(),
            securityService: FakeSettingsSecurityService(),
          ),
        ],
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('zh_CN');
    await ConfigService().init();
  });

  testWidgets('主导航可切换关键页面，并完成统计筛选与关于页跳转', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final statisticsStorage = FakeStatisticsStorageService(
      gifts: [
        Gift(
          id: 1,
          guestId: 1,
          amount: 500,
          isReceived: true,
          eventType: EventTypes.wedding,
          date: DateTime(2025, 3, 20),
        ),
        Gift(
          id: 2,
          guestId: 1,
          amount: 300,
          isReceived: false,
          eventType: EventTypes.wedding,
          date: DateTime(2025, 4, 10),
        ),
        Gift(
          id: 3,
          guestId: 2,
          amount: 800,
          isReceived: true,
          eventType: EventTypes.birthday,
          date: DateTime(2024, 5, 1),
        ),
      ],
      guests: [
        Guest(id: 1, name: '张三', relationship: '朋友'),
        Guest(id: 2, name: '李四', relationship: '同事'),
      ],
    );

    await tester.pumpWidget(
      _buildMainNavigationTestApp(
        updateController: FakeUpdateController.idle(),
        statisticsStorage: statisticsStorage,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('活动簿'), findsOneWidget);
    expect(find.text('待处理'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.bar_chart_rounded));
    await tester.pumpAndSettle();

    expect(find.text('统计分析'), findsOneWidget);
    expect(find.text('最常见礼金金额'), findsOneWidget);

    await tester.tap(find.byTooltip('选择年份'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2025年').last);
    await tester.pumpAndSettle();

    expect(find.text('2025'), findsOneWidget);
    expect(find.text('查看详细人情往来'), findsOneWidget);

    await tester.tap(find.text('婚礼').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('婚礼往来'), findsOneWidget);
    expect(find.text('共 2 条记录'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('应用安全锁'), findsOneWidget);
    expect(find.text('关于随礼记'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('关于随礼记'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    final aboutTile = find.ancestor(
      of: find.text('关于随礼记'),
      matching: find.byType(ListTile),
    );
    await tester.tap(aboutTile);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(AboutAppScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('新增记录流程可完成填写、确认并写入存储', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final storage = RecordingAddRecordStorage();

    await tester.pumpWidget(
      MaterialApp(
        home: AddRecordScreen(storageService: storage),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '韩梅梅');
    await tester.pumpAndSettle();

    await tester.tap(find.text('¥500'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('送礼'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(RecordNoteField.fieldKey),
      '集成测试新增备注',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('保存记录'));
    await tester.pumpAndSettle();

    expect(find.text('确认保存记录'), findsOneWidget);
    expect(find.text('确认写入'), findsOneWidget);

    await tester.tap(find.text('确认写入'));
    await tester.pumpAndSettle();

    expect(storage.lastCreatedGuest?.name, '韩梅梅');
    expect(storage.lastCreatedGuest?.relationship, RelationshipTypes.friend);
    expect(storage.lastCreatedGift?.amount, 500);
    expect(storage.lastCreatedGift?.isReceived, isFalse);
    expect(storage.lastCreatedGift?.note, '集成测试新增备注');
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('记录列表与待处理列表的关键交互可正常完成', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final recordStorage = FakeRecordListStorageService(
      gifts: [
        Gift(
          id: 1,
          guestId: 1,
          amount: 888,
          isReceived: true,
          eventType: EventTypes.wedding,
          date: DateTime(2026, 3, 24),
          note: '目标备注',
        ),
        Gift(
          id: 2,
          guestId: 2,
          amount: 666,
          isReceived: false,
          eventType: EventTypes.birthday,
          date: DateTime(2026, 3, 20),
          note: '其他备注',
        ),
      ],
      guests: [
        Guest(id: 1, name: '目标人', relationship: '朋友'),
        Guest(id: 2, name: '路人甲', relationship: '同事'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RecordListScreen(storageService: recordStorage),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('全部记录'), findsOneWidget);
    expect(find.text('2 笔记录'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '目标人');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('目标备注'), findsOneWidget);
    expect(find.text('其他备注'), findsNothing);
    expect(find.text('1 笔记录'), findsOneWidget);

    final pendingStorage = FakePendingListStorageService(
      unreturnedGifts: [
        Gift(
          id: 3,
          guestId: 3,
          amount: 300,
          isReceived: true,
          eventType: EventTypes.wedding,
          date: DateTime(2025, 12, 1),
          note: '待还备注',
        ),
      ],
      pendingReceipts: [
        Gift(
          id: 4,
          guestId: 4,
          amount: 400,
          isReceived: false,
          eventType: EventTypes.birthday,
          date: DateTime(2025, 10, 1),
          note: '待收备注',
        ),
      ],
      guests: [
        Guest(id: 3, name: '王五', relationship: '朋友'),
        Guest(id: 4, name: '赵六', relationship: '同事'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PendingListScreen(storageService: pendingStorage),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('未还 (1)'), findsOneWidget);
    expect(find.text('待收 (1)'), findsOneWidget);
    expect(find.text('待还备注'), findsOneWidget);

    await tester.tap(find.text('待收 (1)'));
    await tester.pumpAndSettle();

    expect(find.text('待收备注'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
