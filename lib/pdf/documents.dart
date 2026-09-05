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
     كشف الحساب — تفصيلي بفواتير الفترة (متعدد الصفحات)
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
      1: const pw.FixedColumnWidth(58), // التاريخ
      2: const pw.FixedColumnWidth(66), // المرجع
      3: const pw.FlexColumnWidth(), // البيان
      4: const pw.FixedColumnWidth(74), // مدين
      5: const pw.FixedColumnWidth(74), // دائن
      6: const pw.FixedColumnWidth(80), // الرصيد
    };
    final rows = <pw.TableRow>[
      pw.TableRow(repeat: true, decoration: headDeco(), children: [
        oth(a, 'م', size: 9),
        oth(a, 'التاريخ', size: 9),
        oth(a, 'المرجع', size: 9),
        oth(a, 'البيان', size: 9),
        oth(a, 'مدين\n(فواتير)', size: 9),
        oth(a, 'دائن\n(دفعات)', size: 9),
        oth(a, 'الرصيد\n(ر.س)', size: 9),
      ]),
      pw.TableRow(children: [
        otd(a, '', size: 8.6, vPad: 7),
        otd(a, s.from.isEmpty ? '' : fmtDate(s.from), size: 8.6, ltr: true, vPad: 7),
        otd(a, '', size: 8.6, vPad: 7),
        otd(a, s.from.isEmpty ? 'رصيد افتتاحي' : 'رصيد سابق قبل الفترة', align: pw.Alignment.centerRight, size: 8.6, bold: true, color: O.brown, vPad: 7),
        otd(a, '', size: 8.6, vPad: 7),
        otd(a, '', size: 8.6, vPad: 7),
        otd(a, bal(s.opening), size: 8.6, ltr: true, bold: true, color: O.brown, vPad: 7),
      ]),
    ];
    var n = 0;
    for (final r in s.rows) {
      n++;
      final isInv = r.type == 'invoice';
      rows.add(pw.TableRow(children: [
        otd(a, '$n', size: 8.6, vPad: 7),
        otd(a, fmtDate(r.date), size: 8.6, ltr: true, vPad: 7),
        otd(a, r.ref, size: 8.4, ltr: true, vPad: 7),
        otd(a, r.desc, align: pw.Alignment.centerRight, size: 8.6, vPad: 7),
        otd(a, isInv ? money(r.debit) : '', size: 8.6, ltr: true, vPad: 7),
        otd(a, !isInv ? money(r.credit) : '', size: 8.6, ltr: true, vPad: 7),
        otd(a, bal(r.balance), size: 8.6, ltr: true, bold: true, vPad: 7),
      ]));
    }
    if (s.rows.isEmpty) {
      rows.add(pw.TableRow(children: [
        for (var k = 0; k < 7; k++) k == 3 ? otd(a, 'لا توجد حركات خلال الفترة', size: 8.6) : pw.SizedBox(),
      ]));
    }
    rows.add(pw.TableRow(decoration: headDeco(), children: [
      pw.SizedBox(),
      pw.SizedBox(),
      pw.SizedBox(),
      otd(a, 'الإجمالي', align: pw.Alignment.centerRight, size: 9, bold: true, vPad: 7),
      otd(a, money(s.billed), size: 9, ltr: true, bold: true, vPad: 7),
      otd(a, money(s.paid), size: 9, ltr: true, bold: true, vPad: 7),
      otd(a, bal(s.closing), size: 9, ltr: true, bold: true, vPad: 7),
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
          size: 9.4,
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
              _soaLine('الرصيد الافتتاحي', '${bal(s.opening)} ر.س'),
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
              pw.Text(dueLabel, style: a.t(13.2, color: O.brown, black: true)),
              pw.Spacer(),
              pw.Text('${money(due.abs())} ر.س', style: a.t(13.2, color: due > 0 ? O.red : O.brown, black: true)),
            ]),
          ),
        ]),
        if (org.showTafqit && due != 0) pw.SizedBox(height: 4),
        if (org.showTafqit && due != 0)
          pw.Row(children: [
            pw.Spacer(),
            pw.SizedBox(
              width: 360,
              child: pw.Text(tafqit(due.abs()), style: a.t(10.6, color: O.ink, bold: true), textAlign: pw.TextAlign.right),
            ),
          ]),
        if (org.showTerms) pw.SizedBox(height: 8),
        if (org.showTerms)
          pw.Text(
            due > 0
                ? 'ملاحظة: نأمل تسوية الرصيد المستحق عبر التحويل البنكي على الحساب المذكور أدناه مع ذكر رقم الكشف. للاستفسار عن أي حركة يرجى التواصل معنا.'
                : 'ملاحظة: حسابكم مسدَّد بالكامل حتى تاريخ هذا الكشف. نشكر لكم حسن تعاونكم.',
            style: a.t(9.2, color: O.ink),
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
          pw.Text(label, style: a.t(9.6, color: O.ink, bold: bold)),
          pw.Spacer(),
          pw.Text(value, style: a.t(9.6, color: O.ink, bold: bold)),
        ]),
      );

  /* ==========================================================
     سند قبض
     ========================================================== */
  Future<Uint8List> receipt(Payment p, Client c, Invoice? inv) async {
    final label = 'سند قبض ${p.receiptNumber}';
    final doc = _doc(label);
    doc.addPage(pw.Page(
      pageTheme: royalPageTheme(a, org),
      build: (ctx) => pw.Column(children: [
        royalHeader(a, org),
        pw.SizedBox(height: 3 * mm),
        titleBand(a, 'سند قبض', 'RECEIPT VOUCHER', badge: p.receiptNumber, badgeColor: K.navy),
        pw.SizedBox(height: 5 * mm),
        // المبلغ الكبير
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 4 * mm, horizontal: 6 * mm),
          decoration: pw.BoxDecoration(
            gradient: const pw.LinearGradient(colors: [K.navyDeep, K.navy, K.navyLight]),
            borderRadius: pw.BorderRadius.circular(2 * mm),
            border: pw.Border.all(color: K.gold, width: 0.5),
          ),
          child: pw.Row(children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('المبلغ المستلم', style: a.t(8.5, color: K.goldLight)),
              pw.Text(fmtSAR(p.amount), style: a.t(20, color: K.white, black: true), textDirection: pw.TextDirection.ltr),
            ]),
            pw.Spacer(),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('التاريخ', style: a.t(8, color: K.goldLight)),
              pw.Text(fmtDate(p.date), style: a.t(11, color: K.white, bold: true), textDirection: pw.TextDirection.ltr),
              pw.SizedBox(height: 1 * mm),
              pw.Text('طريقة الدفع', style: a.t(8, color: K.goldLight)),
              pw.Text(p.method, style: a.t(10, color: K.white, bold: true)),
            ]),
          ]),
        ),
        pw.SizedBox(height: 4 * mm),
        dataCard(a, title: 'تفاصيل السند', rows: [
          ('استلمنا من', c.name),
          if (org.showTafqit) ('مبلغًا وقدره', tafqit(p.amount)),
          ('وذلك عن', inv != null ? 'فاتورة رقم ${inv.number}${inv.eventDate.isNotEmpty ? ' — ${fmtDate(inv.eventDate)}' : ''}' : 'دفعة على الحساب'),
          ('رقم العملية / المرجع', p.reference),
          ('ملاحظات', p.notes),
        ]),
        pw.SizedBox(height: 4 * mm),
        if (inv != null) _receiptInvoiceState(inv, p),
        pw.Spacer(),
        if (org.showSignatures) signatures(a, org, right: 'المستلم / المدير العام', left: 'توقيع الدافع'),
        if (org.showSignatures) pw.SizedBox(height: 4 * mm),
        royalFooter(a, org),
        pageNum(a, ctx, '$label — ${c.name}'),
      ]),
    ));
    return doc.save();
  }

  pw.Widget _receiptInvoiceState(Invoice inv, Payment p) {
    final t = inv.totals.total;
    return pw.Container(
      decoration: pw.BoxDecoration(color: K.beigeSoft, border: pw.Border.all(color: K.gold, width: 0.5), borderRadius: pw.BorderRadius.circular(2 * mm)),
      padding: const pw.EdgeInsets.symmetric(horizontal: 4 * mm, vertical: 2 * mm),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
        _kv('إجمالي الفاتورة', fmtSAR(t)),
        _kv('هذه الدفعة', fmtSAR(p.amount), color: K.green),
      ]),
    );
  }

  pw.Widget _kv(String k, String v, {PdfColor color = K.navy}) => pw.Column(children: [
        pw.Text(k, style: a.t(7.2, color: K.muted)),
        pw.Text(v, style: a.t(10, color: color, bold: true), textDirection: pw.TextDirection.ltr),
      ]);
}
