/// documents.dart — مولّدات PDF: فاتورة، عرض سعر، كشف حساب، سند قبض | كيف الضيافة
library;

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/models.dart';
import '../core/money.dart';
import 'official_theme.dart';
import 'pdf_theme.dart';

class DocPdf {
  final PdfAssets a;
  final Org org;
  DocPdf(this.a, this.org);

  static Future<DocPdf> create(Org org) async => DocPdf(await PdfAssets.load(), org);

  pw.Document _doc(String title) => pw.Document(
        title: title,
        author: org.name,
        creator: 'كيف الضيافة',
        compress: true,
      );

  /* ==========================================================
     الفاتورة / عرض السعر — التصميم الرسمي البسيط
     ========================================================== */
  Future<Uint8List> invoice(Invoice inv, List<Payment> payments, {Client? client}) async {
    final isQ = inv.isQuote;
    final t = inv.totals;
    // المدفوع = العربون + الدفعات المسجَّلة على الفاتورة
    final extraPaid = isQ ? 0 : payments.where((p) => p.invoiceId == inv.id).fold<int>(0, (s, p) => s + p.amount);
    final deposit = isQ ? 0 : inv.deposit;
    final paid = deposit + extraPaid;
    final remaining = t.total - paid;
    final titleAr = isQ ? 'عرض سعر' : 'فاتورة';
    final label = isQ ? 'عرض سعر رقم ${inv.number}' : 'فاتورة رقم ${inv.number}';
    final hasExt = inv.items.any((i) => i.external > 0);
    final hasDiscount = t.discount > 0;
    final hasVat = t.vatRateBp > 0 && t.vat > 0;
    final showSubtotal = hasDiscount || hasVat;
    final vatPct = t.vatRateBp % 100 == 0 ? '${t.vatRateBp ~/ 100}' : (t.vatRateBp / 100).toStringAsFixed(1);

    final doc = _doc(label);
    doc.addPage(pw.MultiPage(
      pageTheme: officialPageTheme(a, org),
      header: (ctx) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 14),
        child: officialHeader(a, org, badgeLines: [titleAr]),
      ),
      footer: (ctx) => pw.Column(children: [
        pw.SizedBox(height: 8),
        singleRule(width: 0.6),
        pw.SizedBox(height: 10),
        officialFooter(a, org),
        pw.SizedBox(height: 18),
        pw.Center(child: pw.Image(a.certs, height: 26)),
        pw.SizedBox(height: 14),
        officialPageNum(a, ctx),
      ]),
      build: (ctx) => [
        // بيانات العميل (يمين) / بيانات الفاتورة (يسار)
        metaBlock(
          a,
          right: [
            (isQ ? 'مقدَّم إلى: الاسم' : 'بيانات العميل: الاسم', inv.clientName, false),
            if (org.showEventBlock) ('تاريخ الفعالية', _eventRange(inv), true),
            if (org.showEventBlock) ('موقع الفعالية', inv.location, false),
          ],
          left: [
            (isQ ? 'رقم العرض' : 'رقم الفاتورة', inv.number, true),
            ('التاريخ', fmtDate(inv.issueDate), true),
            if (isQ) ('ساري حتى', fmtDate(inv.validUntil), true),
            if (org.showEventBlock) ('عدد الحضور التقريبي', inv.attendees, true),
          ],
        ),
        pw.SizedBox(height: 14),
        _itemsTable(inv, hasExt),
        pw.SizedBox(height: 12),
        // كتلة الإجماليات مثبّتة على يسار الصفحة (كالمرجع): في صف RTL أول عنصر يقع يميناً، لذا الفراغ أولاً
        pw.Row(children: [
          pw.Spacer(),
          pw.SizedBox(
            width: 300,
            child: pw.Column(children: [
              singleRule(width: 1.2),
              pw.SizedBox(height: 8),
              if (hasExt) _sumLine('خدمات الضيافة', fmtSAR(t.services)),
              if (hasExt) _sumLine('مشتريات خارجية', fmtSAR(t.external)),
              if (showSubtotal) _sumLine('المجموع', fmtSAR(t.subtotal)),
              if (hasDiscount) _sumLine('الخصم', '- ${fmtSAR(t.discount)}'),
              if (hasVat) _sumLine('ضريبة القيمة المضافة ($vatPct%)', fmtSAR(t.vat)),
              _sumLine(isQ ? 'الإجمالي' : 'الصافي', fmtSAR(t.total), size: 12.6, black: true),
              if (!isQ && org.showRemaining && deposit > 0) _sumLine('العربون المدفوع', fmtSAR(deposit)),
              if (!isQ && org.showRemaining && extraPaid > 0) _sumLine('المدفوع', fmtSAR(extraPaid)),
              if (!isQ && org.showRemaining && paid > 0)
                _sumLine('المتبقي', fmtSAR(remaining), color: remaining > 0 ? O.red : O.brown, bold: true),
            ]),
          ),
        ]),
        if (inv.notes.trim().isNotEmpty) pw.SizedBox(height: 10),
        if (inv.notes.trim().isNotEmpty)
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('ملاحظات: ', style: a.t(10.2, color: O.brown, bold: true)),
            pw.Expanded(child: pw.Text(inv.notes.trim(), style: a.t(10.2, color: O.ink))),
          ]),
      ],
    ));
    return doc.save();
  }

  String _eventRange(Invoice inv) {
    if (inv.eventDate.isEmpty) return '';
    if (inv.eventDateTo.isNotEmpty && inv.eventDateTo != inv.eventDate) {
      return '${fmtDate(inv.eventDate)} - ${fmtDate(inv.eventDateTo)}';
    }
    return fmtDate(inv.eventDate);
  }

  /// عنوان عمود الكمية حسب وحدة البنود (عدد الأيام / عدد الفترات / الكمية…)
  String _qtyHeader(Invoice inv) {
    if (inv.items.isEmpty) return 'الكمية';
    final u = inv.items.first.unitLabel;
    if (!inv.items.every((i) => i.unitLabel == u)) return 'الكمية';
    return switch (u) {
      'يوم' => 'عدد الأيام',
      'فترة' => 'عدد الفترات',
      'ساعة' => 'عدد الساعات',
      'شخص' => 'عدد الأشخاص',
      'وجبة' => 'عدد الوجبات',
      _ => 'الكمية',
    };
  }

  pw.Widget _itemsTable(Invoice inv, bool hasExt) {
    final qtyHead = _qtyHeader(inv);
    final mixedUnits = qtyHead == 'الكمية';
    // الأعمدة من اليمين: م | الوصف | الكمية | السعر | [مشتريات خارجية] | الإجمالي
    final widths = <int, pw.TableColumnWidth>{
      0: const pw.FixedColumnWidth(24),
      1: const pw.FlexColumnWidth(),
      2: const pw.FixedColumnWidth(69),
      3: const pw.FixedColumnWidth(79),
      if (hasExt) 4: const pw.FixedColumnWidth(72),
      (hasExt ? 5 : 4): const pw.FixedColumnWidth(78),
    };
    final rows = <pw.TableRow>[
      pw.TableRow(repeat: true, decoration: headDeco(), children: [
        oth(a, 'م'),
        oth(a, 'الوصف'),
        oth(a, qtyHead),
        oth(a, 'السعر'),
        if (hasExt) oth(a, 'مشتريات خارجية'),
        oth(a, 'الإجمالي'),
      ]),
    ];
    var i = 0;
    for (final li in inv.items) {
      i++;
      rows.add(pw.TableRow(children: [
        otd(a, '$i', ltr: true),
        _descCell(li.desc),
        otd(a, '${fmtQty(li.qty)}${mixedUnits ? ' ${li.unitLabel}' : ''}', ltr: !mixedUnits),
        otd(a, fmtSAR(li.unitPrice)),
        if (hasExt) otd(a, li.external > 0 ? fmtSAR(li.external) : '—'),
        otd(a, fmtSAR(li.total)),
      ]));
    }
    if (inv.items.isEmpty) {
      rows.add(pw.TableRow(children: [
        pw.SizedBox(),
        otd(a, 'لا توجد بنود', align: pw.Alignment.centerRight),
        pw.SizedBox(),
        pw.SizedBox(),
        if (hasExt) pw.SizedBox(),
        pw.SizedBox(),
      ]));
    }
    return officialTable(columnWidths: widths, children: rows);
  }

  /// خلية الوصف: السطر الأول عريض، والأسطر التالية عادية مسبوقة بشرطة.
  pw.Widget _descCell(String desc) {
    final lines = desc.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (lines.isEmpty) return otd(a, '', align: pw.Alignment.centerRight);
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(lines.first, style: a.t(10.8, color: O.ink, bold: true)),
        for (final l in lines.skip(1))
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 3),
            child: pw.Text(l.startsWith('-') ? l : '- $l', style: a.t(10.2, color: O.ink)),
          ),
      ]),
    );
  }

  /// سطر إجمالي: التسمية يمين والقيمة يسار (LTR للأرقام)
  pw.Widget _sumLine(String label, String value, {double size = 10.8, bool bold = false, bool black = false, PdfColor color = O.ink}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Row(children: [
          pw.Text(label, style: a.t(size, color: color, bold: bold, black: black)),
          pw.Spacer(),
          pw.Text(value, style: a.t(size, color: color, bold: bold, black: black)),
        ]),
      );

  /* ==========================================================
     كشف الحساب — الهيكلية الكلاسيكية مدين/دائن/رصيد (متعدد الصفحات)
     ========================================================== */
  Future<Uint8List> statement(Statement s) async {
    final label = 'كشف حساب ${s.number}';
    final period = s.from.isEmpty && s.to.isEmpty
        ? 'كل الفترات'
        : 'من ${s.from.isEmpty ? 'البداية' : fmtDate(s.from)} إلى ${s.to.isEmpty ? fmtDate(s.issueDate) : fmtDate(s.to)}';
    final doc = _doc(label);
    String money(int h) => fmt(h, trimZeros: true);
    String bal(int v) => v < 0 ? '(${money(-v)})' : money(v);

    // الهيكلية الكلاسيكية لكشف الحساب: جدول واحد مدين/دائن/رصيد متجدد يبدأ برصيد افتتاحي
    final widths = <int, pw.TableColumnWidth>{
      0: const pw.FixedColumnWidth(24), // م
      1: const pw.FixedColumnWidth(60), // التاريخ
      2: const pw.FixedColumnWidth(64), // المرجع
      3: const pw.FlexColumnWidth(), // البيان
      4: const pw.FixedColumnWidth(70), // مدين
      5: const pw.FixedColumnWidth(70), // دائن
      6: const pw.FixedColumnWidth(78), // الرصيد
    };
    final rows = <pw.TableRow>[
      pw.TableRow(repeat: true, decoration: headDeco(), children: [
        oth(a, 'م', size: 10),
        oth(a, 'التاريخ', size: 10),
        oth(a, 'المرجع', size: 10),
        oth(a, 'البيان', size: 10),
        oth(a, 'مدين\n(فواتير)', size: 10),
        oth(a, 'دائن\n(دفعات)', size: 10),
        oth(a, 'الرصيد\n(ر.س)', size: 10),
      ]),
      // سطر «رصيد سابق» يظهر فقط عند وجود رصيد مُرحَّل من قبل الفترة المختارة (وإلا يبدأ الكشف بالحركات مباشرة)
      if (s.opening != 0)
        pw.TableRow(decoration: const pw.BoxDecoration(color: O.headFill), children: [
          otd(a, '', size: 9.8, vPad: 7),
          otd(a, s.from.isEmpty ? '' : fmtDate(s.from), size: 9.8, ltr: true, vPad: 7),
          otd(a, '', size: 9.8, vPad: 7),
          otd(a, 'رصيد سابق قبل الفترة', align: pw.Alignment.centerRight, size: 9.8, bold: true, color: O.brown, vPad: 7),
          otd(a, '', size: 9.8, vPad: 7),
          otd(a, '', size: 9.8, vPad: 7),
          otd(a, bal(s.opening), size: 9.8, ltr: true, bold: true, color: O.brown, vPad: 7),
        ]),
    ];
    var n = 0;
    for (final r in s.rows) {
      n++;
      final isInv = r.type == 'invoice';
      rows.add(pw.TableRow(
        decoration: n.isEven ? const pw.BoxDecoration(color: O.zebra) : null,
        children: [
          otd(a, '$n', size: 9.8, vPad: 7),
          otd(a, fmtDate(r.date), size: 9.8, ltr: true, vPad: 7),
          otd(a, r.ref, size: 9.4, ltr: true, vPad: 7),
          otd(a, r.desc, align: pw.Alignment.centerRight, size: 9.8, vPad: 7),
          otd(a, isInv ? money(r.debit) : '', size: 9.8, ltr: true, color: O.red, vPad: 7),
          otd(a, !isInv ? money(r.credit) : '', size: 9.8, ltr: true, color: O.green, bold: true, vPad: 7),
          otd(a, bal(r.balance), size: 9.8, ltr: true, bold: true, vPad: 7),
        ],
      ));
    }
    if (s.rows.isEmpty) {
      rows.add(pw.TableRow(children: [
        for (var k = 0; k < 7; k++) k == 3 ? otd(a, 'لا توجد حركات خلال الفترة', size: 9.8) : pw.SizedBox(),
      ]));
    }
    rows.add(pw.TableRow(decoration: headDeco(), children: [
      pw.SizedBox(),
      pw.SizedBox(),
      pw.SizedBox(),
      otd(a, 'الإجمالي', align: pw.Alignment.centerRight, size: 10.2, bold: true, vPad: 7),
      otd(a, money(s.billed), size: 10.2, ltr: true, bold: true, color: O.red, vPad: 7),
      otd(a, money(s.paid), size: 10.2, ltr: true, bold: true, color: O.green, vPad: 7),
      otd(a, bal(s.closing), size: 10.2, ltr: true, bold: true, vPad: 7),
    ]));

    final due = s.closing;
    final dueLabel = due > 0 ? 'الرصيد المستحق' : (due < 0 ? 'رصيد دائن للعميل' : 'الرصيد');
    final badgeStatus = due > 0 ? 'مستحق: ${money(due)} ر.س' : (due < 0 ? 'دائن: ${money(-due)} ر.س' : 'لا مستحقات');

    doc.addPage(pw.MultiPage(
      pageTheme: officialPageTheme(a, org, leaves: true),
      header: (ctx) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 10),
        child: officialHeader(a, org, badgeLines: ['كشف حساب', badgeStatus]),
      ),
      footer: (ctx) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 8),
        child: officialPageNum(a, ctx, prefix: '$label — ${s.client.name}'),
      ),
      build: (ctx) => [
        metaBlock(
          a,
          size: 10.4,
          right: [
            ('العميل', s.client.name, false),
            ('جهة الاتصال', s.client.contact, false),
            ('الهاتف', s.client.phone, true),
            ('الرقم الضريبي', s.client.vatNumber, true),
          ],
          left: [
            ('رقم الكشف', s.number, true),
            ('تاريخ الإصدار', fmtDate(s.issueDate), true),
            ('الفترة', period, false),
            ('عدد الفواتير', '${s.count}', true),
          ],
        ),
        pw.SizedBox(height: 10),
        officialTable(columnWidths: widths, children: rows),
        pw.SizedBox(height: 10),
        // ملخص الحساب على يسار الصفحة (كالفاتورة)
        pw.Row(children: [
          pw.Spacer(),
          pw.SizedBox(
            width: 300,
            child: pw.Column(children: [
              if (s.opening != 0) _soaLine('رصيد سابق قبل الفترة', '${bal(s.opening)} ر.س'),
              _soaLine('إجمالي الفواتير', '${money(s.billed)} ر.س'),
              _soaLine('إجمالي المدفوعات', '${money(s.paid)} ر.س'),
            ]),
          ),
        ]),
        pw.SizedBox(height: 4),
        pw.Row(children: [
          pw.Spacer(),
          pw.SizedBox(width: 300, child: singleRule(width: 1.2)),
        ]),
        pw.SizedBox(height: 8),
        pw.Row(children: [
          pw.Spacer(),
          pw.SizedBox(
            width: 300,
            child: pw.Row(children: [
              pw.Text(dueLabel, style: a.t(14.4, color: O.brown, black: true)),
              pw.Spacer(),
              pw.Text('${money(due.abs())} ر.س', style: a.t(14.4, color: due > 0 ? O.red : O.brown, black: true)),
            ]),
          ),
        ]),
        if (org.showTafqit && due != 0) pw.SizedBox(height: 4),
        if (org.showTafqit && due != 0)
          pw.Row(children: [
            pw.Spacer(),
            pw.SizedBox(
              width: 360,
              child: pw.Text(tafqit(due.abs()), style: a.t(11.2, color: O.ink, bold: true), textAlign: pw.TextAlign.right),
            ),
          ]),
        if (org.showTerms) pw.SizedBox(height: 8),
        if (org.showTerms)
          pw.Text(
            due > 0
                ? 'ملاحظة: نأمل تسوية الرصيد المستحق عبر التحويل البنكي على الحساب المذكور أدناه مع ذكر رقم الكشف. للاستفسار عن أي حركة يرجى التواصل معنا.'
                : 'ملاحظة: حسابكم مسدَّد بالكامل حتى تاريخ هذا الكشف. نشكر لكم حسن تعاونكم.',
            style: a.t(10, color: O.ink),
          ),
        pw.SizedBox(height: 10),
        singleRule(),
        pw.SizedBox(height: 16),
        officialFooter(a, org, website: true),
      ],
    ));
    return doc.save();
  }

  pw.Widget _soaLine(String label, String value, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.Row(children: [
          pw.Text(label, style: a.t(10.8, color: O.ink, bold: bold)),
          pw.Spacer(),
          pw.Text(value, style: a.t(10.8, color: O.ink, bold: bold)),
        ]),
      );

  /* ==========================================================
     كشف حساب تفصيلي — بطاقة لكل فاتورة: بنودها كاملة، دفعاتها، إجمالياتها وحالتها
     ========================================================== */
  Future<Uint8List> statementDetailed(Statement s, List<Payment> allPayments) async {
    final label = 'كشف حساب تفصيلي ${s.number}';
    final period = s.from.isEmpty && s.to.isEmpty
        ? 'كل الفترات'
        : 'من ${s.from.isEmpty ? 'البداية' : fmtDate(s.from)} إلى ${s.to.isEmpty ? fmtDate(s.issueDate) : fmtDate(s.to)}';
    final doc = _doc(label);
    String money(int h) => fmt(h, trimZeros: true);
    bool inRange(String d) => (s.from.isEmpty || d.compareTo(s.from) >= 0) && (s.to.isEmpty || d.compareTo(s.to) <= 0);

    final pays = allPayments.where((p) => p.clientId == s.client.id && !p.isDeleted).toList()
      ..sort((x, y) {
        final c = x.date.compareTo(y.date);
        return c != 0 ? c : x.createdAt.compareTo(y.createdAt);
      });
    final onAccount = pays.where((p) => p.invoiceId.isEmpty && inRange(p.date)).toList();

    final due = s.closing;
    final badgeStatus = due > 0 ? 'مستحق: ${money(due)} ر.س' : (due < 0 ? 'دائن: ${money(-due)} ر.س' : 'لا مستحقات');

    // إجماليات حالة الفواتير للملخص
    var cntPaid = 0, cntPartial = 0, cntUnpaid = 0, sumDeposits = 0, sumPays = 0, sumBilled = 0;

    final body = <pw.Widget>[
      metaBlock(
        a,
        size: 10.4,
        right: [
          ('العميل', s.client.name, false),
          ('جهة الاتصال', s.client.contact, false),
          ('الهاتف', s.client.phone, true),
          ('الرقم الضريبي', s.client.vatNumber, true),
        ],
        left: [
          ('رقم الكشف', s.number, true),
          ('تاريخ الإصدار', fmtDate(s.issueDate), true),
          ('الفترة', period, false),
          ('عدد الفواتير', '${s.count}', true),
        ],
      ),
      pw.SizedBox(height: 4),
    ];

    if (s.invoices.isEmpty) {
      body.add(pw.Container(
        padding: const pw.EdgeInsets.all(14),
        decoration: cardDeco(),
        child: pw.Center(child: pw.Text('لا توجد فواتير خلال الفترة', style: a.t(10.8, color: O.ink))),
      ));
    }

    var n = 0;
    for (final inv in s.invoices) {
      n++;
      final invPays = pays.where((p) => p.invoiceId == inv.id).toList();
      final t = inv.totals;
      final extraPaid = invPays.fold<int>(0, (x, p) => x + p.amount);
      final paid = inv.deposit + extraPaid;
      final remaining = t.total - paid;
      final st = computeStatus(inv, invPays);
      final stLabel = statusLabel[st] ?? '';
      final stColor = st == InvoiceStatus.paid ? O.green : (st == InvoiceStatus.partial ? O.gold : O.red);
      if (st == InvoiceStatus.paid) {
        cntPaid++;
      } else if (st == InvoiceStatus.partial) {
        cntPartial++;
      } else {
        cntUnpaid++;
      }
      // الملخص يخص الفترة فقط: العربون بتاريخ الفاتورة (داخل الفترة حتمًا)، والدفعات داخل الفترة فقط
      // كي تتطابق معادلة الملخص مع كشف الحساب المختصر؛ أما بطاقة الفاتورة فتعرض كل دفعاتها لتعكس حالتها الفعلية.
      sumDeposits += inv.deposit;
      sumPays += invPays.where((p) => inRange(p.date)).fold<int>(0, (x, p) => x + p.amount);
      sumBilled += t.total;

      final hasExt = inv.items.any((i) => i.external > 0);
      final hasDiscount = t.discount > 0;
      final hasVat = t.vatRateBp > 0 && t.vat > 0;
      final vatPct = t.vatRateBp % 100 == 0 ? '${t.vatRateBp ~/ 100}' : (t.vatRateBp / 100).toStringAsFixed(1);
      final qtyHead = _qtyHeader(inv);
      final mixedUnits = qtyHead == 'الكمية';
      final meta = <(String, String, bool)>[
        if (inv.eventDate.isNotEmpty) ('تاريخ الفعالية', _eventRange(inv), true),
        if (inv.location.isNotEmpty) ('الموقع', inv.location, false),
        if (inv.attendees.isNotEmpty) ('عدد الحضور', inv.attendees, true),
      ];

      // ---- 1) شريط عنوان البطاقة
      final header = cardHeader([
        pw.Text('$n', style: a.t(11, color: O.brown, black: true)),
        pw.Text('.  فاتورة رقم ', style: a.t(11, color: O.brown, black: true)),
        pw.Text(inv.number, style: a.t(11, color: O.brown, black: true), textDirection: pw.TextDirection.ltr),
        pw.SizedBox(width: 14),
        pw.Text('التاريخ: ', style: a.t(10, color: O.brown, bold: true)),
        pw.Text(fmtDate(inv.issueDate), style: a.t(10, color: O.ink), textDirection: pw.TextDirection.ltr),
        pw.Spacer(),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 2.5),
          decoration: pw.BoxDecoration(color: O.white, border: pw.Border.all(color: stColor, width: 1), borderRadius: pw.BorderRadius.circular(3)),
          child: pw.Text(stLabel, style: a.t(9.6, color: stColor, bold: true)),
        ),
      ]);

      // ---- 2) بيانات الفعالية (إن وُجدت)
      final metaLine = meta.isEmpty
          ? null
          : pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(8, 6, 8, 2),
              child: pw.Wrap(spacing: 18, runSpacing: 2, children: [
                for (final e in meta)
                  pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
                    pw.Text('${e.$1}: ', style: a.t(9.8, color: O.brown, bold: true)),
                    pw.Text(e.$2, style: a.t(9.8, color: O.ink), textDirection: e.$3 ? pw.TextDirection.ltr : null),
                  ]),
              ]),
            );

      // ---- 3) جدول البنود (نفس أعمدة الفاتورة ووصفها الكامل)
      final iw = <int, pw.TableColumnWidth>{
        0: const pw.FixedColumnWidth(24),
        1: const pw.FlexColumnWidth(),
        2: const pw.FixedColumnWidth(66),
        3: const pw.FixedColumnWidth(76),
        if (hasExt) 4: const pw.FixedColumnWidth(72),
        (hasExt ? 5 : 4): const pw.FixedColumnWidth(80),
      };
      final irows = <pw.TableRow>[
        pw.TableRow(repeat: true, decoration: headDeco(), children: [
          oth(a, 'م', size: 9.8),
          oth(a, 'الوصف', size: 9.8),
          oth(a, qtyHead, size: 9.8),
          oth(a, 'السعر', size: 9.8),
          if (hasExt) oth(a, 'مشتريات خارجية', size: 9.8),
          oth(a, 'الإجمالي', size: 9.8),
        ]),
      ];
      var k = 0;
      for (final li in inv.items) {
        k++;
        irows.add(pw.TableRow(decoration: k.isEven ? const pw.BoxDecoration(color: O.zebra) : null, children: [
          otd(a, '$k', size: 9.6, ltr: true, vPad: 6),
          _descCellSized(li.desc, 9.9, 9.4),
          otd(a, '${fmtQty(li.qty)}${mixedUnits ? ' ${li.unitLabel}' : ''}', size: 9.6, ltr: !mixedUnits, vPad: 6),
          otd(a, money(li.unitPrice), size: 9.6, ltr: true, vPad: 6),
          if (hasExt) otd(a, li.external > 0 ? money(li.external) : '—', size: 9.6, ltr: true, vPad: 6),
          otd(a, money(li.total), size: 9.6, ltr: true, bold: true, vPad: 6),
        ]));
      }
      if (inv.items.isEmpty) {
        irows.add(pw.TableRow(children: [
          pw.SizedBox(),
          otd(a, 'لا توجد بنود', align: pw.Alignment.centerRight, size: 9.8, vPad: 6),
          pw.SizedBox(),
          pw.SizedBox(),
          if (hasExt) pw.SizedBox(),
          pw.SizedBox(),
        ]));
      }
      final itemsTable = officialTable(columnWidths: iw, children: irows, border: innerBorder(top: 1.1, bottom: 1.1));

      // ---- 4) الدفعات (يمين) + الإجماليات (يسار)
      final prow = <pw.TableRow>[
        pw.TableRow(decoration: headDeco(), children: [
          oth(a, 'التاريخ', size: 9.4),
          oth(a, 'السند', size: 9.4),
          oth(a, 'الطريقة', size: 9.4),
          oth(a, 'المبلغ', size: 9.4),
        ]),
        if (inv.deposit > 0)
          pw.TableRow(children: [
            otd(a, fmtDate(inv.issueDate), size: 9.4, ltr: true, vPad: 4.5),
            otd(a, '—', size: 9.4, vPad: 4.5),
            otd(a, 'عربون', size: 9.4, vPad: 4.5),
            otd(a, money(inv.deposit), size: 9.4, ltr: true, color: O.green, bold: true, vPad: 4.5),
          ]),
        for (final p in invPays)
          pw.TableRow(children: [
            otd(a, fmtDate(p.date), size: 9.4, ltr: true, vPad: 4.5),
            otd(a, p.receiptNumber.isNotEmpty ? p.receiptNumber : (p.reference.isNotEmpty ? p.reference : '—'), size: 9.2, ltr: true, vPad: 4.5),
            otd(a, p.method, size: 9.4, vPad: 4.5),
            otd(a, money(p.amount), size: 9.4, ltr: true, color: O.green, bold: true, vPad: 4.5),
          ]),
        if (paid > 0)
          pw.TableRow(decoration: const pw.BoxDecoration(color: O.zebra), children: [
            // عمود التاريخ ضيق (58pt) فيُكتفى بـ«الإجمالي» كي لا ينكسر العنوان على سطرين
            otd(a, 'الإجمالي', align: pw.Alignment.centerRight, size: 9.4, bold: true, vPad: 4.5),
            pw.SizedBox(),
            pw.SizedBox(),
            otd(a, money(paid), size: 9.4, ltr: true, color: O.green, bold: true, vPad: 4.5),
          ]),
      ];
      final noPays = paid == 0;
      final remLabel = remaining > 0 ? 'المتبقي' : (remaining < 0 ? 'مدفوع بالزيادة' : 'المتبقي');
      final remColor = remaining > 0 ? O.red : O.green;
      final bottom = pw.Padding(
        padding: const pw.EdgeInsets.fromLTRB(8, 7, 8, 8),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          // الدفعات — يمين
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('الدفعات المستلمة على الفاتورة', style: a.t(9.8, color: O.brown, bold: true)),
              pw.SizedBox(height: 4),
              if (noPays)
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: O.line, width: 0.85), color: O.zebra),
                  child: pw.Text('لم تُستلم أي دفعة على هذه الفاتورة حتى تاريخ الكشف', style: a.t(9.4, color: O.red)),
                )
              else
                officialTable(columnWidths: {
                  0: const pw.FixedColumnWidth(58),
                  1: const pw.FixedColumnWidth(68),
                  2: const pw.FlexColumnWidth(),
                  3: const pw.FixedColumnWidth(72),
                }, children: prow),
            ]),
          ),
          pw.SizedBox(width: 16),
          // الإجماليات — يسار (نفس بنية الفاتورة)
          pw.SizedBox(
            width: 226,
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('إجماليات الفاتورة', style: a.t(9.8, color: O.brown, bold: true)),
              pw.SizedBox(height: 4),
              pw.Container(
                padding: const pw.EdgeInsets.fromLTRB(8, 4, 8, 4),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: O.line, width: 0.85)),
                child: pw.Column(children: [
                  if (hasExt) _dLine('خدمات الضيافة', money(t.services)),
                  if (hasExt) _dLine('مشتريات خارجية', money(t.external)),
                  if (hasDiscount || hasVat) _dLine('المجموع', money(t.subtotal)),
                  if (hasDiscount) _dLine('الخصم', '- ${money(t.discount)}'),
                  if (hasVat) _dLine('ضريبة القيمة المضافة ($vatPct%)', money(t.vat)),
                  _dLine('إجمالي الفاتورة', money(t.total), bold: true, top: hasExt || hasDiscount || hasVat),
                  if (inv.deposit > 0) _dLine('العربون', money(inv.deposit), color: O.green),
                  if (extraPaid > 0) _dLine('الدفعات', money(extraPaid), color: O.green),
                  _dLine(remLabel, money(remaining.abs()), color: remColor, bold: true, top: true),
                ]),
              ),
            ]),
          ),
        ]),
      );

      // ---- 5) ملاحظات الفاتورة
      final notes = inv.notes.trim().isEmpty
          ? null
          : pw.Container(
              padding: const pw.EdgeInsets.fromLTRB(8, 5, 8, 6),
              decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: O.line, width: 0.85))),
              child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('ملاحظات: ', style: a.t(9.4, color: O.brown, bold: true)),
                pw.Expanded(child: pw.Text(inv.notes.trim(), style: a.t(9.4, color: O.ink))),
              ]),
            );

      // ---- تجميع البطاقة: القصيرة كتلة واحدة لا تنقسم؛ الطويلة تُقسَّم مع تكرار رأس الجدول
      final short = inv.items.length + invPays.length <= 6;
      body.add(pw.SizedBox(height: 10));
      if (short) {
        body.add(pw.Inseparable(
          child: pw.Container(
            decoration: cardDeco(),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
              header,
              if (metaLine != null) metaLine,
              pw.SizedBox(height: metaLine != null ? 5 : 7),
              pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8), child: itemsTable),
              bottom,
              if (notes != null) notes,
            ]),
          ),
        ));
      } else {
        // بطاقة مفتوحة من الأسفل (يُغلقها الذيل) كي ينقسم الجدول بين الصفحات
        body.add(pw.Inseparable(
          child: pw.Container(
            decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: O.line, width: 1.1), left: pw.BorderSide(color: O.line, width: 1.1), right: pw.BorderSide(color: O.line, width: 1.1))),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
              header,
              if (metaLine != null) metaLine,
              pw.SizedBox(height: metaLine != null ? 5 : 7),
            ]),
          ),
        ));
        body.add(pw.Container(
          decoration: const pw.BoxDecoration(border: pw.Border(left: pw.BorderSide(color: O.line, width: 1.1), right: pw.BorderSide(color: O.line, width: 1.1))),
          padding: const pw.EdgeInsets.symmetric(horizontal: 8),
          child: itemsTable,
        ));
        body.add(pw.Inseparable(
          child: pw.Container(
            decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: O.line, width: 1.1), left: pw.BorderSide(color: O.line, width: 1.1), right: pw.BorderSide(color: O.line, width: 1.1))),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [bottom, if (notes != null) notes]),
          ),
        ));
      }
    }

    // ---- دفعات على الحساب (غير مرتبطة بفاتورة)
    if (onAccount.isNotEmpty) {
      var k = 0;
      final accTotal = onAccount.fold<int>(0, (x, p) => x + p.amount);
      body.add(pw.SizedBox(height: 10));
      body.add(pw.Inseparable(
        child: pw.Container(
          decoration: cardDeco(),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
            cardHeader([
              pw.Text('دفعات على الحساب', style: a.t(11, color: O.brown, black: true)),
              pw.Text('  (غير مخصصة لفاتورة محددة)', style: a.t(9.6, color: O.ink)),
              pw.Spacer(),
              pw.Text('${money(accTotal)} ر.س', style: a.t(10.4, color: O.green, black: true)),
            ]),
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(8, 7, 8, 8),
              child: officialTable(columnWidths: {
                0: const pw.FixedColumnWidth(24),
                1: const pw.FixedColumnWidth(60),
                2: const pw.FixedColumnWidth(70),
                3: const pw.FixedColumnWidth(70),
                4: const pw.FlexColumnWidth(),
                5: const pw.FixedColumnWidth(80),
              }, children: [
                pw.TableRow(decoration: headDeco(), children: [
                  oth(a, 'م', size: 9.6),
                  oth(a, 'التاريخ', size: 9.6),
                  oth(a, 'السند', size: 9.6),
                  oth(a, 'الطريقة', size: 9.6),
                  oth(a, 'المرجع / ملاحظات', size: 9.6),
                  oth(a, 'المبلغ', size: 9.6),
                ]),
                for (final p in onAccount)
                  pw.TableRow(decoration: (++k).isEven ? const pw.BoxDecoration(color: O.zebra) : null, children: [
                    otd(a, '$k', size: 9.4, ltr: true, vPad: 5),
                    otd(a, fmtDate(p.date), size: 9.4, ltr: true, vPad: 5),
                    otd(a, p.receiptNumber.isNotEmpty ? p.receiptNumber : '—', size: 9.2, ltr: true, vPad: 5),
                    otd(a, p.method, size: 9.4, vPad: 5),
                    otd(a, [p.reference, p.notes].where((e) => e.trim().isNotEmpty).join(' — '), align: pw.Alignment.centerRight, size: 9.2, vPad: 5),
                    otd(a, money(p.amount), size: 9.4, ltr: true, color: O.green, bold: true, vPad: 5),
                  ]),
              ]),
            ),
          ]),
        ),
      ));
    }

    // ---- الملخص العام: حالة الفواتير (يمين) + معادلة الرصيد (يسار)
    final dueLabel = due > 0 ? 'الرصيد المستحق' : (due < 0 ? 'رصيد دائن للعميل' : 'الرصيد');
    final accTotal = onAccount.fold<int>(0, (x, p) => x + p.amount);
    // تحقق داخلي: ما يُعرض في البطاقات يجب أن يساوي معادلة الكشف نفسها (تُفحص في الاختبارات)
    assert(sumBilled == s.billed, 'إجمالي بطاقات الفواتير ($sumBilled) ≠ إجمالي الفواتير في الكشف (${s.billed})');
    assert(sumDeposits + sumPays + accTotal == s.paid, 'مجموع المدفوعات المعروضة ≠ إجمالي المدفوعات في الكشف (${s.paid})');
    assert(cntPaid + cntPartial + cntUnpaid == s.count, 'عدّادات الحالة لا تساوي عدد الفواتير');
    body.add(pw.SizedBox(height: 12));
    body.add(pw.Inseparable(
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        pw.Container(
          decoration: cardDeco(),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
            cardHeader([pw.Text('ملخص الحساب', style: a.t(11.4, color: O.brown, black: true))]),
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                // يمين: عدّاد الحالات
                pw.Expanded(
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    _sumLine('عدد الفواتير خلال الفترة', '${s.count}', size: 10.2),
                    _sumLine('مدفوعة بالكامل', '$cntPaid', size: 10.2, color: O.green),
                    _sumLine('مدفوعة جزئيًا', '$cntPartial', size: 10.2, color: O.gold),
                    _sumLine('غير مدفوعة', '$cntUnpaid', size: 10.2, color: O.red),
                  ]),
                ),
                pw.SizedBox(width: 26),
                // يسار: المعادلة
                pw.SizedBox(
                  width: 280,
                  child: pw.Column(children: [
                    if (s.opening != 0) _sumLine('رصيد سابق قبل الفترة', '${s.opening < 0 ? '(${money(-s.opening)})' : money(s.opening)} ر.س', size: 10.2),
                    _sumLine('إجمالي الفواتير', '${money(s.billed)} ر.س', size: 10.2),
                    if (sumDeposits > 0) _sumLine('العرابين المستلمة', '${money(sumDeposits)} ر.س', size: 10.2, color: O.green),
                    if (sumPays > 0) _sumLine('الدفعات على الفواتير', '${money(sumPays)} ر.س', size: 10.2, color: O.green),
                    if (accTotal > 0) _sumLine('دفعات على الحساب', '${money(accTotal)} ر.س', size: 10.2, color: O.green),
                    _sumLine('إجمالي المدفوعات', '${money(s.paid)} ر.س', size: 10.2, bold: true, color: O.green),
                    singleRule(width: 1.2),
                    pw.SizedBox(height: 7),
                    pw.Row(children: [
                      pw.Text(dueLabel, style: a.t(14, color: O.brown, black: true)),
                      pw.Spacer(),
                      pw.Text('${money(due.abs())} ر.س', style: a.t(14, color: due > 0 ? O.red : O.brown, black: true)),
                    ]),
                    if (org.showTafqit && due != 0) pw.SizedBox(height: 3),
                    if (org.showTafqit && due != 0)
                      pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: pw.Text(tafqit(due.abs()), style: a.t(9.8, color: O.ink, bold: true)),
                      ),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
        if (org.showTerms) pw.SizedBox(height: 8),
        if (org.showTerms)
          pw.Text(
            due > 0
                ? 'ملاحظة: نأمل تسوية الرصيد المستحق عبر التحويل البنكي على الحساب المذكور أدناه مع ذكر رقم الكشف. للاستفسار عن أي حركة يرجى التواصل معنا.'
                : 'ملاحظة: حسابكم مسدَّد بالكامل حتى تاريخ هذا الكشف. نشكر لكم حسن تعاونكم.',
            style: a.t(10, color: O.ink),
          ),
        pw.SizedBox(height: 10),
        singleRule(),
        pw.SizedBox(height: 14),
        officialFooter(a, org, website: true),
      ]),
    ));

    doc.addPage(pw.MultiPage(
      pageTheme: officialPageTheme(a, org, leaves: true),
      header: (ctx) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 10),
        child: officialHeader(a, org, badgeLines: ['كشف حساب تفصيلي', badgeStatus]),
      ),
      footer: (ctx) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 8),
        child: officialPageNum(a, ctx, prefix: '$label — ${s.client.name}'),
      ),
      build: (ctx) => body,
    ));
    return doc.save();
  }

  /// خلية الوصف بحجم مخصص (للكشف التفصيلي): السطر الأول عريض والبقية بشرطة — كالفاتورة تمامًا
  pw.Widget _descCellSized(String desc, double first, double rest) {
    final lines = desc.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (lines.isEmpty) return otd(a, '', align: pw.Alignment.centerRight, size: first, vPad: 6);
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(lines.first, style: a.t(first, color: O.ink, bold: true)),
        for (final l in lines.skip(1))
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Text(l.startsWith('-') ? l : '- $l', style: a.t(rest, color: O.ink)),
          ),
      ]),
    );
  }

  /// سطر في كتلة إجماليات الفاتورة داخل الكشف التفصيلي
  pw.Widget _dLine(String label, String value, {bool bold = false, PdfColor color = O.ink, bool top = false}) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 3.2),
        decoration: top ? const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: O.gold, width: 0.8))) : null,
        child: pw.Row(children: [
          pw.Text(label, style: a.t(9.8, color: color, bold: bold)),
          pw.Spacer(),
          pw.Text('$value ر.س', style: a.t(9.8, color: color, bold: bold)),
        ]),
      );

  /* ==========================================================
     سند قبض — نصف صفحة (A5 عرضي) بالهوية الرسمية
     ========================================================== */
  /// [payments] كل دفعات العميل (لحساب المدفوع من الفاتورة حتى هذا السند شاملًا إياه).
  Future<Uint8List> receipt(Payment p, Client c, Invoice? inv, {List<Payment> payments = const []}) async {
    final label = 'سند قبض ${p.receiptNumber}';
    final doc = _doc(label);
    String money(int h) => fmt(h);

    // حالة الفاتورة بعد هذه الدفعة: العربون + الدفعات المسجَّلة على الفاتورة حتى هذا السند (شاملًا إياه)
    int invTotal = 0, invPaidBefore = 0, invRemaining = 0;
    if (inv != null) {
      invTotal = inv.totals.total;
      bool upTo(Payment q) => q.id != p.id && !q.isDeleted && q.invoiceId == inv.id &&
          (q.date.compareTo(p.date) < 0 || (q.date == p.date && q.createdAt.compareTo(p.createdAt) <= 0));
      invPaidBefore = inv.deposit + payments.where(upTo).fold<int>(0, (t, q) => t + q.amount);
      invRemaining = invTotal - invPaidBefore - p.amount;
    }
    final isFull = inv != null && invRemaining <= 0;
    final about = inv != null
        ? 'فاتورة رقم ${inv.number}${inv.eventDate.isNotEmpty ? ' — فعالية ${_eventRange(inv)}' : ''}${inv.location.isNotEmpty ? ' — ${inv.location}' : ''}'
        : 'دفعة على الحساب';
    final m = p.method;
    final knownMethod = m == 'نقدًا' || m == 'شبكة' || m == 'تحويل بنكي' || m == 'شيك';

    doc.addPage(pw.Page(
      pageTheme: receiptPageTheme(a, org),
      build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        receiptHeader(a, org, title: 'سند قبض', subtitle: 'RECEIPT VOUCHER'),
        pw.SizedBox(height: 8),
        doubleRule(),
        pw.SizedBox(height: 8),
        // رقم السند (يمين) والتاريخ (يسار)
        pw.Row(children: [
          pw.Expanded(
            flex: 55,
            child: framedBox(pw.Row(children: [
              pw.Text('رقم السند: ', style: a.t(10.8, color: O.brown, bold: true)),
              pw.Text(p.receiptNumber, style: a.t(11.6, color: O.ink, black: true), textDirection: pw.TextDirection.ltr),
            ])),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            flex: 45,
            child: framedBox(pw.Row(children: [
              pw.Text('التاريخ: ', style: a.t(10.8, color: O.brown, bold: true)),
              pw.Text(fmtDate(p.date), style: a.t(11.2, color: O.ink, bold: true), textDirection: pw.TextDirection.ltr),
            ])),
          ),
        ]),
        pw.SizedBox(height: 9),
        pw.Row(children: [
          dottedField(a, 'استلمنا من السيد/ة', c.name, flex: 60),
          pw.SizedBox(width: 14),
          dottedField(a, 'رقم الجوال', c.phone, ltr: true, flex: 40),
        ]),
        pw.SizedBox(height: 8),
        pw.Row(children: [dottedField(a, 'وذلك مقابل', about)]),
        pw.SizedBox(height: 9),
        // المبلغ رقمًا وكتابةً
        framedBox(
          pw.Row(children: [
            pw.Text('مبلغ وقدره: ', style: a.t(11, color: O.brown, bold: true)),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: pw.BoxDecoration(color: O.white, border: pw.Border.all(color: O.gold, width: 0.9), borderRadius: pw.BorderRadius.circular(3)),
              child: pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
                pw.Text(money(p.amount), style: a.t(15, color: O.brown, black: true), textDirection: pw.TextDirection.ltr),
                pw.Text(' ر.س', style: a.t(10.4, color: O.brown, bold: true)),
              ]),
            ),
            if (org.showTafqit) pw.SizedBox(width: 14),
            if (org.showTafqit) pw.Text('كتابةً: ', style: a.t(10.4, color: O.brown, bold: true)),
            if (org.showTafqit) pw.Expanded(child: pw.Text(tafqit(p.amount), style: a.t(10.4, color: O.ink, bold: true))),
          ]),
          fill: O.headFill,
          vPad: 7,
        ),
        pw.SizedBox(height: 8),
        // طريقة الدفع والحالة
        framedBox(
          pw.Row(children: [
            pw.Text('طريقة الدفع: ', style: a.t(10.2, color: O.brown, bold: true)),
            checkBox(a, 'نقدًا', m == 'نقدًا'),
            pw.SizedBox(width: 10),
            checkBox(a, 'شبكة', m == 'شبكة'),
            pw.SizedBox(width: 10),
            checkBox(a, 'تحويل', m == 'تحويل بنكي'),
            pw.SizedBox(width: 10),
            checkBox(a, 'شيك', m == 'شيك'),
            pw.SizedBox(width: 10),
            checkBox(a, knownMethod || m.isEmpty ? 'أخرى' : m, !knownMethod && m.isNotEmpty),
            pw.Spacer(),
            pw.Container(width: 0.8, height: 12, color: O.line),
            pw.Spacer(),
            pw.Text('الحالة: ', style: a.t(10.2, color: O.brown, bold: true)),
            checkBox(a, 'دفعة', inv != null && !isFull),
            pw.SizedBox(width: 10),
            checkBox(a, 'سداد كامل', isFull),
            pw.SizedBox(width: 10),
            checkBox(a, 'على الحساب', inv == null),
          ]),
          vPad: 6,
        ),
        if (p.reference.trim().isNotEmpty || p.notes.trim().isNotEmpty) pw.SizedBox(height: 7),
        if (p.reference.trim().isNotEmpty || p.notes.trim().isNotEmpty)
          pw.Row(children: [
            if (p.reference.trim().isNotEmpty) dottedField(a, 'رقم العملية / المرجع', p.reference.trim(), ltr: true, size: 9.6, flex: 45),
            if (p.reference.trim().isNotEmpty && p.notes.trim().isNotEmpty) pw.SizedBox(width: 14),
            if (p.notes.trim().isNotEmpty) dottedField(a, 'ملاحظات', p.notes.trim(), size: 9.6, flex: 55),
          ]),
        if (inv != null) pw.SizedBox(height: 7),
        if (inv != null)
          pw.Row(children: [
            pw.Text('إجمالي الفاتورة: ', style: a.t(9.6, color: O.brown, bold: true)),
            pw.Text('${money(invTotal)} ر.س', style: a.t(9.6, color: O.ink, bold: true)),
            pw.SizedBox(width: 16),
            if (invPaidBefore > 0) pw.Text('المدفوع سابقًا: ', style: a.t(9.6, color: O.brown, bold: true)),
            if (invPaidBefore > 0) pw.Text('${money(invPaidBefore)} ر.س', style: a.t(9.6, color: O.ink, bold: true)),
            if (invPaidBefore > 0) pw.SizedBox(width: 16),
            pw.Text('هذه الدفعة: ', style: a.t(9.6, color: O.brown, bold: true)),
            pw.Text('${money(p.amount)} ر.س', style: a.t(9.6, color: O.green, bold: true)),
            pw.SizedBox(width: 16),
            pw.Text(invRemaining > 0 ? 'المتبقي بعد الدفعة: ' : 'المتبقي: ', style: a.t(9.6, color: O.brown, bold: true)),
            pw.Text('${money(invRemaining < 0 ? 0 : invRemaining)} ر.س', style: a.t(9.6, color: invRemaining > 0 ? O.red : O.green, bold: true)),
          ]),
        pw.Spacer(),
        // التوقيعات والختم
        if (org.showSignatures || org.showStamp)
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            if (org.showSignatures) pw.Expanded(child: _sigSlot('توقيع المستلم')),
            pw.Expanded(
              child: pw.Column(children: [
                if (org.showStamp) pw.Image(a.stamp, width: 54, height: 54, fit: pw.BoxFit.contain),
                if (org.showStamp) pw.SizedBox(height: 2),
                pw.Text('ختم المؤسسة', style: a.t(9.6, color: O.brown, bold: true)),
              ]),
            ),
            if (org.showSignatures) pw.Expanded(child: _sigSlot('توقيع العميل')),
          ]),
        pw.SizedBox(height: 8),
        receiptFooterBand(a, org),
      ]),
    ));
    return doc.save();
  }

  pw.Widget _sigSlot(String label) => pw.Column(children: [
        pw.Container(
          width: 120,
          height: 0.7,
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: O.gold, width: 0.7, style: pw.BorderStyle.dotted))),
        ),
        pw.SizedBox(height: 3),
        pw.Text(label, style: a.t(9.6, color: O.brown, bold: true)),
      ]);
}
