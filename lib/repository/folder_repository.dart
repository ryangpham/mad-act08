import 'package:sqflite/sqflite.dart';
import 'package:act08/database_helper.dart';
import 'package:act08/models/folder.dart';

class FolderRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // CREATE
  Future<int> insertFolder(Folder folder) async {
    final db = await _dbHelper.database;
    return await db.insert('folders', folder.toMap());
  }

  // READ all folders
  Future<List<Folder>> getAllFolders() async {
    final db = await _dbHelper.database;

    final List<Map<String, dynamic>> maps = await db.query('folders');

    return List.generate(maps.length, (i) {
      return Folder.fromMap(maps[i]);
    });
  }

  // READ single folder
  Future<Folder?> getFolderById(int id) async {
    final db = await _dbHelper.database;

    final List<Map<String, dynamic>> maps = await db.query(
      'folders',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;

    return Folder.fromMap(maps.first);
  }

  // UPDATE
  Future<int> updateFolder(Folder folder) async {
    final db = await _dbHelper.database;

    return await db.update(
      'folders',
      folder.toMap(),
      where: 'id = ?',
      whereArgs: [folder.id],
    );
  }

  // DELETE
  Future<int> deleteFolder(int id) async {
    final db = await _dbHelper.database;

    return await db.delete('folders', where: 'id = ?', whereArgs: [id]);
  }

  // COUNT folders
  Future<int> getFolderCount() async {
    final db = await _dbHelper.database;

    final result = await db.rawQuery('SELECT COUNT(*) as count FROM folders');

    return Sqflite.firstIntValue(result) ?? 0;
  }
}
