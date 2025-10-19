import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'sqlite_db.dart';
import 'message_model.dart';

class MessagesRepository {
  Future<Database> get _db async => AppDatabase.instance.database;

  final Map<String, StreamController<List<MessageModel>>> _channels = {};

  Stream<List<MessageModel>> watchLatest(
    String uid,
    String subject, {
    int limit = 100,
  }) {
    final key = '$uid::$subject';
    var ctrl = _channels[key];
    if (ctrl == null || ctrl.isClosed) {
      ctrl = StreamController<List<MessageModel>>.broadcast(
        onListen: () => _emit(uid, subject, limit),
      );
      _channels[key] = ctrl;
    }
    return ctrl.stream;
  }

  Future<void> _emit(String uid, String subject, int limit) async {
    final db = await _db;
    final rows = await db.query(
      'messages',
      where: 'uid = ? AND subject = ?',
      whereArgs: [uid, subject],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    final list = rows.map(MessageModel.fromMap).toList();
    _channels['$uid::$subject']?.add(list);
  }

  Future<int> insertMessage(MessageModel m) async {
    final db = await _db;
    final id = await db.insert('messages', m.toMap());
    await _emit(m.uid, m.subject, 100);
    return id;
  }
}
