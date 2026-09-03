/// store.dart — حالة التطبيق والتخزين المحلي (Hive) | كيف الضيافة
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models.dart';

class Store extends ChangeNotifier {
  static const _boxName = 'keif_diafa';
  late Box _box;

  final List<Client> clients = [];
  final List<Invoice> docs = []; // فواتير + عروض أسعار
  final List<Payment> payments = [];
  Org org = Org();
  bool ready = false;

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
    _load();
    ready = true;
    notifyListeners();
  }

  void _load() {
    clients
      ..clear()
      ..addAll(_list('clients').map((m) => Client.fromMap(m)));
    docs
      ..clear()
      ..addAll(_list('docs').map((m) => Invoice.fromMap(m)));
    payments
      ..clear()
      ..addAll(_list('payments').map((m) => Payment.fromMap(m)));
    final o = _box.get('org');
    org = Org.fromMap(o is Map ? o : null);
  }

  Iterable<Map> _list(String key) {
    final v = _box.get(key);
    if (v is List) return v.whereType<Map>();
    return const [];
  }

  Future<void> _save(String key) async {
    switch (key) {
      case 'clients':
        await _box.put(key, clients.map((e) => e.toMap()).toList());
      case 'docs':
        await _box.put(key, docs.map((e) => e.toMap()).toList());
      case 'payments':
        await _box.put(key, payments.map((e) => e.toMap()).toList());
      case 'org':
        await _box.put(key, org.toMap());
    }
    notifyListeners();
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

  /* ---------- الترقيم ---------- */
  String nextNumber(DocKind kind) {
    final prefix = kind == DocKind.invoice ? org.invPrefix : org.quotePrefix;
    var max = org.invStart - 1;
    for (final d in docs.where((d) => d.kind == kind)) {
      final m = RegExp(r'(\d+)\s*$').firstMatch(d.number);
      if (m != null) {
        final n = int.parse(m[1]!);
        if (n > max) max = n;
      }
    }
    return '$prefix${(max + 1).toString().padLeft(org.invPad, '0')}';
  }

  String nextReceiptNumber() {
    var max = 0;
    for (final p in payments) {
      final m = RegExp(r'REC-(\d+)').firstMatch(p.receiptNumber);
      if (m != null) {
        final n = int.parse(m[1]!);
        if (n > max) max = n;
      }
    }
    return 'REC-${(max + 1).toString().padLeft(4, '0')}';
  }

  String statementNumber(Client c) {
    final d = todayISO();
    final idx = clients.indexWhere((x) => x.id == c.id) + 1;
    return 'SOA-${d.substring(0, 4)}${d.substring(5, 7)}-${idx.toString().padLeft(3, '0')}';
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

  Future<void> deleteClient(String id) async {
    clients.removeWhere((c) => c.id == id);
    docs.removeWhere((d) => d.clientId == id);
    payments.removeWhere((p) => p.clientId == id);
    await _save('docs');
    await _save('payments');
    await _save('clients');
  }

  /* ---------- المستندات ---------- */
  Future<void> saveDoc(Invoice d) async {
    d.updatedAt = DateTime.now().toIso8601String();
    if (d.number.isEmpty) d.number = nextNumber(d.kind);
    final c = client(d.clientId);
    if (c != null) d.clientName = c.name;
    final i = docs.indexWhere((x) => x.id == d.id);
    if (i >= 0) {
      docs[i] = d;
    } else {
      docs.add(d);
    }
    await _save('docs');
  }

  Future<void> deleteDoc(String id) async {
    docs.removeWhere((d) => d.id == id);
    payments.removeWhere((p) => p.invoiceId == id);
    await _save('payments');
    await _save('docs');
  }

  /// تحويل عرض سعر إلى فاتورة
  Future<Invoice> convertQuote(Invoice q) async {
    final inv = q.copy()
      ..id = uid('i_')
      ..kind = DocKind.invoice
      ..number = ''
      ..issueDate = todayISO()
      ..status = InvoiceStatus.issued.name
      ..terms = org.invoiceTerms
      ..validUntil = ''
      ..convertedTo = '';
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

  Future<void> deletePayment(String id) async {
    final p = payments.where((x) => x.id == id).firstOrNull;
    payments.removeWhere((x) => x.id == id);
    await _save('payments');
    if (p != null) {
      final inv = doc(p.invoiceId);
      if (inv != null && inv.countsInLedger) {
        inv.status = computeStatus(inv, payments).name;
        await _save('docs');
      }
    }
  }

  /* ---------- الإعدادات ---------- */
  Future<void> saveOrg(Org o) async {
    org = o;
    await _save('org');
  }

  /* ---------- النسخ الاحتياطي ---------- */
  String exportJson() => jsonEncode({
        'app': 'keif-diafa',
        'schema': 2,
        'exportedAt': DateTime.now().toIso8601String(),
        'data': {
          'clients': clients.map((e) => e.toMap()).toList(),
          'docs': docs.map((e) => e.toMap()).toList(),
          'payments': payments.map((e) => e.toMap()).toList(),
          'org': org.toMap(),
        },
      });

  /// يستورد نسخة (يدعم نسخ التطبيق القديم: invoices بدل docs)
  Future<int> importJson(String json) async {
    final m = jsonDecode(json);
    if (m is! Map || m['data'] is! Map) throw const FormatException('ملف غير صالح');
    final data = m['data'] as Map;
    var n = 0;
    for (final c in (data['clients'] as List? ?? [])) {
      final cl = Client.fromMap(c as Map);
      final i = clients.indexWhere((x) => x.id == cl.id);
      if (i >= 0) {
        clients[i] = cl;
      } else {
        clients.add(cl);
      }
      n++;
    }
    final rawDocs = [...(data['docs'] as List? ?? []), ...(data['invoices'] as List? ?? [])];
    for (final d in rawDocs) {
      final inv = Invoice.fromMap(d as Map);
      final i = docs.indexWhere((x) => x.id == inv.id);
      if (i >= 0) {
        docs[i] = inv;
      } else {
        docs.add(inv);
      }
      n++;
    }
    for (final p in (data['payments'] as List? ?? [])) {
      final pay = Payment.fromMap(p as Map);
      final i = payments.indexWhere((x) => x.id == pay.id);
      if (i >= 0) {
        payments[i] = pay;
      } else {
        payments.add(pay);
      }
      n++;
    }
    if (data['org'] is Map) {
      final old = data['org'] as Map;
      org = Org.fromMap({...org.toMap(), ...old});
    }
    await _save('clients');
    await _save('docs');
    await _save('payments');
    await _save('org');
    return n;
  }

  Future<void> wipe() async {
    clients.clear();
    docs.clear();
    payments.clear();
    await _box.clear();
    notifyListeners();
  }
}
