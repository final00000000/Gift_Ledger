import 'package:sqflite/sqflite.dart';
import '../models/event_book.dart';
import '../models/gift.dart';
import '../models/guest.dart';

/// 原生平台的数据库服务
class NativeDatabaseService {
  static final NativeDatabaseService _instance = NativeDatabaseService._internal();
  static Database? _database;

  factory NativeDatabaseService() => _instance;

  NativeDatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = '$dbPath/gift_money.db';

    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE guests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        relationship TEXT NOT NULL,
        phone TEXT,
        note TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE event_books (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        date TEXT NOT NULL,
        lunarDate TEXT,
        note TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE gifts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        guestId INTEGER NOT NULL,
        amount REAL NOT NULL,
        isReceived INTEGER NOT NULL,
        eventType TEXT NOT NULL,
        eventBookId INTEGER,
        date TEXT NOT NULL,
        note TEXT,
        relatedRecordId INTEGER,
        isReturned INTEGER NOT NULL DEFAULT 0,
        returnDueDate TEXT,
        remindedCount INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (guestId) REFERENCES guests (id),
        FOREIGN KEY (eventBookId) REFERENCES event_books (id)
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_gifts_eventBookId ON gifts(eventBookId)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 添加还礼追踪字段
      await db.execute('ALTER TABLE gifts ADD COLUMN relatedRecordId INTEGER');
      await db.execute('ALTER TABLE gifts ADD COLUMN isReturned INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE gifts ADD COLUMN returnDueDate TEXT');
      await db.execute('ALTER TABLE gifts ADD COLUMN remindedCount INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE event_books (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          date TEXT NOT NULL,
          lunarDate TEXT,
          note TEXT,
          createdAt TEXT NOT NULL
        )
      ''');
      await db.execute('ALTER TABLE gifts ADD COLUMN eventBookId INTEGER');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_gifts_eventBookId ON gifts(eventBookId)');
    }
  }

  // Guest CRUD
  Future<int> insertGuest(Guest guest) async {
    final db = await database;
    return await db.insert('guests', guest.toMap());
  }

  Future<List<Guest>> getAllGuests() async {
    final db = await database;
    final maps = await db.query('guests', orderBy: 'name ASC');
    return maps.map((map) => Guest.fromMap(map)).toList();
  }

  Future<Guest?> getGuestById(int id) async {
    final db = await database;
    final maps = await db.query('guests', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Guest.fromMap(maps.first);
  }

  Future<Guest?> getGuestByName(String name) async {
    final db = await database;
    final maps = await db.query('guests', where: 'name = ?', whereArgs: [name]);
    if (maps.isEmpty) return null;
    return Guest.fromMap(maps.first);
  }

  Future<int> updateGuest(Guest guest) async {
    final db = await database;
    return await db.update(
      'guests',
      guest.toMap(),
      where: 'id = ?',
      whereArgs: [guest.id],
    );
  }

  Future<int> deleteGuest(int id) async {
    final db = await database;
    await db.delete('gifts', where: 'guestId = ?', whereArgs: [id]);
    return await db.delete('guests', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertEventBook(EventBook eventBook) async {
    final db = await database;
    return await db.insert('event_books', eventBook.toMap());
  }

  Future<List<EventBook>> getAllEventBooks() async {
    final db = await database;
    final maps = await db.query('event_books', orderBy: 'date DESC, createdAt DESC');
    return maps.map((map) => EventBook.fromMap(map)).toList();
  }

  Future<EventBook?> getEventBookById(int id) async {
    final db = await database;
    final maps = await db.query('event_books', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return EventBook.fromMap(maps.first);
  }

  Future<int> updateEventBook(EventBook eventBook) async {
    final db = await database;
    return await db.update(
      'event_books',
      eventBook.toMap(),
      where: 'id = ?',
      whereArgs: [eventBook.id],
    );
  }

  Future<int> deleteEventBook(int id) async {
    final db = await database;
    return await db.transaction((txn) async {
      await txn.delete('gifts', where: 'eventBookId = ?', whereArgs: [id]);
      return await txn.delete('event_books', where: 'id = ?', whereArgs: [id]);
    });
  }

  // Gift CRUD
  Future<int> insertGift(Gift gift) async {
    final db = await database;
    return await db.insert('gifts', gift.toMap());
  }

  Future<void> insertGiftsBatch(List<Gift> gifts) async {
    if (gifts.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final gift in gifts) {
      batch.insert('gifts', gift.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<List<Gift>> getAllGifts() async {
    final db = await database;
    final maps = await db.query('gifts', orderBy: 'date DESC');
    return maps.map((map) => Gift.fromMap(map)).toList();
  }

  Future<List<Gift>> getGiftsByGuest(int guestId) async {
    final db = await database;
    final maps = await db.query(
      'gifts',
      where: 'guestId = ?',
      whereArgs: [guestId],
      orderBy: 'date DESC',
    );
    return maps.map((map) => Gift.fromMap(map)).toList();
  }

  Future<List<Gift>> getGiftsByEventBook(int eventBookId) async {
    final db = await database;
    final maps = await db.query(
      'gifts',
      where: 'eventBookId = ?',
      whereArgs: [eventBookId],
      orderBy: 'date DESC',
    );
    return maps.map((map) => Gift.fromMap(map)).toList();
  }

  Future<List<Gift>> getRecentGifts({int limit = 10}) async {
    final db = await database;
    final maps = await db.query('gifts', orderBy: 'id DESC', limit: limit); // 使用 id DESC 确保最新录入的在前
    return maps.map((map) => Gift.fromMap(map)).toList();
  }

  Future<int> updateGift(Gift gift) async {
    final db = await database;
    return await db.update(
      'gifts',
      gift.toMap(),
      where: 'id = ?',
      whereArgs: [gift.id],
    );
  }

  Future<int> deleteGift(int id) async {
    final db = await database;
    return await db.delete('gifts', where: 'id = ?', whereArgs: [id]);
  }

  Future<double> getEventBookReceivedTotal(int eventBookId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM gifts WHERE isReceived = 1 AND eventBookId = ?',
      [eventBookId],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getEventBookSentTotal(int eventBookId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM gifts WHERE isReceived = 0 AND eventBookId = ?',
      [eventBookId],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<int> getEventBookGiftCount(int eventBookId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM gifts WHERE eventBookId = ?',
      [eventBookId],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  // 统计
  Future<double> getTotalReceived({bool includeEventBooks = true}) async {
    final db = await database;
    final filter = includeEventBooks ? '' : ' AND eventBookId IS NULL';
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM gifts WHERE isReceived = 1$filter',
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getTotalSent({bool includeEventBooks = true}) async {
    final db = await database;
    final filter = includeEventBooks ? '' : ' AND eventBookId IS NULL';
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM gifts WHERE isReceived = 0$filter',
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<Map<int, double>> getGuestReceivedTotals({bool includeEventBooks = true}) async {
    final db = await database;
    final filter = includeEventBooks ? '' : ' AND eventBookId IS NULL';
    final result = await db.rawQuery(
      'SELECT guestId, SUM(amount) as total FROM gifts WHERE isReceived = 1$filter GROUP BY guestId',
    );
    return {
      for (var row in result)
        row['guestId'] as int: (row['total'] as num).toDouble()
    };
  }

  Future<Map<int, double>> getGuestSentTotals({bool includeEventBooks = true}) async {
    final db = await database;
    final filter = includeEventBooks ? '' : ' AND eventBookId IS NULL';
    final result = await db.rawQuery(
      'SELECT guestId, SUM(amount) as total FROM gifts WHERE isReceived = 0$filter GROUP BY guestId',
    );
    return {
      for (var row in result)
        row['guestId'] as int: (row['total'] as num).toDouble()
    };
  }

  Future<void> saveGiftWithGuest(Gift gift, Guest guest) async {
    final db = await database;
    await db.transaction((txn) async {
      // 检查联系人是否存在
      final List<Map<String, dynamic>> guestMaps = await txn.query(
        'guests',
        where: 'name = ?',
        whereArgs: [guest.name],
      );

      int guestId;
      if (guestMaps.isEmpty) {
        guestId = await txn.insert('guests', guest.toMap());
      } else {
        final existingGuest = Guest.fromMap(guestMaps.first);
        guestId = existingGuest.id!;
        if (existingGuest.relationship != guest.relationship) {
          await txn.update(
            'guests',
            guest.toMap(),
            where: 'id = ?',
            whereArgs: [guestId],
          );
        }
      }

      // 保存礼金
      await txn.insert('gifts', gift.copyWith(guestId: guestId).toMap());
    });
  }

  // 还礼追踪查询方法
  
  /// 获取未还清单：收礼且未还的记录
  Future<List<Gift>> getUnreturnedGifts({bool includeEventBooks = true}) async {
    final db = await database;
    final filter = includeEventBooks ? '' : ' AND eventBookId IS NULL';
    final maps = await db.query(
      'gifts',
      where: 'isReceived = 1 AND isReturned = 0$filter',
      orderBy: 'date DESC',
    );
    return maps.map((map) => Gift.fromMap(map)).toList();
  }

  /// 获取待收清单：送礼且未收的记录
  Future<List<Gift>> getPendingReceipts({bool includeEventBooks = true}) async {
    final db = await database;
    final filter = includeEventBooks ? '' : ' AND eventBookId IS NULL';
    final maps = await db.query(
      'gifts',
      where: 'isReceived = 0 AND isReturned = 0$filter',
      orderBy: 'date DESC',
    );
    return maps.map((map) => Gift.fromMap(map)).toList();
  }

  /// 更新还礼状态
  Future<int> updateReturnStatus(int giftId, {required bool isReturned, int? relatedRecordId}) async {
    final db = await database;
    return await db.update(
      'gifts',
      {
        'isReturned': isReturned ? 1 : 0,
        'relatedRecordId': relatedRecordId,
      },
      where: 'id = ?',
      whereArgs: [giftId],
    );
  }

  /// 增加提醒计数
  Future<int> incrementRemindedCount(int giftId) async {
    final db = await database;
    return await db.rawUpdate(
      'UPDATE gifts SET remindedCount = remindedCount + 1 WHERE id = ?',
      [giftId],
    );
  }

  /// 关联两条记录
  Future<void> linkGiftRecords(int giftId1, int giftId2) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update('gifts', {'relatedRecordId': giftId2, 'isReturned': 1}, where: 'id = ?', whereArgs: [giftId1]);
      await txn.update('gifts', {'relatedRecordId': giftId1, 'isReturned': 1}, where: 'id = ?', whereArgs: [giftId2]);
    });
  }

  /// 获取待处理记录数量
  Future<int> getPendingCount({bool includeEventBooks = true}) async {
    final db = await database;
    final filter = includeEventBooks ? '' : ' AND eventBookId IS NULL';
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM gifts WHERE isReturned = 0$filter',
    );
    return (result.first['count'] as int?) ?? 0;
  }
}

final nativeDb = NativeDatabaseService();
