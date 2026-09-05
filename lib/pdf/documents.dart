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
    final invs = s.invoices;
    // عنوان الفترة: شهر واحد → «أغسطس 2026»، غير ذلك → المدى
    final monthRef = s.to.isNotEmpty ? s.to : (s.from.isNotEmpty ? s.from : s.issueDate);
    final sameMonth = s.from.length >= 7 && s.to.length >= 7 && s.from.substring(0, 7) == s.to.substring(0, 7);
    final periodTitle = sameMonth ? fmtMonth(monthRef) : (s.from.isEmpty && s.to.isEmpty ? 'كل الفترات' : fmtMonth(monthRef));
    final periodText = s.from.isEmpty && s.to.isEmpty
        ? 'كل الفترات'
        : '${sameMonth ? '$periodTitle — ' : ''}من ${s.from.isEmpty ? 'البداية' : fmtDate(s.from)} حتى ${s.to.isEmpty ? fmtDate(s.issueDate) : fmtDate(s.to)}';
    final services = invs.fold<int>(0, (v, i) => v + i.totals.services);
    final external = invs.fold<int>(0, (v, i) => v + i.totals.external);
    final hasExt = external > 0;
    final due = s.closing;
    final doc = _doc(label);

    String money(int h) => fmt(h, trimZeros: true);

    final widths = <int, pw.TableColumnWidth>{
      0: const pw.FixedColumnWidth(20), // م
      1: const pw.FixedColumnWidth(47), // رقم الفاتورة
      2: const pw.FixedColumnWidth(51), // تاريخ الإصدار
      3: const pw.FixedColumnWidth(53), // تاريخ الفعالية
      4: const pw.FixedColumnWidth(57), // الموقع
      5: const pw.FlexColumnWidth(), // البيان
      6: const pw.FixedColumnWidth(38), // الفترات
      7: const pw.FixedColumnWidth(43), // السعر
      if (hasExt) 8: const pw.FixedColumnWidth(52), // مشتريات خارجية
      (hasExt ? 9 : 8): const pw.FixedColumnWidth(58), // الإجمالي
    };
    final rows = <pw.TableRow>[
      pw.TableRow(repeat: true, decoration: headDeco(), children: [
        oth(a, 'م', size: 8.6),
        oth(a, 'رقم\nالفاتورة', size: 8.6),
        oth(a, 'تاريخ\nالإصدار', size: 8.6),
        oth(a, 'تاريخ\nالفعالية', size: 8.6),
        oth(a, 'الموقع', size: 8.6),
        oth(a, 'البيان', size: 8.6),
        oth(a, 'الفترات', size: 8.6),
        oth(a, 'السعر', size: 8.6),
        if (hasExt) oth(a, 'مشتريات\nخارجية', size: 8.6),
        oth(a, 'الإجمالي\n(ر.س)', size: 8.6),
      ]),
    ];
    var n = 0;
    for (final i in invs) {
      n++;
      final qty = i.items.fold<double>(0, (v, li) => v + li.qty);
      final price = i.items.length == 1 ? i.items.first.unitPrice : (qty > 0 ? (i.totals.services / qty).round() : i.totals.services);
      final desc = i.items.map((li) => li.desc.split('\n').first.trim()).where((e) => e.isNotEmpty).join('، ');
      rows.add(pw.TableRow(children: [
        otd(a, '$n', size: 8.4, vPad: 7),
        otd(a, i.number, size: 8.4, ltr: true, vPad: 7),
        otd(a, fmtDate(i.issueDate), size: 8.4, ltr: true, vPad: 7),
        otd(a, i.eventDate.isEmpty ? '—' : fmtDate(i.eventDate), size: 8.4, ltr: i.eventDate.isNotEmpty, vPad: 7),
        otd(a, i.location.isEmpty ? '—' : i.location, size: 8.4, vPad: 7),
        otd(a, desc.isEmpty ? 'خدمات ضيافة' : 'خدمات ضيافة: $desc', size: 8.4, vPad: 7),
        otd(a, fmtQty(qty), size: 8.4, ltr: true, vPad: 7),
        otd(a, money(price), size: 8.4, ltr: true, vPad: 7),
        if (hasExt) otd(a, i.totals.external > 0 ? money(i.totals.external) : '—', size: 8.4, ltr: i.totals.external > 0, vPad: 7),
        otd(a, money(i.totals.total), size: 8.4, ltr: true, bold: true, vPad: 7),
      ]));
    }
    if (invs.isEmpty) {
      rows.add(pw.TableRow(children: [
        for (var k = 0; k < (hasExt ? 10 : 9); k++) k == 5 ? otd(a, 'لا توجد فواتير خلال الفترة', size: 8.6) : pw.SizedBox(),
      ]));
    }

    doc.addPage(pw.MultiPage(
      pageTheme: officialPageTheme(a, org, leaves: true),
      header: (ctx) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 10),
        child: officialHeader(a, org, badgeLines: ['كشف حساب', periodTitle]),
      ),
      footer: (ctx) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 8),
        child: officialPageNum(a, ctx, prefix: periodTitle),
      ),
      build: (ctx) => [
        metaBlock(
          a,
          size: 9,
          right: [
            ('كشف حساب مُقدَّم إلى', s.client.name, false),
            ('الفترة', periodText, false),
          ],
          left: [
            ('رقم الكشف', s.number, true),
            ('تاريخ الإصدار', fmtDate(s.issueDate), true),
          ],
        ),
        pw.SizedBox(height: 8),
        officialTable(columnWidths: widths, children: rows),
        pw.SizedBox(height: 8),
        // الإجماليات: التسميات قرب منتصف الصفحة والقيم عند الهامش الأيسر (كالمرجع)
        pw.Row(children: [
          pw.Spacer(),
          pw.SizedBox(
            width: 300,
            child: pw.Column(children: [
              _soaLine('إجمالي خدمات الضيافة', '${money(services)} ر.س'),
              if (hasExt) _soaLine('إجمالي المشتريات الخارجية', '${money(external)} ر.س'),
              if (s.opening != 0) _soaLine('رصيد سابق قبل الفترة', '${money(s.opening)} ر.س'),
              if (s.paid > 0) _soaLine('المدفوع خلال الفترة', '${money(s.paid)} ر.س'),
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
              pw.Text('الإجمالي المستحق – ${_countLabel(s.count)}', style: a.t(13.2, color: O.brown, black: true)),
              pw.Spacer(),
              pw.Text('${money(due)} ر.س', style: a.t(13.2, color: O.brown, black: true)),
            ]),
          ),
        ]),
        // التفقيط داخل كتلة الإجماليات اليسرى (كالمرجع) ثم خط فاصل بعرض الصفحة قبل التذييل
        if (org.showTafqit && due > 0) pw.SizedBox(height: 4),
        if (org.showTafqit && due > 0)
          pw.Row(children: [
            pw.Spacer(),
            pw.SizedBox(
              width: 360,
              child: pw.Text(tafqit(due), style: a.t(10.6, color: O.ink, bold: true), textAlign: pw.TextAlign.right),
            ),
          ]),
        pw.SizedBox(height: 10),
        singleRule(),
        pw.SizedBox(height: 16),
        officialFooter(a, org, website: true),
      ],
    ));
    return doc.save();
  }

  String _countLabel(int n) => switch (n) {
        1 => 'فاتورة واحدة',
        2 => 'فاتورتان',
        _ when n >= 3 && n <= 10 => '$n فواتير',
        _ => '$n فاتورة',
      };

  pw.Widget _soaLine(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.Row(children: [
          pw.Text(label, style: a.t(9.6, color: O.ink)),
          pw.Spacer(),
          pw.Text(value, style: a.t(9.6, color: O.ink)),
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
