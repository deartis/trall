import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/marker_model.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('trallzero.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE markers (
        id TEXT PRIMARY KEY,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        type TEXT NOT NULL,
        description TEXT NOT NULL,
        heading REAL,
        confirmations INTEGER NOT NULL DEFAULT 1,
        createdAt TEXT,
        updatedAt TEXT
      )
    ''');
  }

  Future<void> _onUpgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE markers ADD COLUMN heading REAL');
      await db.execute('ALTER TABLE markers ADD COLUMN confirmations INTEGER NOT NULL DEFAULT 1');
      await db.execute('ALTER TABLE markers ADD COLUMN createdAt TEXT');
      await db.execute('ALTER TABLE markers ADD COLUMN updatedAt TEXT');
    }
  }

  Future<void> insertMarker(TruckerMarker marker) async {
    final db = await instance.database;
    await db.insert(
      'markers',
      marker.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<TruckerMarker>> getAllMarkers() async {
    final db = await instance.database;
    final result = await db.query('markers');
    return result.map((json) => TruckerMarker.fromMap(json)).toList();
  }

  Future<void> deleteMarker(String id) async {
    final db = await instance.database;
    await db.delete(
      'markers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearAllMarkers() async {
    final db = await instance.database;
    await db.delete('markers');
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
