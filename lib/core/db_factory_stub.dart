import 'package:sqflite_common/sqlite_api.dart';

/// الويب: لا SQLite (يُستخدم Hive)
Future<DatabaseFactory> dbFactory() async =>
    throw UnsupportedError('SQLite غير متاح على الويب');
