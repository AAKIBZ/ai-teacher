// dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'sqlite_db.dart';

class SubjectsRepository {
  final Map<String, StreamController<List<String>>> _channels = {};

  Future<Database> get _db async => AppDatabase.instance.database;

  /// Returns a broadcast stream of subject names for the given uid.
  Stream<List<String>> watch(String uid) {
    var ctrl = _channels[uid];
    if (ctrl == null || ctrl.isClosed) {
      ctrl = StreamController<List<String>>.broadcast(
        onListen: () => _emit(uid),
      );
      _channels[uid] = ctrl;
    }
    return ctrl.stream;
  }

  /// Emits the current list of subjects for `uid` into the stream controller.
  Future<void> _emit(String uid) async {
    final db = await _db;
    final rows = await db.query(
      'subjects',
      where: 'uid = ?',
      whereArgs: [uid],
      orderBy: 'created_at DESC',
    );
    final list = rows.map<String>((r) => r['name'] as String).toList();
    _channels[uid]?.add(list);
  }

  /// Inserts a subject for `uid`. Returns inserted row id or -1 if duplicate.
  Future<int> insertSubject(String uid, String name) async {
    final db = await _db;
    final exists = await db.query(
      'subjects',
      where: 'uid = ? AND name = ?',
      whereArgs: [uid, name],
      limit: 1,
    );
    if (exists.isNotEmpty) return -1;
    final id = await db.insert('subjects', {
      'uid': uid,
      'name': name,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    await _emit(uid);
    return id;
  }

  /// Close all controllers (call on app shutdown if needed).
  void dispose() {
    for (final c in _channels.values) {
      if (!c.isClosed) c.close();
    }
    _channels.clear();
  }
}

final subjectsRepoProvider = Provider<SubjectsRepository>((_) => SubjectsRepository());

