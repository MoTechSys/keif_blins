/// models.dart — نماذج البيانات والمحاسبة | كيف الضيافة
library;

import 'money.dart';

String uid(String prefix) {
  final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final r = (DateTime.now().hashCode ^ t.hashCode).abs().toRadixString(36);
  return '$prefix$t${r.substring(0, r.length > 4 ? 4 : r.length)}';
}

String todayISO() {
  final d = DateTime.now();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

const arMonths = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];

/// ISO → "2026/8/4"
String fmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final p = iso.split('-');
  if (p.length < 3) return iso;
  // اليوم قد يكون "04" أو "4" أو "04T10:00:00" — نأخذ الأرقام الأولى فقط
  final dayDigits = RegExp(r'^\d{1,2}').firstMatch(p[2])?.group(0) ?? p[2];
  return '${p[0]}/${int.tryParse(p[1]) ?? p[1]}/${int.tryParse(dayDigits) ?? dayDigits}';
}

/// ISO → "أغسطس 2026"
String fmtMonth(String? iso) {
  if (iso == null || iso.length < 7) return '';
  final m = int.tryParse(iso.substring(5, 7)) ?? 1;
  return '${arMonths[(m - 1).clamp(0, 11)]} ${iso.substring(0, 4)}';
}

/* ============================================================
   العميل
   ============================================================ */
class Client {
  String id;
  String name;
  String contact;
  String phone;
  String email;
  String vatNumber;
  String crNumber;
  String address;
  String notes;
  int openingBalance; // هللة (رصيد افتتاحي مستحق)
  /// تاريخ النقل إلى سلة المحذوفات (فارغ = نشط)
  String deletedAt;
  String createdAt;
  String updatedAt;

  Client({
    String? id,
    this.name = '',
    this.contact = '',
    this.phone = '',
    this.email = '',
    this.vatNumber = '',
    this.crNumber = '',
    this.address = '',
    this.notes = '',
    this.openingBalance = 0,
    this.deletedAt = '',
    String? createdAt,
    String? updatedAt,
  })  : id = id ?? uid('c_'),
        createdAt = createdAt ?? DateTime.now().toIso8601String(),
        updatedAt = updatedAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() => {
        'id': id, 'name': name, 'contact': contact, 'phone': phone,
        'email': email, 'vatNumber': vatNumber, 'crNumber': crNumber,
        'address': address, 'notes': notes, 'openingBalance': openingBalance,
        'deletedAt': deletedAt, 'createdAt': createdAt, 'updatedAt': updatedAt,
      };

  bool get isDeleted => deletedAt.isNotEmpty;

  factory Client.fromMap(Map m) => Client(
        id: m['id'] as String?,
        name: (m['name'] ?? '') as String,
        contact: (m['contact'] ?? '') as String,
        phone: (m['phone'] ?? '') as String,
        email: (m['email'] ?? '') as String,
        vatNumber: (m['vatNumber'] ?? '') as String,
        crNumber: (m['crNumber'] ?? '') as String,
        address: (m['address'] ?? '') as String,
        notes: (m['notes'] ?? '') as String,
        openingBalance: (m['openingBalance'] as num?)?.toInt() ?? 0,
        deletedAt: (m['deletedAt'] ?? '') as String,
        createdAt: m['createdAt'] as String?,
        updatedAt: m['updatedAt'] as String?,
      );
}

/* ============================================================
   بند
   ============================================================ */
const unitLabels = ['فترة', 'يوم', 'عدد', 'ساعة', 'شخص', 'وجبة'];

class LineItem {
  String id;
  String desc;
  int unitPrice; // هللة
  double qty;
  String unitLabel;
  int external; // مشتريات خارجية (هللة)

  LineItem({
    String? id,
    this.desc = '',
    this.unitPrice = 0,
    this.qty = 1,
    this.unitLabel = 'فترة',
    this.external = 0,
  }) : id = id ?? uid('li_');

  int get service => roundHalfUp(unitPrice * qty);
  int get total => service + external;

  Map<String, dynamic> toMap() => {
        'id': id, 'desc': desc, 'unitPrice': unitPrice, 'qty': qty,
        'unitLabel': unitLabel, 'external': external,
      };

  factory LineItem.fromMap(Map m) => LineItem(
        id: m['id'] as String?,
        desc: (m['desc'] ?? '') as String,
        unitPrice: (m['unitPrice'] as num?)?.toInt() ?? 0,
        qty: (m['qty'] as num?)?.toDouble() ?? 1,
        unitLabel: (m['unitLabel'] ?? 'فترة') as String,
        external: (m['external'] as num?)?.toInt() ?? 0,
      );

  LineItem copy() => LineItem.fromMap(toMap());
}

/* ============================================================
   الفاتورة / عرض السعر (نفس البنية؛ kind يميّز)
   ============================================================ */
enum DocKind { invoice, quotation }

enum InvoiceStatus { draft, issued, partial, paid, cancelled }

const statusLabel = {
  InvoiceStatus.draft: 'مسودة',
  InvoiceStatus.issued: 'غير مدفوعة',
  InvoiceStatus.partial: 'مدفوعة جزئيًا',
  InvoiceStatus.paid: 'مدفوعة',
  InvoiceStatus.cancelled: 'ملغاة',
};

enum QuoteStatus { draft, sent, accepted, rejected, converted }

const quoteStatusLabel = {
  QuoteStatus.draft: 'مسودة',
  QuoteStatus.sent: 'مُرسل',
  QuoteStatus.accepted: 'مقبول',
  QuoteStatus.rejected: 'مرفوض',
  QuoteStatus.converted: 'حُوّل لفاتورة',
};

class Totals {
  final int services, external, subtotal, discount, vat, vatRateBp, total;
  const Totals({
    required this.services,
    required this.external,
    required this.subtotal,
    required this.discount,
    required this.vat,
    required this.vatRateBp,
    required this.total,
  });
}

class Invoice {
  String id;
  DocKind kind;
  String number;
  String clientId;
  String clientName;
  String issueDate;
  String eventDate;
  String eventDateTo;
  String validUntil; // لعرض السعر
  String location;
  String attendees;
  List<LineItem> items;
  int discount;
  int vatRateBp; // 1500 = 15%
  int deposit;
  String status; // InvoiceStatus.name أو QuoteStatus.name
  String notes;
  String terms;
  String convertedTo; // رقم الفاتورة الناتجة عن عرض السعر
  /// جوال العميل في "العرض السريع" (عرض سعر بلا عميل مسجّل: clientId فارغ)
  String quickPhone;
  /// تاريخ النقل إلى سلة المحذوفات (فارغ = نشط)
  String deletedAt;
  String createdAt;
  String updatedAt;

  Invoice({
    String? id,
    this.kind = DocKind.invoice,
    this.number = '',
    this.clientId = '',
    this.clientName = '',
    String? issueDate,
    this.eventDate = '',
    this.eventDateTo = '',
    this.validUntil = '',
    this.location = '',
    this.attendees = '',
    List<LineItem>? items,
    this.discount = 0,
    this.vatRateBp = 1500,
    this.deposit = 0,
    String? status,
    this.notes = '',
    this.terms = '',
    this.convertedTo = '',
    this.quickPhone = '',
    this.deletedAt = '',
    String? createdAt,
    String? updatedAt,
  })  : id = id ?? uid('i_'),
        issueDate = issueDate ?? todayISO(),
        items = items ?? [],
        status = status ?? 'draft',
        createdAt = createdAt ?? DateTime.now().toIso8601String(),
        updatedAt = updatedAt ?? DateTime.now().toIso8601String();

  bool get isQuote => kind == DocKind.quotation;

  /// عرض سعر سريع: بلا عميل مسجّل (الاسم والجوال داخل العرض فقط)
  bool get isQuick => clientId.isEmpty;
  bool get isDeleted => deletedAt.isNotEmpty;

  Totals get totals {
    var services = 0, external = 0;
    for (final li in items) {
      services += li.service;
      external += li.external;
    }
    final subtotal = services + external;
    // ملاحظة: لا نستخدم clamp(0, 1 << 62) لأن الإزاحة > 31 بت على الويب (dart2js) تعطي 0
    // فيصبح الإجمالي 0.00 دائمًا. الخصم لا يتجاوز المجموع الفرعي أبدًا.
    final afterDiscount = subtotal - discount < 0 ? 0 : subtotal - discount;
    final vat = vatRateBp > 0 ? roundHalfUp(afterDiscount * vatRateBp / 10000) : 0;
    return Totals(
      services: services,
      external: external,
      subtotal: subtotal,
      discount: discount,
      vat: vat,
      vatRateBp: vatRateBp,
      total: afterDiscount + vat,
    );
  }

  InvoiceStatus get invoiceStatus =>
      InvoiceStatus.values.firstWhere((s) => s.name == status, orElse: () => InvoiceStatus.issued);
  QuoteStatus get quoteStatus =>
      QuoteStatus.values.firstWhere((s) => s.name == status, orElse: () => QuoteStatus.draft);

  bool get countsInLedger =>
      !isQuote && invoiceStatus != InvoiceStatus.draft && invoiceStatus != InvoiceStatus.cancelled;

  Map<String, dynamic> toMap() => {
        'id': id, 'kind': kind.name, 'number': number, 'clientId': clientId,
        'clientName': clientName, 'issueDate': issueDate, 'eventDate': eventDate,
        'eventDateTo': eventDateTo, 'validUntil': validUntil, 'location': location,
        'attendees': attendees, 'items': items.map((e) => e.toMap()).toList(),
        'discount': discount, 'vatRateBp': vatRateBp, 'deposit': deposit,
        'status': status, 'notes': notes, 'terms': terms, 'convertedTo': convertedTo,
        'quickPhone': quickPhone, 'deletedAt': deletedAt,
        'createdAt': createdAt, 'updatedAt': updatedAt,
      };

  factory Invoice.fromMap(Map m) => Invoice(
        id: m['id'] as String?,
        kind: (m['kind'] == 'quotation') ? DocKind.quotation : DocKind.invoice,
        number: (m['number'] ?? '') as String,
        clientId: (m['clientId'] ?? '') as String,
        clientName: (m['clientName'] ?? '') as String,
        issueDate: (m['issueDate'] ?? todayISO()) as String,
        eventDate: (m['eventDate'] ?? '') as String,
        eventDateTo: (m['eventDateTo'] ?? '') as String,
        validUntil: (m['validUntil'] ?? '') as String,
        location: (m['location'] ?? '') as String,
        attendees: (m['attendees'] ?? '').toString(),
        items: ((m['items'] as List?) ?? []).map((e) => LineItem.fromMap(e as Map)).toList(),
        discount: (m['discount'] as num?)?.toInt() ?? 0,
        vatRateBp: (m['vatRateBp'] as num?)?.toInt() ?? 1500,
        deposit: (m['deposit'] as num?)?.toInt() ?? 0,
        status: (m['status'] ?? 'draft') as String,
        notes: (m['notes'] ?? '') as String,
        terms: (m['terms'] ?? '') as String,
        convertedTo: (m['convertedTo'] ?? '') as String,
        quickPhone: (m['quickPhone'] ?? '') as String,
        deletedAt: (m['deletedAt'] ?? '') as String,
        createdAt: m['createdAt'] as String?,
        updatedAt: m['updatedAt'] as String?,
      );

  Invoice copy() => Invoice.fromMap(toMap());
}

/* ============================================================
   الدفعات
   ============================================================ */
const payMethods = ['تحويل بنكي', 'نقدًا', 'شبكة', 'شيك', 'أخرى'];

class Payment {
  String id;
  String clientId;
  String invoiceId; // '' = دفعة على الحساب
  int amount;
  String date;
  String method;
  String reference;
  String notes;
  String receiptNumber;
  String deletedAt;
  String createdAt;

  Payment({
    String? id,
    this.clientId = '',
    this.invoiceId = '',
    this.amount = 0,
    String? date,
    this.method = 'تحويل بنكي',
    this.reference = '',
    this.notes = '',
    this.receiptNumber = '',
    this.deletedAt = '',
    String? createdAt,
  })  : id = id ?? uid('p_'),
        date = date ?? todayISO(),
        createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() => {
        'id': id, 'clientId': clientId, 'invoiceId': invoiceId, 'amount': amount,
        'date': date, 'method': method, 'reference': reference, 'notes': notes,
        'receiptNumber': receiptNumber, 'deletedAt': deletedAt, 'createdAt': createdAt,
      };

  bool get isDeleted => deletedAt.isNotEmpty;

  factory Payment.fromMap(Map m) => Payment(
        id: m['id'] as String?,
        clientId: (m['clientId'] ?? '') as String,
        invoiceId: (m['invoiceId'] ?? '') as String,
        amount: (m['amount'] as num?)?.toInt() ?? 0,
        date: (m['date'] ?? todayISO()) as String,
        method: (m['method'] ?? 'تحويل بنكي') as String,
        reference: (m['reference'] ?? '') as String,
        notes: (m['notes'] ?? '') as String,
        receiptNumber: (m['receiptNumber'] ?? '') as String,
        deletedAt: (m['deletedAt'] ?? '') as String,
        createdAt: m['createdAt'] as String?,
      );
}

/* ============================================================
   المحاسبة
   ============================================================ */

/// المدفوع من فاتورة = العربون + الدفعات المخصصة لها
int invoicePaid(Invoice inv, Iterable<Payment> payments) {
  var p = inv.deposit;
  for (final pay in payments) {
    if (pay.invoiceId == inv.id) p += pay.amount;
  }
  return p;
}

int invoiceRemaining(Invoice inv, Iterable<Payment> payments) =>
    inv.totals.total - invoicePaid(inv, payments);

/// الحالة المحسوبة (المسودة والملغاة تبقى كما هي)
InvoiceStatus computeStatus(Invoice inv, Iterable<Payment> payments) {
  final s = inv.invoiceStatus;
  if (s == InvoiceStatus.draft || s == InvoiceStatus.cancelled) return s;
  final total = inv.totals.total;
  final paid = invoicePaid(inv, payments);
  if (total <= 0) return InvoiceStatus.paid;
  if (paid >= total) return InvoiceStatus.paid;
  if (paid > 0) return InvoiceStatus.partial;
  return InvoiceStatus.issued;
}

class ClientSummary {
  final int opening, billed, deposits, payments, paid, outstanding, invoiceCount, unpaidCount;
  const ClientSummary({
    required this.opening,
    required this.billed,
    required this.deposits,
    required this.payments,
    required this.paid,
    required this.outstanding,
    required this.invoiceCount,
    required this.unpaidCount,
  });
}

/// ملخّص العميل — يستثني الدفعات المخصصة لفواتير مسودة/ملغاة
ClientSummary clientSummary(Client c, List<Invoice> allInvoices, List<Payment> allPayments) {
  final inv = allInvoices.where((i) => i.clientId == c.id && i.countsInLedger).toList();
  final liveIds = inv.map((i) => i.id).toSet();
  final pays = allPayments.where((p) =>
      p.clientId == c.id && (p.invoiceId.isEmpty || liveIds.contains(p.invoiceId)));
  var billed = 0, deposits = 0, unpaid = 0;
  for (final i in inv) {
    billed += i.totals.total;
    deposits += i.deposit;
    if (computeStatus(i, allPayments) != InvoiceStatus.paid) unpaid++;
  }
  var payments = 0;
  for (final p in pays) {
    payments += p.amount;
  }
  final paid = deposits + payments;
  return ClientSummary(
    opening: c.openingBalance,
    billed: billed,
    deposits: deposits,
    payments: payments,
    paid: paid,
    outstanding: c.openingBalance + billed - paid,
    invoiceCount: inv.length,
    unpaidCount: unpaid,
  );
}

/* ============================================================
   كشف الحساب
   ============================================================ */
class StatementRow {
  final String date;
  final String type; // 'invoice' | 'payment' | 'opening'
  final String ref;
  final String desc;
  final int debit; // مدين (فواتير)
  final int credit; // دائن (دفعات)
  final int balance;
  const StatementRow({
    required this.date,
    required this.type,
    required this.ref,
    required this.desc,
    required this.debit,
    required this.credit,
    required this.balance,
  });
}

class Statement {
  final String number;
  final String issueDate;
  final String title;
  final Client client;
  final String from;
  final String to;
  final int opening; // الرصيد قبل الفترة (الافتتاحي + حركة ما قبل from)
  final List<StatementRow> rows;
  /// الفواتير الواقعة داخل الفترة (للعرض التفصيلي في PDF الكشف) مرتبة بتاريخ الإصدار
  final List<Invoice> invoices;
  final int billed, paid, closing, count;
  const Statement({
    required this.number,
    required this.issueDate,
    required this.title,
    required this.client,
    required this.from,
    required this.to,
    required this.opening,
    required this.rows,
    this.invoices = const [],
    required this.billed,
    required this.paid,
    required this.closing,
    required this.count,
  });
}

Statement buildStatement({
  required Client client,
  required List<Invoice> invoices,
  required List<Payment> payments,
  String from = '',
  String to = '',
  String number = '',
  String? issueDate,
  String title = 'كشف حساب',
}) {
  final inv = invoices.where((i) => i.clientId == client.id && i.countsInLedger).toList();
  final liveIds = inv.map((i) => i.id).toSet();
  final pays = payments
      .where((p) => p.clientId == client.id && (p.invoiceId.isEmpty || liveIds.contains(p.invoiceId)))
      .toList();

  bool inRange(String d) => (from.isEmpty || d.compareTo(from) >= 0) && (to.isEmpty || d.compareTo(to) <= 0);
  bool before(String d) => from.isNotEmpty && d.compareTo(from) < 0;

  // الرصيد الافتتاحي للفترة
  var opening = client.openingBalance;
  for (final i in inv) {
    if (before(i.issueDate)) opening += i.totals.total - i.deposit;
  }
  for (final p in pays) {
    if (before(p.date)) opening -= p.amount;
  }

  // الحركات داخل الفترة
  final events = <_Ev>[];
  for (final i in inv) {
    if (!inRange(i.issueDate)) continue;
    events.add(_Ev(i.issueDate, 0, 'invoice', i.number, _invDesc(i), i.totals.total, 0));
    if (i.deposit > 0) {
      events.add(_Ev(i.issueDate, 1, 'payment', i.number, 'عربون مستلم — فاتورة ${i.number}', 0, i.deposit));
    }
  }
  for (final p in pays) {
    if (!inRange(p.date)) continue;
    final invNo = inv.where((i) => i.id == p.invoiceId).map((i) => i.number).firstOrNull;
    final d = invNo != null ? 'دفعة (${p.method}) — فاتورة $invNo' : 'دفعة على الحساب (${p.method})';
    events.add(_Ev(p.date, 2, 'payment', p.receiptNumber.isNotEmpty ? p.receiptNumber : p.reference, d, 0, p.amount));
  }
  events.sort((a, b) {
    final c = a.date.compareTo(b.date);
    return c != 0 ? c : a.order.compareTo(b.order);
  });

  var bal = opening;
  var billed = 0, paid = 0, count = 0;
  final rows = <StatementRow>[];
  for (final e in events) {
    bal += e.debit - e.credit;
    billed += e.debit;
    paid += e.credit;
    if (e.type == 'invoice') count++;
    rows.add(StatementRow(
      date: e.date, type: e.type, ref: e.ref, desc: e.desc,
      debit: e.debit, credit: e.credit, balance: bal,
    ));
  }
  return Statement(
    number: number,
    issueDate: issueDate ?? todayISO(),
    title: title,
    client: client,
    from: from,
    to: to,
    opening: opening,
    rows: rows,
    invoices: (inv.where((i) => inRange(i.issueDate)).toList()
      ..sort((a, b) {
        final c = a.issueDate.compareTo(b.issueDate);
        return c != 0 ? c : a.number.compareTo(b.number);
      })),
    billed: billed,
    paid: paid,
    closing: bal,
    count: count,
  );
}

String _invDesc(Invoice i) {
  final b = StringBuffer('فاتورة ${i.number}');
  if (i.eventDate.isNotEmpty) {
    b.write(' — ${fmtDate(i.eventDate)}');
    if (i.eventDateTo.isNotEmpty && i.eventDateTo != i.eventDate) b.write(' إلى ${fmtDate(i.eventDateTo)}');
  }
  if (i.location.isNotEmpty) b.write(' — ${i.location}');
  return b.toString();
}

class _Ev {
  final String date, type, ref, desc;
  final int order, debit, credit;
  _Ev(this.date, this.order, this.type, this.ref, this.desc, this.debit, this.credit);
}

/* ============================================================
   إعدادات المؤسسة (الترويسة)
   ============================================================ */
class Org {
  String name;
  String nameEn;
  String cr;
  String vat;
  String kingdom;
  String city;
  String website;
  String email;
  String phone;
  String bankName;
  String bankAccount;
  String iban;
  bool showStamp;
  bool showWatermark;
  /// تفعيل ضريبة القيمة المضافة في المستندات (من الإعدادات)
  bool vatEnabled;
  /// نسبة الضريبة الافتراضية (نقاط أساس: 1500 = 15%)
  int vatRateBp;
  /// تفعيل حقل الخصم في المستندات
  bool discountEnabled;
  /// إظهار حقل العربون عند إنشاء الفاتورة
  bool depositEnabled;
  /// الثيم: night / dawn / charcoal
  String theme;
  String invPrefix;
  int invPad;
  int invStart;
  String quotePrefix;
  String invoiceTerms;
  String quoteTerms;

  /* ---- الترقيم (ملاحظة 11ج) ----
     'seq'      : تسلسلي  بادئة + رقم يبدأ من invStart  (INV-0001)
     'datetime' : تلقائي من التاريخ والوقت             (INV-20260509-143522)  */
  String numberingMode;
  /// إدراج السنة في الرقم التسلسلي: INV-2026-0001
  bool numberYear;

  /* ---- عناصر المستندات (ملاحظة 11أ): لا يظهر إلا ما فُعِّل ---- */
  bool showBank;        // بيانات البنك و IBAN في التذييل
  bool showVatNumber;   // الرقم الضريبي في الترويسة
  bool showCr;          // السجل التجاري في الترويسة
  bool showTerms;       // صندوق الشروط
  bool showSignatures;  // خانات التوقيع
  bool showTafqit;      // المبلغ كتابةً
  bool showAck;         // إقرار الاستلام في الفاتورة
  bool showRemaining;   // سطر المدفوع/المتبقي في الفاتورة
  bool showEventBlock;  // بطاقة تفاصيل المناسبة

  Org({
    this.name = 'مؤسسة كيف الضيافة',
    this.nameEn = 'KEIF ALDIAFA EST.',
    this.cr = '4030499689',
    this.vat = '',
    this.kingdom = 'المملكة العربية السعودية',
    this.city = 'جدة',
    this.website = 'keifaldiafa.com',
    this.email = 'info@keifaldiafa.com',
    this.phone = '0508252134',
    this.bankName = 'البنك الأهلي السعودي',
    this.bankAccount = '01400017244409',
    this.iban = 'SA7310000001400017244409',
    this.showStamp = true,
    this.showWatermark = true,
    this.vatEnabled = false,
    this.vatRateBp = 1500,
    this.discountEnabled = false,
    this.depositEnabled = true,
    this.theme = 'night',
    this.invPrefix = 'INV-',
    this.invPad = 4,
    this.invStart = 1,
    this.quotePrefix = 'QT-',
    this.invoiceTerms = 'يُعتبر هذا المستند فاتورة رسمية صادرة من مؤسسة كيف الضيافة. تُسدَّد المبالغ المستحقة عبر التحويل البنكي على الحساب المذكور أدناه، مع ذكر رقم الفاتورة في وصف التحويل.',
    this.quoteTerms = 'هذا العرض ساري لمدة 15 يومًا من تاريخه. الأسعار شاملة الخدمة والتجهيز. يُعتمد العرض بتأكيد العميل ودفع العربون، وتُصدر الفاتورة النهائية بعد التنفيذ.',
    this.numberingMode = 'seq',
    this.numberYear = false,
    this.showBank = true,
    this.showVatNumber = false,
    this.showCr = true,
    this.showTerms = true,
    this.showSignatures = true,
    this.showTafqit = true,
    this.showAck = false,
    this.showRemaining = true,
    this.showEventBlock = true,
  });

  Map<String, dynamic> toMap() => {
        'name': name, 'nameEn': nameEn, 'cr': cr, 'vat': vat, 'kingdom': kingdom, 'city': city,
        'website': website, 'email': email, 'phone': phone, 'bankName': bankName,
        'bankAccount': bankAccount, 'iban': iban, 'showStamp': showStamp,
        'showWatermark': showWatermark, 'vatEnabled': vatEnabled, 'vatRateBp': vatRateBp,
        'discountEnabled': discountEnabled, 'depositEnabled': depositEnabled, 'theme': theme,
        'invPrefix': invPrefix, 'invPad': invPad,
        'invStart': invStart, 'quotePrefix': quotePrefix, 'invoiceTerms': invoiceTerms,
        'quoteTerms': quoteTerms,
        'numberingMode': numberingMode, 'numberYear': numberYear,
        'showBank': showBank, 'showVatNumber': showVatNumber, 'showCr': showCr,
        'showTerms': showTerms, 'showSignatures': showSignatures, 'showTafqit': showTafqit,
        'showAck': showAck, 'showRemaining': showRemaining, 'showEventBlock': showEventBlock,
      };

  factory Org.fromMap(Map? m) {
    final d = Org();
    if (m == null) return d;
    String s(String k, String def) => (m[k] as String?)?.trim().isNotEmpty == true ? m[k] as String : def;
    return Org(
      name: s('name', d.name),
      nameEn: s('nameEn', d.nameEn),
      cr: s('cr', d.cr),
      vat: (m['vat'] ?? '') as String,
      kingdom: s('kingdom', d.kingdom),
      city: (m['city'] ?? d.city) as String,
      website: s('website', d.website),
      email: s('email', d.email),
      phone: s('phone', d.phone),
      bankName: s('bankName', d.bankName),
      bankAccount: s('bankAccount', d.bankAccount),
      iban: s('iban', d.iban),
      showStamp: (m['showStamp'] as bool?) ?? true,
      showWatermark: (m['showWatermark'] as bool?) ?? true,
      vatEnabled: (m['vatEnabled'] as bool?) ?? false,
      vatRateBp: (m['vatRateBp'] as num?)?.toInt() ?? 1500,
      discountEnabled: (m['discountEnabled'] as bool?) ?? false,
      depositEnabled: (m['depositEnabled'] as bool?) ?? true,
      theme: (m['theme'] as String?) ?? 'night',
      invPrefix: (m['invPrefix'] ?? d.invPrefix) as String,
      invPad: (m['invPad'] as num?)?.toInt() ?? 4,
      invStart: (m['invStart'] as num?)?.toInt() ?? 1,
      quotePrefix: (m['quotePrefix'] ?? d.quotePrefix) as String,
      invoiceTerms: (m['invoiceTerms'] ?? d.invoiceTerms) as String,
      quoteTerms: (m['quoteTerms'] ?? d.quoteTerms) as String,
      numberingMode: (m['numberingMode'] as String?) ?? 'seq',
      numberYear: (m['numberYear'] as bool?) ?? false,
      showBank: (m['showBank'] as bool?) ?? true,
      showVatNumber: (m['showVatNumber'] as bool?) ?? ((m['vat'] as String?)?.isNotEmpty ?? false),
      showCr: (m['showCr'] as bool?) ?? true,
      showTerms: (m['showTerms'] as bool?) ?? true,
      showSignatures: (m['showSignatures'] as bool?) ?? true,
      showTafqit: (m['showTafqit'] as bool?) ?? true,
      showAck: (m['showAck'] as bool?) ?? false,
      showRemaining: (m['showRemaining'] as bool?) ?? true,
      showEventBlock: (m['showEventBlock'] as bool?) ?? true,
    );
  }

  String get ibanSpaced => iban.replaceAllMapped(RegExp(r'.{4}'), (m) => '${m[0]} ').trim();
}
