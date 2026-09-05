/// store.dart — حالة التطبيق والتخزين المحلي (Hive) | كيف الضيافة
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'file_service.dart';
import 'models.dart';

class Store extends ChangeNotifier {
  static const _boxName = 'keif_diafa';
  late Box _box;

  /// القوائم النشطة (كل الشاشات تعتمد عليها)
  final List<Client> clients = [];
  final List<Invoice> docs = []; // فواتير + عروض أسعار
  final List<Payment> payments = [];

  /// سلة المحذوفات (ملاحظة 8): تُحذف نهائيًا تلقائيًا بعد [trashDays] يومًا
  static const trashDays = 30;
  final List<Client> trashClients = [];
  final List<Invoice> trashDocs = [];
  final List<Payment> trashPayments = [];

  Org org = Org();
  bool ready = false;

  /// رسالة خطأ التشغيل (إن فشل فتح قاعدة البيانات) — null يعني لا خطأ
  String? initError;
  bool _hiveInited = false;

  /// للاختبارات: تخطي Hive.initFlutter (يُستدعى Hive.init(path) مسبقًا)
  @visibleForTesting
  static bool skipHiveInit = false;

  Future<void> init() async {
    initError = null;
    try {
      if (!_hiveInited && !skipHiveInit) {
        await Hive.initFlutter();
      }
      _hiveInited = true;
      _box = await Hive.openBox(_boxName);
      _load();
      await purgeExpiredTrash();
      ready = true;
    } catch (e, st) {
      debugPrint('Store.init failed: $e\n$st');
      initError = '$e';
      ready = false;
    }
    notifyListeners();
  }

  void _load() {
    // سجل تالف واحد لا يجب أن يمنع تحميل الباقي
    Iterable<T> safe<T>(String key, T Function(Map) parse) sync* {
      for (final m in _list(key)) {
        try {
          yield parse(m);
        } catch (e) {
          debugPrint('skip corrupt $key record: $e');
        }
      }
    }

    // كل مفتاح يحمل النشط والمحذوف معًا؛ نفصلهما حسب deletedAt
    clients.clear();
    trashClients.clear();
    for (final c in safe('clients', (m) => Client.fromMap(m))) {
      (c.isDeleted ? trashClients : clients).add(c);
    }
    docs.clear();
    trashDocs.clear();
    for (final d in safe('docs', (m) => Invoice.fromMap(m))) {
      (d.isDeleted ? trashDocs : docs).add(d);
    }
    payments.clear();
    trashPayments.clear();
    for (final p in safe('payments', (m) => Payment.fromMap(m))) {
      (p.isDeleted ? trashPayments : payments).add(p);
    }
    final o = _box.get('org');
    try {
      org = Org.fromMap(o is Map ? o : null);
    } catch (_) {
      org = Org();
    }
  }

  Iterable<Map> _list(String key) {
    final v = _box.get(key);
    if (v is List) return v.whereType<Map>();
    return const [];
  }

  Future<void> _save(String key) async {
    switch (key) {
      case 'clients':
        await _box.put(key, [...clients, ...trashClients].map((e) => e.toMap()).toList());
      case 'docs':
        await _box.put(key, [...docs, ...trashDocs].map((e) => e.toMap()).toList());
      case 'payments':
        await _box.put(key, [...payments, ...trashPayments].map((e) => e.toMap()).toList());
      case 'org':
        await _box.put(key, org.toMap());
    }
    notifyListeners();
    _scheduleAutoBackup();
  }

  /* ---------- النسخ الاحتياطي التلقائي إلى مجلد الهاتف ---------- */
  Timer? _backupTimer;

  /// آخر نسخة تلقائية ناجحة (مسار الملف) — للعرض في الإعدادات
  String? lastAutoBackupPath;
  DateTime? lastAutoBackupAt;

  bool get autoBackupEnabled => (_box.get('autoBackup') as bool?) ?? true;
  Future<void> setAutoBackup(bool v) async {
    await _box.put('autoBackup', v);
    notifyListeners();
    if (v) _scheduleAutoBackup();
  }

  /// بعد أي تغيير: ننتظر 4 ثوانٍ (لتجميع التعديلات المتتالية) ثم نكتب نسخة اليوم
  void _scheduleAutoBackup() {
    if (!FileService.supported || !autoBackupEnabled) return;
    _backupTimer?.cancel();
    _backupTimer = Timer(const Duration(seconds: 4), () => backupNow(auto: true));
  }

  /// كتابة نسخة احتياطية إلى مجلد الهاتف الآن. تعيد المسار أو null
  Future<String?> backupNow({bool auto = false}) async {
    if (!FileService.supported) return null;
    // لا نكتب نسخة لقاعدة فارغة تلقائيًا (قد تكون بعد مسح مقصود)
    if (auto && clients.isEmpty && docs.isEmpty && payments.isEmpty) return null;
    // ملاحظة 11ب: اسم النسخة اليدوية بالتاريخ والساعة والدقيقة  keif-backup-2026-05-09_14-35.json
    // النسخة التلقائية: ملف واحد لليوم يُستبدل (auto-2026-05-09.json)
    final name = auto ? 'auto-${todayISO()}.json' : 'keif-backup-${backupStamp()}.json';
    final p = await FileService.saveBackup(exportJson(), name);
    if (p != null) {
      lastAutoBackupPath = p;
      lastAutoBackupAt = DateTime.now();
      if (auto) await FileService.pruneBackups(keep: 14);
      notifyListeners();
    }
    return p;
  }

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
      docs.where((d) => d.kind == DocKind.quotation).toList()..sort(_byDateDesc);

  int _byDateDesc(Invoice a, Invoice b) {
    final c = b.issueDate.compareTo(a.issueDate);
    return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
  }

  Client? client(String id) => clients.where((c) => c.id == id).firstOrNull;
  Invoice? doc(String id) => docs.where((d) => d.id == id).firstOrNull;

  List<Invoice> clientInvoices(String clientId) =>
      invoices.where((i) => i.clientId == clientId).toList();
  List<Payment> clientPayments(String clientId) =>
      payments.where((p) => p.clientId == clientId).toList()..sort((a, b) => b.date.compareTo(a.date));
  List<Invoice> clientQuotes(String clientId) =>
      quotes.where((q) => q.clientId == clientId).toList();

  /// اسم العميل الظاهر في المستند (عميل مسجّل أو عرض سريع)
  String docClientName(Invoice d) => d.clientName.trim().isEmpty ? 'عميل' : d.clientName.trim();

  /// أسماء ملفات المشاركة/الحفظ الموحّدة (ملاحظة 11د)
  /// فاتورة INV-0005 - اسم العميل.pdf / عرض سعر QT-0001 - اسم العميل.pdf
  String docFileName(Invoice d) => '${d.isQuote ? 'عرض سعر' : 'فاتورة'} ${d.number} - ${docClientName(d)}.pdf';

  /// سند قبض REC-0001 - اسم العميل.pdf
  String receiptFileName(Payment p) {
    final c = client(p.clientId);
    return 'سند قبض ${p.receiptNumber} - ${c?.name.trim().isNotEmpty == true ? c!.name.trim() : 'عميل'}.pdf';
  }

  /// كشف حساب - اسم العميل - التاريخ.pdf
  String statementFileName(Client c, {String? date, bool detailed = false}) =>
      '${detailed ? 'كشف حساب تفصيلي' : 'كشف حساب'} - ${c.name.trim()} - ${date ?? todayISO()}.pdf';

  /// إشعار تسليم - رقم الفاتورة - اسم العميل.pdf
  String deliveryFileName(Invoice d) => 'إشعار تسليم - ${d.number} - ${docClientName(d)}.pdf';

  ClientSummary summary(Client c) => clientSummary(c, docs, payments);

  /// مؤشرات الرئيسية
  ({int outstanding, int billed, int collected, int thisMonth, int overdue}) get kpis {
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
    final liveIds = docs.where((d) => d.countsInLedger).map((d) => d.id).toSet();
    for (final p in payments) {
      if (p.invoiceId.isEmpty || liveIds.contains(p.invoiceId)) collected += p.amount;
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
      final base = '$prefix${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}${two(now.second)}';
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
      if (org.numberYear && !d.number.startsWith('$prefix$yearPart')) continue; // التسلسل يبدأ من جديد كل سنة
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
      await _save('docs');
    } else {
      clients.add(c);
    }
    await _save('clients');
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
    await _save('docs');
    await _save('payments');
    await _save('clients');
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
    await _save('payments');
    await _save('docs');
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
    await _save('payments');
    // تحديث حالة الفاتورة المرتبطة
    final inv = doc(p.invoiceId);
    if (inv != null && inv.countsInLedger) {
      inv.status = computeStatus(inv, payments).name;
      await _save('docs');
    }
  }

  /// حذف دفعة = نقلها إلى سلة المحذوفات وتحديث حالة الفاتورة
  Future<void> deletePayment(String id) async {
    final p = payments.where((x) => x.id == id).firstOrNull;
    if (p == null) return;
    payments.remove(p);
    trashPayments.add(p..deletedAt = DateTime.now().toIso8601String());
    await _save('payments');
    await _refreshInvoiceStatus(p.invoiceId);
  }

  Future<void> _refreshInvoiceStatus(String invoiceId) async {
    final inv = doc(invoiceId);
    if (inv != null && inv.countsInLedger) {
      inv.status = computeStatus(inv, payments).name;
      await _save('docs');
    }
  }

  /* ---------- سلة المحذوفات (ملاحظة 8) ---------- */
  int get trashCount => trashClients.length + trashDocs.length + trashPayments.length;

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
    for (final d in trashDocs.where((d) => d.clientId == id && d.deletedAt == stamp).toList()) {
      trashDocs.remove(d);
      docs.add(d..deletedAt = '');
    }
    for (final p in trashPayments.where((p) => p.clientId == id && p.deletedAt == stamp).toList()) {
      trashPayments.remove(p);
      payments.add(p..deletedAt = '');
    }
    await _save('clients');
    await _save('docs');
    await _save('payments');
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
    for (final p in trashPayments.where((p) => p.invoiceId == id && p.deletedAt == stamp).toList()) {
      trashPayments.remove(p);
      payments.add(p..deletedAt = '');
    }
    await _save('clients');
    await _save('payments');
    await _save('docs');
    await _refreshInvoiceStatus(d.id);
  }

  Future<void> restorePayment(String id) async {
    final p = trashPayments.where((x) => x.id == id).firstOrNull;
    if (p == null) return;
    trashPayments.remove(p);
    payments.add(p..deletedAt = '');
    await _save('payments');
    await _refreshInvoiceStatus(p.invoiceId);
  }

  /// حذف نهائي لعنصر واحد
  Future<void> purgeClient(String id) async {
    trashClients.removeWhere((c) => c.id == id);
    trashDocs.removeWhere((d) => d.clientId == id);
    trashPayments.removeWhere((p) => p.clientId == id);
    await _save('clients');
    await _save('docs');
    await _save('payments');
  }

  Future<void> purgeDoc(String id) async {
    trashDocs.removeWhere((d) => d.id == id);
    trashPayments.removeWhere((p) => p.invoiceId == id);
    await _save('docs');
    await _save('payments');
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
    await _save('clients');
    await _save('docs');
    await _save('payments');
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
    if (trashCount != before) {
      await _box.put('clients', [...clients, ...trashClients].map((e) => e.toMap()).toList());
      await _box.put('docs', [...docs, ...trashDocs].map((e) => e.toMap()).toList());
      await _box.put('payments', [...payments, ...trashPayments].map((e) => e.toMap()).toList());
    }
  }

  /* ---------- الإعدادات ---------- */
  Future<void> saveOrg(Org o) async {
    org = o;
    await _save('org');
  }

  /* ---------- الحساب / شاشة الدخول ---------- */
  /// هل اختار المستخدم طريقة الدخول (Google أو بدون تسجيل)؟
  bool get signedIn => ready && ((_box.get('signedIn') as bool?) ?? false);
  String get accountName => ready ? (_box.get('accountName') as String?) ?? '' : '';
  String get accountEmail => ready ? (_box.get('accountEmail') as String?) ?? '' : '';
  String get accountPhoto => ready ? (_box.get('accountPhoto') as String?) ?? '' : '';
  Future<void> setAccount({String name = '', String email = '', String photo = ''}) async {
    await _box.put('signedIn', true);
    await _box.put('accountName', name);
    await _box.put('accountEmail', email);
    await _box.put('accountPhoto', photo);
    notifyListeners();
  }
  Future<void> signOut() async {
    await _box.put('signedIn', false);
    await _box.put('accountName', '');
    await _box.put('accountEmail', '');
    await _box.put('accountPhoto', '');
    notifyListeners();
  }

  String get themeKey => org.theme;
  Future<void> setTheme(String key) async {
    org.theme = key;
    await _save('org');
  }

  /* ---------- النسخ الاحتياطي ---------- */
  String exportJson() => jsonEncode({
        'app': 'keif-diafa',
        'schema': 3,
        'exportedAt': DateTime.now().toIso8601String(),
        'counts': {'clients': clients.length, 'docs': docs.length, 'payments': payments.length},
        'data': {
          'clients': [...clients, ...trashClients].map((e) => e.toMap()).toList(),
          'docs': [...docs, ...trashDocs].map((e) => e.toMap()).toList(),
          'payments': [...payments, ...trashPayments].map((e) => e.toMap()).toList(),
          'org': org.toMap(),
        },
      });

  /// يستورد نسخة (يدعم نسخ التطبيق القديم: invoices بدل docs)
  Future<int> importJson(String json) async {
    final m = jsonDecode(json);
    if (m is! Map || m['data'] is! Map) throw const FormatException('ملف غير صالح');
    final data = m['data'] as Map;
    var n = 0;
    // سجل تالف واحد لا يُفشل الاسترجاع كله — نتجاوزه ونكمل
    Iterable<Map> maps(dynamic v) => v is List ? v.whereType<Map>() : const [];
    void upsert<T>(List<T> list, Iterable<Map> raw, T Function(Map) parse, String Function(T) id) {
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
    upsert<Client>(clients, maps(data['clients']), Client.fromMap, (c) => c.id);
    upsert<Invoice>(docs, [...maps(data['docs']), ...maps(data['invoices'])], Invoice.fromMap, (d) => d.id);
    upsert<Payment>(payments, maps(data['payments']), Payment.fromMap, (p) => p.id);
    trashClients.addAll(clients.where((c) => c.isDeleted));
    clients.removeWhere((c) => c.isDeleted);
    trashDocs.addAll(docs.where((d) => d.isDeleted));
    docs.removeWhere((d) => d.isDeleted);
    trashPayments.addAll(payments.where((p) => p.isDeleted));
    payments.removeWhere((p) => p.isDeleted);
    if (data['org'] is Map) {
      try {
        org = Org.fromMap({...org.toMap(), ...(data['org'] as Map)});
      } catch (e) {
        debugPrint('import: org skipped: $e');
      }
    }
    await _save('clients');
    await _save('docs');
    await _save('payments');
    await _save('org');
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
    org = Org();
    await _box.clear();
    notifyListeners();
  }
}
