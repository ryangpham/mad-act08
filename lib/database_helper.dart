import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:act08/services/deck_of_cards_api.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  final DeckOfCardsApi _deckApi = DeckOfCardsApi();

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('card_organizer.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Create Folders table
    await db.execute('''
      CREATE TABLE folders(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        folder_name TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');

    // Create Cards table with foreign key
    await db.execute('''
      CREATE TABLE cards(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        card_name TEXT NOT NULL,
        suit TEXT NOT NULL,
        image_url TEXT,
        folder_id INTEGER,
        FOREIGN KEY (folder_id) REFERENCES folders (id)
          ON DELETE CASCADE
      )
    ''');

    // Prepopulate folders
    await _prepopulateFolders(db);

    // Prepopulate cards from API
    await _syncCardsFromApi(db);
  }

  Future<void> _prepopulateFolders(Database db) async {
    final folders = ['Hearts', 'Diamonds', 'Clubs', 'Spades'];
    for (int i = 0; i < folders.length; i++) {
      await db.insert('folders', {
        'folder_name': folders[i],
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> syncCardsFromApi() async {
    final db = await database;
    await _syncCardsFromApi(db);
  }

  Future<void> _syncCardsFromApi(Database db) async {
    final folders = await db.query('folders', columns: ['id', 'folder_name']);
    final folderMap = <String, int>{
      for (final row in folders)
        (row['folder_name'] as String).toUpperCase(): row['id'] as int,
    };

    final cards = await _deckApi.fetchStandardDeckCards();

    await db.transaction((txn) async {
      await txn.delete('cards');

      for (final card in cards) {
        final suit = (card['suit'] as String).toUpperCase();
        final folderId = folderMap[suit];
        if (folderId == null) {
          continue;
        }

        await txn.insert('cards', {
          'card_name': _formatCardValue(card['value'] as String),
          'suit': _toTitleCase(suit),
          'image_url': card['image'] as String?,
          'folder_id': folderId,
        });
      }
    });
  }

  String _formatCardValue(String value) {
    switch (value.toUpperCase()) {
      case 'ACE':
      case 'KING':
      case 'QUEEN':
      case 'JACK':
        return _toTitleCase(value);
      default:
        return value;
    }
  }

  String _toTitleCase(String value) {
    if (value.isEmpty) return value;
    final lower = value.toLowerCase();
    return '${lower[0].toUpperCase()}${lower.substring(1)}';
  }
}
