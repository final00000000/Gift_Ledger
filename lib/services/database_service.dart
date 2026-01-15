import 'package:sqflite/sqflite.dart';
import '../models/event_book.dart';
import '../models/gift.dart';
import '../models/guest.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;

  DatabaseService._internal();

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
      version: 2,
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
        FOREIGN KEY (guestId) REFERENCES guests (id),
        FOREIGN KEY (eventBookId) REFERENCES event_books (id)
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_gifts_eventBookId ON gifts(eventBookId)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
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
    final maps = await db.query('gifts', orderBy: 'date DESC', limit: limit);
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
}
