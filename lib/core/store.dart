/// store.dart — حالة التطبيق والتخزين المحلي (Hive) | كيف الضيافة
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'backup_service.dart';
import 'brand.dart';
import 'db.dart';
import 'file_service.dart';
import 'models.dart';

class Store extends ChangeNotifier {
  /// قاعدة البيانات: SQLite على أندرويد، Hive على الويب (انظر db.dart)
  final AppDb _db;
  Store({AppDb? db}) : _db = db ?? AppDb.create();

  AppDb get database => _db;

  /// إعدادات صغيرة (مفتاح/قيمة) — تُحمّل كلها عند التشغيل وتُكتب فورًا عند التغيير
  final Map<String, dynamic> _kv = {};

  /// القوائم النشطة (كل الشاشات تعتمد عليها)
  final List<Client> clients = [];
  final List<Invoice> docs = []; // فواتير + عروض أسعار
  final List<Payment> payments = [];
  final List<Claim> claims = [];

  /// سلة المحذوفات (ملاحظة 8): تُحذف نهائيًا تلقائيًا بعد [trashDays] يومًا
  static const trashDays = 30;
  final List<Client> trashClients = [];
  final List<Invoice> trashDocs = [];
  final List<Payment> trashPayments = [];
  final List<Claim> trashClaims = [];

  Org org = Org();
  bool ready = false;

  /// رسالة خطأ التشغيل (إن فشل فتح قاعدة البيانات) — null يعني لا خطأ
  String? initError;

  /// نتيجة فحص السلامة عند الفتح (null = سليمة)
  String? integrityError;

  /// عدد السجلات المرحّلة من Hive في هذا التشغيل (0 = لا ترحيل)
  int migratedFromHive = 0;

  bool _opened = false;

  Future<void> init() async {
    initError = null;
    try {
      if (!_opened) {
        await _db.open(Brand.current.dbName);
        _opened = true;
        await _migrateFromHiveIfNeeded();
      }
      integrityError = await _db.integrityCheck();
      await _load();
      await purgeExpiredTrash();
      ready = true;
      // نسخة اليوم عند الفتح (إن لم تُكتب بعد) — لا تنتظر الواجهة
      unawaited(BackupService.dailyIfDue(this));
    } catch (e, st) {
      debugPrint('Store.init failed: $e\n$st');
      initError = '$e';
      ready = false;
    }
    notifyListeners();
  }

  /// ترحيل لمرة واحدة من صندوق Hive (الإصدارات ≤ 2.2) إلى SQLite
  /// لا يُحذف الصندوق القديم — يبقى نسخة أمان إضافية.
  Future<void> _migrateFromHiveIfNeeded() async {
    if (_db is! SqliteDb) return;
    if (await _db.getKv('migratedFromHive') == true) return;
    final legacy = await HiveDb.readLegacy(Brand.current.dbName);
    if (legacy != null) {
      List<Map<String, dynamic>> rows(String k) {
        final v = legacy[k];
        if (v is! List) return [];
        return [
          for (final m in v.whereType<Map>())
            if (m['id'] is String) Map<String, dynamic>.from(m),
        ];
      }

      final tables = {
        for (final t in ['clients', 'docs', 'payments']) t: rows(t),
      };
      await _db.replaceTables(tables);
      for (final k in legacy.keys) {
        if (recordTables.contains(k)) continue;
        await _db.putKv(k, legacy[k]);
      }
      // تحقق: كل سجل صالح وصل
      var ok = true;
      for (final e in tables.entries) {
        if ((await _db.all(e.key)).length != e.value.length) ok = false;
      }
      if (!ok) {
        throw StateError(
          'فشل التحقق من ترحيل البيانات — لم يُعلَّم الترحيل كمكتمل، وستُعاد المحاولة',
        );
      }
      migratedFromHive = tables.values.fold<int>(0, (s, l) => s + l.length);
      debugPrint(
        'Store: migrated $migratedFromHive records from Hive to SQLite',
      );
    }
    await _db.putKv('migratedFromHive', true);
  }

  Future<void> _load() async {
    // سجل تالف واحد لا يجب أن يمنع تحميل الباقي
    Future<List<T>> safe<T>(String table, T Function(Map) parse) async {
      final out = <T>[];
      for (final m in await _db.all(table)) {
        try {
          out.add(parse(m));
        } catch (e) {
          debugPrint('skip corrupt $table record: $e');
        }
      }
      return out;
    }

    // كل جدول يحمل النشط والمحذوف معًا؛ نفصلهما حسب deletedAt
    clients.clear();
    trashClients.clear();
    for (final c in await safe('clients', (m) => Client.fromMap(m))) {
      (c.isDeleted ? trashClients : clients).add(c);
    }
    docs.clear();
    trashDocs.clear();
    for (final d in await safe('docs', (m) => Invoice.fromMap(m))) {
      (d.isDeleted ? trashDocs : docs).add(d);
    }
    payments.clear();
    trashPayments.clear();
    for (final p in await safe('payments', (m) => Payment.fromMap(m))) {
      (p.isDeleted ? trashPayments : payments).add(p);
    }
    claims.clear();
    trashClaims.clear();
    for (final c in await safe('claims', (m) => Claim.fromMap(m))) {
      (c.isDeleted ? trashClaims : claims).add(c);
    }
    _kv.clear();
    for (final k in _kvKeys) {
      final v = await _db.getKv(k);
      if (v != null) _kv[k] = v;
    }
    final o = _kv['org'];
    try {
      org = Org.fromMap(o is Map ? o : null);
    } catch (_) {
      org = Org();
    }
  }

  static const _kvKeys = [
    'org',
    'autoBackup',
    'signedIn',
    'accountName',
    'accountEmail',
    'accountPhoto',
    'lastDailyBackup',
    'lastDriveBackup',
    'driveAuto',
    'lastBackupHash',
    'storageAsked',
  ];

  dynamic kv(String key) => _kv[key];
  Future<void> setKv(String key, dynamic value) async {
    _kv[key] = value;
    await _db.putKv(key, value);
    notifyListeners();
  }

  Map<String, List<Map<String, dynamic>>> _tableRows(String key) =>
      switch (key) {
        'clients' => {
          'clients': [
            ...clients,
            ...trashClients,
          ].map((e) => e.toMap()).toList(),
        },
        'docs' => {
          'docs': [...docs, ...trashDocs].map((e) => e.toMap()).toList(),
        },
        'payments' => {
          'payments': [
            ...payments,
            ...trashPayments,
          ].map((e) => e.toMap()).toList(),
        },
        'claims' => {
          'claims': [...claims, ...trashClaims].map((e) => e.toMap()).toList(),
        },
        _ => const {},
      };

  /// حفظ جدول أو أكثر في **معاملة واحدة** (الكل أو لا شيء)
  Future<void> _saveAll(Iterable<String> keys) async {
    final tables = <String, List<Map<String, dynamic>>>{};
    for (final k in keys) {
      if (k == 'org') {
        _kv['org'] = org.toMap();
        await _db.putKv('org', org.toMap());
      } else {
        tables.addAll(_tableRows(k));
      }
    }
    if (tables.isNotEmpty) await _db.replaceTables(tables);
    notifyListeners();
    _scheduleAutoBackup();
  }

  Future<void> _save(String key) => _saveAll([key]);

  /* ---------- النسخ الاحتياطي التلقائي إلى مجلد الهاتف ---------- */
  Timer? _backupTimer;

  /// آخر نسخة ناجحة (مسار الملف) — للعرض في الإعدادات
  String? lastAutoBackupPath;
  DateTime? lastAutoBackupAt;

  bool get autoBackupEnabled => (_kv['autoBackup'] as bool?) ?? true;
  Future<void> setAutoBackup(bool v) async {
    await setKv('autoBackup', v);
    if (v) _scheduleAutoBackup();
  }

  /// بعد أي تغيير: ننتظر 4 ثوانٍ (لتجميع التعديلات المتتالية) ثم نحدّث نسخة اليوم
  void _scheduleAutoBackup() {
    if (!FileService.supported || !autoBackupEnabled) return;
    _backupTimer?.cancel();
    _backupTimer = Timer(
      const Duration(seconds: 4),
      () => backupNow(auto: true),
    );
  }

  /// كتابة نسخة احتياطية مُتحقَّق منها إلى مجلد الهاتف الآن. تعيد المسار أو null
  Future<String?> backupNow({bool auto = false}) async {
    if (!FileService.supported) return null;
    // لا نكتب نسخة لقاعدة فارغة تلقائيًا (قد تكون بعد مسح مقصود)
    if (auto && isEmpty) return null;
    final r = await BackupService.writeLocal(this, auto: auto);
    if (r != null) {
      lastAutoBackupPath = r;
      lastAutoBackupAt = DateTime.now();
      notifyListeners();
    }
    return r;
  }

  bool get isEmpty =>
      clients.isEmpty && docs.isEmpty && payments.isEmpty && claims.isEmpty;

  /// 2026-05-09_14-35
  static String backupStamp([DateTime? t]) {
    final n = t ?? DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}-${two(n.month)}-${two(n.day)}_${two(n.hour)}-${two(n.minute)}';
  }

  @override
  void dispose() {
    _backupTimer?.cancel();
    super.dispose();
  }

  /* ---------- الاستعلامات ---------- */
  List<Invoice> get invoices =>
      docs.where((d) => d.kind == DocKind.invoice).toList()..sort(_byDateDesc);
  List<Invoice> get quotes =>
      docs.where((d) => d.kind == DocKind.quotation).toList()
        ..sort(_byDateDesc);

  int _byDateDesc(Invoice a, Invoice b) {
    final c = b.issueDate.compareTo(a.issueDate);
    return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
  }

  Client? client(String id) => clients.where((c) => c.id == id).firstOrNull;
  Invoice? doc(String id) => docs.where((d) => d.id == id).firstOrNull;

  List<Invoice> clientInvoices(String clientId) =>
      invoices.where((i) => i.clientId == clientId).toList();
  List<Payment> clientPayments(String clientId) =>
      payments.where((p) => p.clientId == clientId).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
  List<Invoice> clientQuotes(String clientId) =>
      quotes.where((q) => q.clientId == clientId).toList();

  /// اسم العميل الظاهر في المستند (عميل مسجّل أو عرض سريع)
  String docClientName(Invoice d) =>
      d.clientName.trim().isEmpty ? 'عميل' : d.clientName.trim();

  /// أسماء ملفات المشاركة/الحفظ الموحّدة (ملاحظة 11د)
  /// فاتورة INV-0005 - اسم العميل.pdf / عرض سعر QT-0001 - اسم العميل.pdf
  String docFileName(Invoice d) =>
      '${d.isQuote ? 'عرض سعر' : 'فاتورة'} ${d.number} - ${docClientName(d)}.pdf';

  /// سند قبض REC-0001 - اسم العميل.pdf
  String receiptFileName(Payment p) {
    final c = client(p.clientId);
    return 'سند قبض ${p.receiptNumber} - ${c?.name.trim().isNotEmpty == true ? c!.name.trim() : 'عميل'}.pdf';
  }

  /// كشف حساب - اسم العميل - التاريخ.pdf
  String statementFileName(Client c, {String? date, bool detailed = false}) =>
      '${detailed ? 'كشف حساب تفصيلي' : 'كشف حساب'} - ${c.name.trim()} - ${date ?? todayISO()}.pdf';

  /// إشعار تسليم - رقم الفاتورة - اسم العميل.pdf
  String deliveryFileName(Invoice d) =>
      'إشعار تسليم - ${d.number} - ${docClientName(d)}.pdf';

  ClientSummary summary(Client c) => clientSummary(c, docs, payments);

  /// مؤشرات الرئيسية
  ({int outstanding, int billed, int collected, int thisMonth, int overdue})
  get kpis {
    var billed = 0, collected = 0, thisMonth = 0, overdue = 0, opening = 0;
    final ym = todayISO().substring(0, 7);
    for (final c in clients) {
      opening += c.openingBalance;
    }
    for (final i in invoices) {
      if (!i.countsInLedger) continue;
      final t = i.totals.total;
      billed += t;
      collected += i.deposit;
      if (i.issueDate.startsWith(ym)) thisMonth += t;
      if (computeStatus(i, payments) != InvoiceStatus.paid) overdue++;
    }
    final liveIds = docs
        .where((d) => d.countsInLedger)
        .map((d) => d.id)
        .toSet();
    for (final p in payments) {
      if (p.invoiceId.isEmpty || liveIds.contains(p.invoiceId)) {
        collected += p.amount;
      }
    }
    return (
      outstanding: opening + billed - collected,
      billed: billed,
      collected: collected,
      thisMonth: thisMonth,
      overdue: overdue,
    );
  }

  /* ---------- الترقيم (ملاحظة 11ج) ---------- */
  /// يشمل المحذوفات حتى لا يتكرر رقم مستند في السلة
  Iterable<Invoice> get _allDocs => [...docs, ...trashDocs];

  String nextNumber(DocKind kind) {
    final prefix = kind == DocKind.invoice ? org.invPrefix : org.quotePrefix;
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    if (org.numberingMode == 'datetime') {
      // INV-20260509-143522 — فريد بطبيعته؛ نضيف لاحقة إن تكرّر في نفس الثانية
      final base =
          '$prefix${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}${two(now.second)}';
      var n = base;
      var k = 1;
      while (_allDocs.any((d) => d.number == n)) {
        n = '$base-${k++}';
      }
      return n;
    }
    // تسلسلي: بادئة [+ سنة-] + رقم يبدأ من "يبدأ من"
    final yearPart = org.numberYear ? '${now.year}-' : '';
    var max = org.invStart - 1;
    for (final d in _allDocs.where((d) => d.kind == kind)) {
      if (org.numberYear && !d.number.startsWith('$prefix$yearPart')) {
        continue; // التسلسل يبدأ من جديد كل سنة
      }
      final m = RegExp(r'(\d+)\s*$').firstMatch(d.number);
      final n = m == null ? null : int.tryParse(m[1]!);
      if (n != null && n > max) max = n;
    }
    return '$prefix$yearPart${(max + 1).toString().padLeft(org.invPad, '0')}';
  }

  /// مثال حي للرقم التالي (لشاشة الإعدادات)
  String previewNumber(Org o, DocKind kind) {
    final saved = org;
    org = o;
    try {
      return nextNumber(kind);
    } finally {
      org = saved;
    }
  }

  String nextReceiptNumber() {
    var max = 0;
    for (final p in [...payments, ...trashPayments]) {
      final m = RegExp(r'REC-(\d+)').firstMatch(p.receiptNumber);
      final n = m == null ? null : int.tryParse(m[1]!);
      if (n != null && n > max) max = n;
    }
    return 'REC-${(max + 1).toString().padLeft(4, '0')}';
  }

  /// رقم الكشف: SOA-سنةشهر-رمز ثابت للعميل
  /// (مشتق من معرّف العميل فلا يتغير بحذف أو إضافة عملاء آخرين)
  String statementNumber(Client c) {
    final d = todayISO();
    var h = 0;
    for (final u in c.id.codeUnits) {
      h = (h * 31 + u) & 0x7fffffff;
    }
    final code = (h % 900 + 100).toString();
    return 'SOA-${d.substring(0, 4)}${d.substring(5, 7)}-$code';
  }

  /* ---------- العملاء ---------- */
  Future<void> saveClient(Client c) async {
    c.updatedAt = DateTime.now().toIso8601String();
    final i = clients.indexWhere((x) => x.id == c.id);
    if (i >= 0) {
      clients[i] = c;
      for (final d in docs.where((d) => d.clientId == c.id)) {
        d.clientName = c.name;
      }
      await _saveAll(['docs', 'clients']);
    } else {
      clients.add(c);
      await _save('clients');
    }
  }

  /// حذف عميل = نقله مع مستنداته ودفعاته إلى سلة المحذوفات (يمكن استرجاعه 30 يومًا)
  Future<void> deleteClient(String id) async {
    final stamp = DateTime.now().toIso8601String();
    final c = clients.where((x) => x.id == id).firstOrNull;
    if (c == null) return;
    clients.remove(c);
    trashClients.add(c..deletedAt = stamp);
    for (final d in docs.where((d) => d.clientId == id).toList()) {
      docs.remove(d);
      trashDocs.add(d..deletedAt = stamp);
    }
    for (final p in payments.where((p) => p.clientId == id).toList()) {
      payments.remove(p);
      trashPayments.add(p..deletedAt = stamp);
    }
    for (final cl in claims.where((x) => x.clientId == id).toList()) {
      claims.remove(cl);
      trashClaims.add(cl..deletedAt = stamp);
    }
    await _saveAll(['docs', 'payments', 'claims', 'clients']);
  }

  /* ---------- المستندات ---------- */
  Future<void> saveDoc(Invoice d) async {
    d.updatedAt = DateTime.now().toIso8601String();
    if (d.number.isEmpty) d.number = nextNumber(d.kind);
    final c = client(d.clientId);
    if (c != null) d.clientName = c.name; // العرض السريع يحتفظ باسمه المكتوب
    final i = docs.indexWhere((x) => x.id == d.id);
    if (i >= 0) {
      docs[i] = d;
    } else {
      docs.add(d);
    }
    await _save('docs');
  }

  /// حذف مستند = نقله مع دفعاته المرتبطة إلى سلة المحذوفات
  Future<void> deleteDoc(String id) async {
    final stamp = DateTime.now().toIso8601String();
    final d = docs.where((x) => x.id == id).firstOrNull;
    if (d == null) return;
    docs.remove(d);
    trashDocs.add(d..deletedAt = stamp);
    for (final p in payments.where((p) => p.invoiceId == id).toList()) {
      payments.remove(p);
      trashPayments.add(p..deletedAt = stamp);
    }
    await _saveAll(['payments', 'docs']);
  }

  /// تحويل عرض سعر إلى فاتورة. [clientId] يُمرَّر عند تحويل عرض سريع بعد إنشاء عميل له
  Future<Invoice> convertQuote(Invoice q, {String? clientId}) async {
    final inv = q.copy()
      ..id = uid('i_')
      ..kind = DocKind.invoice
      ..number = ''
      ..issueDate = todayISO()
      ..status = InvoiceStatus.issued.name
      ..terms = org.invoiceTerms
      ..validUntil = ''
      ..convertedTo = '';
    if (clientId != null && clientId.isNotEmpty) {
      inv.clientId = clientId;
      q.clientId = clientId; // يرتبط العرض بالعميل الجديد أيضًا
    }
    inv.items = q.items.map((e) => e.copy()).toList();
    await saveDoc(inv);
    q.status = QuoteStatus.converted.name;
    q.convertedTo = inv.number;
    await saveDoc(q);
    return inv;
  }

  /* ---------- الدفعات ---------- */
  Future<void> savePayment(Payment p) async {
    if (p.receiptNumber.isEmpty) p.receiptNumber = nextReceiptNumber();
    final i = payments.indexWhere((x) => x.id == p.id);
    if (i >= 0) {
      payments[i] = p;
    } else {
      payments.add(p);
    }
    // الدفعة وحالة الفاتورة المرتبطة في معاملة واحدة
    final inv = doc(p.invoiceId);
    if (inv != null && inv.countsInLedger) {
      inv.status = computeStatus(inv, payments).name;
      await _saveAll(['payments', 'docs']);
    } else {
      await _save('payments');
    }
  }

  /// حذف دفعة = نقلها إلى سلة المحذوفات وتحديث حالة الفاتورة
  Future<void> deletePayment(String id) async {
    final p = payments.where((x) => x.id == id).firstOrNull;
    if (p == null) return;
    payments.remove(p);
    trashPayments.add(p..deletedAt = DateTime.now().toIso8601String());
    await _savePaymentAndStatus(p.invoiceId);
  }

  /// الدفعات + حالة الفاتورة المرتبطة في معاملة واحدة (لا حالة معلّقة لو انقطع التطبيق)
  Future<void> _savePaymentAndStatus(String invoiceId) async {
    final inv = doc(invoiceId);
    if (inv != null && inv.countsInLedger) {
      inv.status = computeStatus(inv, payments).name;
      await _saveAll(['payments', 'docs']);
    } else {
      await _save('payments');
    }
  }

  /* ---------- خطابات المطالبة المالية ---------- */
  List<Claim> get claimsSorted => [...claims]
    ..sort((a, b) {
      final c = b.date.compareTo(a.date);
      return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
    });

  Claim? claim(String id) => claims.where((c) => c.id == id).firstOrNull;
  List<Claim> clientClaims(String clientId) =>
      claimsSorted.where((c) => c.clientId == clientId).toList();

  /// الترقيم يتبع نمط الإعدادات (تسلسلي / تاريخ ووقت) ببادئة المطالبة
  String nextClaimNumber() {
    final prefix = org.claimPrefix.isEmpty ? 'CLM-' : org.claimPrefix;
    final all = [...claims, ...trashClaims];
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    if (org.numberingMode == 'datetime') {
      final base =
          '$prefix${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}${two(now.second)}';
      var n = base;
      var k = 1;
      while (all.any((c) => c.number == n)) {
        n = '$base-${k++}';
      }
      return n;
    }
    var max = 0;
    for (final c in all) {
      if (!c.number.startsWith(prefix)) continue;
      final m = RegExp(r'(\d+)\s*$').firstMatch(c.number);
      final n = m == null ? null : int.tryParse(m[1]!);
      if (n != null && n > max) max = n;
    }
    return '$prefix${(max + 1).toString().padLeft(4, '0')}';
  }

  Future<void> saveClaim(Claim c) async {
    c.updatedAt = DateTime.now().toIso8601String();
    if (c.number.isEmpty) c.number = nextClaimNumber();
    final i = claims.indexWhere((x) => x.id == c.id);
    if (i >= 0) {
      claims[i] = c;
    } else {
      claims.add(c);
    }
    await _save('claims');
  }

  Future<void> deleteClaim(String id) async {
    final c = claims.where((x) => x.id == id).firstOrNull;
    if (c == null) return;
    claims.remove(c);
    trashClaims.add(c..deletedAt = DateTime.now().toIso8601String());
    await _save('claims');
  }

  Future<void> restoreClaim(String id) async {
    final c = trashClaims.where((x) => x.id == id).firstOrNull;
    if (c == null) return;
    trashClaims.remove(c);
    claims.add(c..deletedAt = '');
    await _save('claims');
  }

  Future<void> purgeClaim(String id) async {
    trashClaims.removeWhere((c) => c.id == id);
    await _save('claims');
  }

  /// مسودة مطالبة من فواتير العميل: بند لكل فاتورة بمتبقيها (أو إجماليها)
  Claim claimFromInvoices(
    Client c,
    List<Invoice> invs, {
    bool remainingOnly = true,
  }) {
    final items = <ClaimItem>[];
    for (final i in invs) {
      final amt = remainingOnly
          ? invoiceRemaining(i, payments)
          : i.totals.total;
      if (amt <= 0) continue;
      final first = i.items.isEmpty
          ? ''
          : i.items.first.desc.split('\n').first.trim();
      final what = [
        if (first.isNotEmpty) first else 'خدمات ضيافة',
        if (i.eventDate.isNotEmpty) 'بتاريخ ${fmtDate(i.eventDate)}',
        if (i.location.isNotEmpty) '— ${i.location}',
      ].join(' ');
      items.add(
        ClaimItem(
          desc: what,
          amount: amt,
          invoiceId: i.id,
          invoiceNumber: i.number,
        ),
      );
    }
    return Claim(
      clientId: c.id,
      recipient: c.name,
      items: items,
      showRefColumn: true,
    );
  }

  /// سطر اسم الملف: خطاب مطالبة CLM-0001 - الجهة.pdf
  String claimFileName(Claim c) =>
      'خطاب مطالبة ${c.number} - ${c.recipient.trim().isEmpty ? 'جهة' : c.recipient.trim()}.pdf';

  /* ---------- سلة المحذوفات (ملاحظة 8) ---------- */
  int get trashCount =>
      trashClients.length +
      trashDocs.length +
      trashPayments.length +
      trashClaims.length;

  /// الأيام المتبقية قبل الحذف النهائي
  static int daysLeft(String deletedAt) {
    final t = DateTime.tryParse(deletedAt);
    if (t == null) return 0;
    final left = trashDays - DateTime.now().difference(t).inDays;
    return left < 0 ? 0 : left;
  }

  Future<void> restoreClient(String id) async {
    final c = trashClients.where((x) => x.id == id).firstOrNull;
    if (c == null) return;
    final stamp = c.deletedAt;
    trashClients.remove(c);
    clients.add(c..deletedAt = '');
    // نسترجع ما حُذف معه في نفس العملية
    for (final d
        in trashDocs
            .where((d) => d.clientId == id && d.deletedAt == stamp)
            .toList()) {
      trashDocs.remove(d);
      docs.add(d..deletedAt = '');
    }
    for (final p
        in trashPayments
            .where((p) => p.clientId == id && p.deletedAt == stamp)
            .toList()) {
      trashPayments.remove(p);
      payments.add(p..deletedAt = '');
    }
    for (final cl
        in trashClaims
            .where((x) => x.clientId == id && x.deletedAt == stamp)
            .toList()) {
      trashClaims.remove(cl);
      claims.add(cl..deletedAt = '');
    }
    await _saveAll(['clients', 'docs', 'payments', 'claims']);
  }

  Future<void> restoreDoc(String id) async {
    final d = trashDocs.where((x) => x.id == id).firstOrNull;
    if (d == null) return;
    final stamp = d.deletedAt;
    trashDocs.remove(d);
    docs.add(d..deletedAt = '');
    // إن كان عميله في السلة نسترجعه أيضًا حتى لا يبقى المستند بلا عميل
    final tc = trashClients.where((c) => c.id == d.clientId).firstOrNull;
    if (tc != null) {
      trashClients.remove(tc);
      clients.add(tc..deletedAt = '');
    }
    for (final p
        in trashPayments
            .where((p) => p.invoiceId == id && p.deletedAt == stamp)
            .toList()) {
      trashPayments.remove(p);
      payments.add(p..deletedAt = '');
    }
    if (d.countsInLedger) d.status = computeStatus(d, payments).name;
    await _saveAll(['clients', 'payments', 'docs']);
  }

  Future<void> restorePayment(String id) async {
    final p = trashPayments.where((x) => x.id == id).firstOrNull;
    if (p == null) return;
    trashPayments.remove(p);
    payments.add(p..deletedAt = '');
    await _savePaymentAndStatus(p.invoiceId);
  }

  /// حذف نهائي لعنصر واحد
  Future<void> purgeClient(String id) async {
    trashClients.removeWhere((c) => c.id == id);
    trashDocs.removeWhere((d) => d.clientId == id);
    trashPayments.removeWhere((p) => p.clientId == id);
    trashClaims.removeWhere((x) => x.clientId == id);
    await _saveAll(['clients', 'docs', 'payments', 'claims']);
  }

  Future<void> purgeDoc(String id) async {
    trashDocs.removeWhere((d) => d.id == id);
    trashPayments.removeWhere((p) => p.invoiceId == id);
    await _saveAll(['docs', 'payments']);
  }

  Future<void> purgePayment(String id) async {
    trashPayments.removeWhere((p) => p.id == id);
    await _save('payments');
  }

  /// إفراغ السلة كاملة
  Future<void> emptyTrash() async {
    trashClients.clear();
    trashDocs.clear();
    trashPayments.clear();
    trashClaims.clear();
    await _saveAll(['clients', 'docs', 'payments', 'claims']);
  }

  /// الحذف التلقائي لما تجاوز 30 يومًا (يُستدعى عند التشغيل)
  Future<void> purgeExpiredTrash() async {
    bool expired(String at) {
      final t = DateTime.tryParse(at);
      return t == null || DateTime.now().difference(t).inDays >= trashDays;
    }

    final before = trashCount;
    trashClients.removeWhere((c) => expired(c.deletedAt));
    trashDocs.removeWhere((d) => expired(d.deletedAt));
    trashPayments.removeWhere((p) => expired(p.deletedAt));
    trashClaims.removeWhere((x) => expired(x.deletedAt));
    if (trashCount != before) {
      await _db.replaceTables({
        for (final k in ['clients', 'docs', 'payments', 'claims'])
          ..._tableRows(k),
      });
    }
  }

  /* ---------- الإعدادات ---------- */
  Future<void> saveOrg(Org o) async {
    org = o;
    await _save('org');
  }

  /* ---------- الحساب / شاشة الدخول ---------- */
  /// هل اختار المستخدم طريقة الدخول (Google أو بدون تسجيل)؟
  bool get signedIn => ready && ((_kv['signedIn'] as bool?) ?? false);
  String get accountName => ready ? (_kv['accountName'] as String?) ?? '' : '';
  String get accountEmail =>
      ready ? (_kv['accountEmail'] as String?) ?? '' : '';
  String get accountPhoto =>
      ready ? (_kv['accountPhoto'] as String?) ?? '' : '';
  Future<void> setAccount({
    String name = '',
    String email = '',
    String photo = '',
  }) async {
    for (final e in {
      'signedIn': true,
      'accountName': name,
      'accountEmail': email,
      'accountPhoto': photo,
    }.entries) {
      _kv[e.key] = e.value;
      await _db.putKv(e.key, e.value);
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    for (final e in {
      'signedIn': false,
      'accountName': '',
      'accountEmail': '',
      'accountPhoto': '',
    }.entries) {
      _kv[e.key] = e.value;
      await _db.putKv(e.key, e.value);
    }
    notifyListeners();
  }

  String get themeKey => org.theme;
  Future<void> setTheme(String key) async {
    org.theme = key;
    await _save('org');
  }

  /* ---------- النسخ الاحتياطي ---------- */
  /// بيانات النسخة (بلا غلاف التحقق) — BackupService يضيف البصمة والتحقق
  Map<String, dynamic> exportData() => {
    'clients': [...clients, ...trashClients].map((e) => e.toMap()).toList(),
    'docs': [...docs, ...trashDocs].map((e) => e.toMap()).toList(),
    'payments': [...payments, ...trashPayments].map((e) => e.toMap()).toList(),
    'claims': [...claims, ...trashClaims].map((e) => e.toMap()).toList(),
    'org': org.toMap(),
  };

  Map<String, int> get counts => {
    'clients': clients.length,
    'docs': docs.length,
    'payments': payments.length,
    'claims': claims.length,
  };

  String exportJson() => BackupService.encode(this);

  /// يستورد نسخة (يدعم نسخ التطبيق القديم: invoices بدل docs)
  Future<int> importJson(String json) async {
    final m = jsonDecode(json);
    if (m is! Map || m['data'] is! Map) {
      throw const FormatException('ملف غير صالح');
    }
    final data = m['data'] as Map;
    var n = 0;
    // سجل تالف واحد لا يُفشل الاسترجاع كله — نتجاوزه ونكمل
    Iterable<Map> maps(dynamic v) => v is List ? v.whereType<Map>() : const [];
    void upsert<T>(
      List<T> list,
      Iterable<Map> raw,
      T Function(Map) parse,
      String Function(T) id,
    ) {
      for (final r in raw) {
        try {
          final item = parse(r);
          final i = list.indexWhere((x) => id(x) == id(item));
          if (i >= 0) {
            list[i] = item;
          } else {
            list.add(item);
          }
          n++;
        } catch (e) {
          debugPrint('import: skipped corrupt record: $e');
        }
      }
    }

    // نعيد ما في السلة إلى القوائم العامة، ندمج، ثم نفصل المحذوف إلى السلة من جديد
    clients.addAll(trashClients);
    docs.addAll(trashDocs);
    payments.addAll(trashPayments);
    trashClients.clear();
    trashDocs.clear();
    trashPayments.clear();
    claims.addAll(trashClaims);
    trashClaims.clear();
    upsert<Client>(clients, maps(data['clients']), Client.fromMap, (c) => c.id);
    upsert<Invoice>(
      docs,
      [...maps(data['docs']), ...maps(data['invoices'])],
      Invoice.fromMap,
      (d) => d.id,
    );
    upsert<Payment>(
      payments,
      maps(data['payments']),
      Payment.fromMap,
      (p) => p.id,
    );
    upsert<Claim>(claims, maps(data['claims']), Claim.fromMap, (c) => c.id);
    trashClients.addAll(clients.where((c) => c.isDeleted));
    clients.removeWhere((c) => c.isDeleted);
    trashDocs.addAll(docs.where((d) => d.isDeleted));
    docs.removeWhere((d) => d.isDeleted);
    trashPayments.addAll(payments.where((p) => p.isDeleted));
    payments.removeWhere((p) => p.isDeleted);
    trashClaims.addAll(claims.where((c) => c.isDeleted));
    claims.removeWhere((c) => c.isDeleted);
    if (data['org'] is Map) {
      try {
        org = Org.fromMap({...org.toMap(), ...(data['org'] as Map)});
      } catch (e) {
        debugPrint('import: org skipped: $e');
      }
    }
    await _saveAll(['clients', 'docs', 'payments', 'claims', 'org']);
    return n;
  }

  /// مسح البيانات (العملاء/المستندات/الدفعات/الإعدادات).
  /// رمز القفل محفوظ في صندوق منفصل فلا يتأثر. النسخ الاحتياطية في مجلد الهاتف تبقى كذلك.
  Future<void> wipe() async {
    _backupTimer?.cancel();
    clients.clear();
    docs.clear();
    payments.clear();
    trashClients.clear();
    trashDocs.clear();
    trashPayments.clear();
    claims.clear();
    trashClaims.clear();
    org = Org();
    _kv.clear();
    await _db.clearAll();
    notifyListeners();
  }
}
