import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' as sq;
import 'package:sqflite_common/sqlite_api.dart';

/// أندرويد/iOS: sqflite الأصلي. غير ذلك (اختبارات سطح المكتب): مصنع يُحقن من الاختبار.
@visibleForTesting
DatabaseFactory? debugDbFactory;

Future<DatabaseFactory> dbFactory() async {
  if (debugDbFactory != null) return debugDbFactory!;
  if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
    return sq.databaseFactory;
  }
  throw UnsupportedError('SQLite: لم يُحقن مصنع لهذه المنصة');
}
