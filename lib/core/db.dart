/// db.dart — طبقة التخزين الدائم | نظام الفواتير
///
/// **أندرويد: SQLite** (المعيار المعتمد في تطبيقات المحاسبة على الهواتف):
///   - وضع WAL + synchronous=FULL: كل عملية حفظ تُكتب على القرص قبل أن تعود،
///     وانقطاع الكهرباء/إغلاق التطبيق فجأة لا يُتلف القاعدة (إما تتم المعاملة كاملة أو لا تتم).
///   - كل حفظ داخل **معاملة واحدة** (transaction): حذف عميل مع فواتيره ودفعاته يتم كاملًا أو لا يتم.
///   - جدول لكل نوع (clients / docs / payments / claims / kv) — السجل يُخزَّن كـ JSON
///     مع أعمدة مفهرسة للاستعلام؛ هذا يجعل إضافة حقل جديد لاحقًا بلا ترحيل مخطط خطر.
///   - فحص سلامة `PRAGMA quick_check` عند الفتح؛ إن فشل يُبلَّغ المستخدم ويُقترح الاسترجاع من آخر نسخة.
///   - الملف في مجلد التطبيق الداخلي الخاص (لا يستطيع أي تطبيق آخر قراءته أو حذفه).
///
/// **الويب (المعاينة فقط): Hive** (IndexedDB) بنفس الواجهة.
///
/// **ترحيل آلي:** عند أول تشغيل بعد التحديث تُنقل بيانات Hive القديمة إلى SQLite في معاملة
/// واحدة، ويُتحقق من تطابق العدد قبل تعليم الترحيل كمكتمل. صندوق Hive القديم لا يُحذف
/// (يبقى نسخة أمان) — فلا يمكن أن تضيع بيانات بسبب الترحيل.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common/sqlite_api.dart';

import 'db_factory.dart';

/// الجداول التي تحمل سجلات (كل سجل Map له 'id')
const recordTables = ['clients', 'docs', 'payments', 'claims'];

abstract class AppDb {
  /// وصف مقروء لنوع التخزين (يظهر في الإعدادات)
  String get engine;

  /// مسار ملف القاعدة (null على الويب)
  String? get path;

  Future<void> open(String name);

  Future<List<Map<String, dynamic>>> all(String table);

  /// يستبدل محتوى عدة جداول كاملًا في **معاملة واحدة** (الكل أو لا شيء)
  Future<void> replaceTables(Map<String, List<Map<String, dynamic>>> tables);

  Future<dynamic> getKv(String key);
  Future<void> putKv(String key, dynamic value);
  Future<void> clearAll();

  /// فحص السلامة: null = سليمة، وإلا رسالة الخطأ
  Future<String?> integrityCheck();

  Future<void> close();

  /// الاختيار الآلي حسب المنصة
  static AppDb create() => kIsWeb ? HiveDb() : SqliteDb();
}

/* ============================================================
   SQLite (أندرويد / سطح المكتب / الاختبارات)
   ============================================================ */
class SqliteDb implements AppDb {
  Database? _db;
  String? _path;

  /// للاختبارات: مجلد بديل
  @visibleForTesting
  static String? debugDir;

  @override
  String get engine => 'SQLite (WAL)';
  @override
  String? get path => _path;

  Database get db {
    final d = _db;
    if (d == null) throw StateError('قاعدة البيانات غير مفتوحة');
    return d;
  }

  @override
  Future<void> open(String name) async {
    final factory = await dbFactory();
    final dir = debugDir ?? await factory.getDatabasesPath();
    _path = p.join(dir, '$name.db');
    _db = await factory.openDatabase(
      _path!,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          // WAL: القرّاء لا يحجبون الكاتب، والكتابة ذرّية؛ FULL: مزامنة كاملة مع القرص
          await db.rawQuery('PRAGMA journal_mode=WAL');
          await db.execute('PRAGMA synchronous=FULL');
          await db.execute('PRAGMA foreign_keys=ON');
        },
        onCreate: (db, v) async {
          final b = db.batch();
          for (final t in recordTables) {
            b.execute(
              'CREATE TABLE $t (id TEXT PRIMARY KEY, data TEXT NOT NULL, updated_at TEXT, deleted_at TEXT)',
            );
          }
          b.execute('CREATE TABLE kv (k TEXT PRIMARY KEY, v TEXT)');
          b.execute('CREATE INDEX docs_deleted ON docs(deleted_at)');
          b.execute('CREATE INDEX payments_deleted ON payments(deleted_at)');
          await b.commit(noResult: true);
        },
      ),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> all(String table) async {
    final rows = await db.query(table, columns: ['data'], orderBy: 'rowid');
    final out = <Map<String, dynamic>>[];
    for (final r in rows) {
      try {
        final m = jsonDecode(r['data'] as String);
        if (m is Map) out.add(Map<String, dynamic>.from(m));
      } catch (e) {
        debugPrint('SqliteDb: skip corrupt row in $table: $e');
      }
    }
    return out;
  }

  @override
  Future<void> replaceTables(
    Map<String, List<Map<String, dynamic>>> tables,
  ) async {
    await db.transaction((txn) async {
      final b = txn.batch();
      tables.forEach((table, rows) {
        b.delete(table);
        for (final m in rows) {
          b.insert(table, {
            'id': m['id'] as String,
            'data': jsonEncode(m),
            'updated_at': m['updatedAt'] ?? '',
            'deleted_at': m['deletedAt'] ?? '',
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });
      await b.commit(noResult: true);
    });
  }

  @override
  Future<dynamic> getKv(String key) async {
    final r = await db.query('kv', where: 'k = ?', whereArgs: [key], limit: 1);
    if (r.isEmpty) return null;
    final v = r.first['v'] as String?;
    if (v == null) return null;
    try {
      return jsonDecode(v);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> putKv(String key, dynamic value) async {
    await db.insert('kv', {
      'k': key,
      'v': jsonEncode(value),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> clearAll() async {
    await db.transaction((txn) async {
      for (final t in [...recordTables, 'kv']) {
        await txn.delete(t);
      }
    });
  }

  @override
  Future<String?> integrityCheck() async {
    try {
      final r = await db.rawQuery('PRAGMA quick_check');
      final v = r.isEmpty ? 'ok' : '${r.first.values.first}';
      return v == 'ok' ? null : v;
    } catch (e) {
      return '$e';
    }
  }

  @override
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}

/* ============================================================
   Hive (الويب — معاينة فقط) + مصدر الترحيل من الإصدارات القديمة
   ============================================================ */
class HiveDb implements AppDb {
  Box? _box;
  static bool _inited = false;

  /// للاختبارات: تخطي Hive.initFlutter (يُستدعى Hive.init(path) مسبقًا)
  @visibleForTesting
  static bool skipInit = false;

  @override
  String get engine => memoryOnly ? 'ذاكرة مؤقتة (معاينة)' : 'IndexedDB (Hive)';
  @override
  String? get path => null;

  Box get box {
    final b = _box;
    if (b == null) throw StateError('قاعدة البيانات غير مفتوحة');
    return b;
  }

  static Future<void> ensureInit() async {
    if (_inited || skipInit) return;
    await Hive.initFlutter();
    _inited = true;
  }

  @override
  Future<void> open(String name) async {
    await ensureInit();
    try {
      _box = await Hive.openBox(name);
    } catch (e) {
      // الويب فقط: iframe مقيّد (sandbox بلا allow-same-origin) يجعل الأصل مبهمًا
      // فيرفض المتصفح IndexedDB. نعمل في الذاكرة كي تظهر المعاينة بدل شاشة الخطأ.
      // على أندرويد لا يمرّ التطبيق من هنا إطلاقًا (SqliteDb).
      if (!kIsWeb) rethrow;
      debugPrint('HiveDb: IndexedDB غير متاح ($e) — تخزين مؤقت في الذاكرة');
      _box = await Hive.openBox(name, bytes: Uint8List(0));
      memoryOnly = true;
    }
  }

  /// true عندما تعذّر IndexedDB وعمل الصندوق في الذاكرة (لا يبقى بعد إعادة التحميل)
  bool memoryOnly = false;

  @override
  Future<List<Map<String, dynamic>>> all(String table) async {
    final v = box.get(table);
    if (v is! List) return [];
    return [for (final m in v.whereType<Map>()) _deep(m)];
  }

  @override
  Future<void> replaceTables(
    Map<String, List<Map<String, dynamic>>> tables,
  ) async {
    await box.putAll({for (final e in tables.entries) e.key: e.value});
  }

  @override
  Future<dynamic> getKv(String key) async => box.get(key);

  @override
  Future<void> putKv(String key, dynamic value) => box.put(key, value);

  @override
  Future<void> clearAll() async {
    await box.clear();
  }

  @override
  Future<String?> integrityCheck() async => null;

  @override
  Future<void> close() async {
    await _box?.close();
    _box = null;
  }

  /// Hive يعيد `Map<dynamic,dynamic>` — نحوّله إلى `Map<String,dynamic>` بعمق
  static Map<String, dynamic> _deep(Map m) =>
      m.map((k, v) => MapEntry('$k', _v(v)));
  static dynamic _v(dynamic v) =>
      v is Map ? _deep(v) : (v is List ? v.map(_v).toList() : v);

  /* ---------- الترحيل من Hive إلى SQLite (مرة واحدة) ---------- */
  /// يقرأ صندوق الإصدارات القديمة (إن وُجد) ويعيد محتواه، أو null إن لم يوجد/فارغ.
  static Future<Map<String, dynamic>?> readLegacy(String boxName) async {
    try {
      await ensureInit();
      if (!await Hive.boxExists(boxName)) return null;
      final b = await Hive.openBox(boxName);
      if (b.isEmpty) {
        await b.close();
        return null;
      }
      final out = <String, dynamic>{for (final k in b.keys) '$k': _v(b.get(k))};
      await b.close();
      return out;
    } catch (e) {
      debugPrint('HiveDb.readLegacy failed: $e');
      return null;
    }
  }
}
