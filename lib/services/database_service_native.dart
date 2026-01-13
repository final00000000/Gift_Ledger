import 'package:sqflite/sqflite.dart';
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
      version: 1,
      onCreate: _onCreate,
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
      CREATE TABLE gifts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        guestId INTEGER NOT NULL,
        amount REAL NOT NULL,
        isReceived INTEGER NOT NULL,
        eventType TEXT NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        FOREIGN KEY (guestId) REFERENCES guests (id)
      )
    ''');
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

  // Gift CRUD
  Future<int> insertGift(Gift gift) async {
    final db = await database;
    return await db.insert('gifts', gift.toMap());
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

  // 统计
  Future<double> getTotalReceived() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM gifts WHERE isReceived = 1',
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getTotalSent() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM gifts WHERE isReceived = 0',
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<Map<int, double>> getGuestReceivedTotals() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT guestId, SUM(amount) as total FROM gifts WHERE isReceived = 1 GROUP BY guestId',
    );
    return {
      for (var row in result)
        row['guestId'] as int: (row['total'] as num).toDouble()
    };
  }

  Future<Map<int, double>> getGuestSentTotals() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT guestId, SUM(amount) as total FROM gifts WHERE isReceived = 0 GROUP BY guestId',
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
}

final nativeDb = NativeDatabaseService();
