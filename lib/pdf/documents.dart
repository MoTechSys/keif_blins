/// documents.dart — مولّدات PDF: فاتورة، عرض سعر، كشف حساب، سند قبض | كيف الضيافة
library;

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/models.dart';
import '../core/money.dart';
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
     الفاتورة / عرض السعر
     ========================================================== */
  Future<Uint8List> invoice(Invoice inv, List<Payment> payments, {Client? client}) async {
    final isQ = inv.isQuote;
    final t = inv.totals;
    final paid = isQ ? 0 : invoicePaid(inv, payments);
    final remaining = t.total - paid;
    final titleAr = isQ ? 'عرض سعر' : (inv.vatRateBp > 0 ? 'فاتورة ضريبية' : 'فاتورة');
    final titleEn = isQ ? 'QUOTATION' : (inv.vatRateBp > 0 ? 'TAX INVOICE' : 'INVOICE');
    final label = isQ ? 'عرض سعر رقم ${inv.number}' : 'فاتورة رقم ${inv.number}';

    String? badge;
    PdfColor badgeColor = K.navy;
    if (!isQ) {
      final st = computeStatus(inv, payments);
      badge = statusLabel[st];
      badgeColor = switch (st) {
        InvoiceStatus.paid => K.green,
        InvoiceStatus.partial => K.goldDark,
        InvoiceStatus.cancelled => K.red,
        _ => K.navy,
      };
    } else {
      badge = quoteStatusLabel[inv.quoteStatus];
    }

    final doc = _doc(label);
    doc.addPage(pw.MultiPage(
      pageTheme: royalPageTheme(a, org),
      header: (ctx) => pw.Column(children: [
        royalHeader(a, org),
        pw.SizedBox(height: 3 * mm),
        titleBand(a, titleAr, titleEn, badge: badge, badgeColor: badgeColor),
        pw.SizedBox(height: 3 * mm),
      ]),
      footer: (ctx) => pw.Column(children: [
        royalFooter(a, org, bank: !isQ || true),
        pageNum(a, ctx, '$label — ${org.name}'),
      ]),
      build: (ctx) => [
        // بطاقتا البيانات
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
            flex: 11,
            child: dataCard(a, title: isQ ? 'مقدَّم إلى' : 'بيانات العميل', rows: [
              ('العميل', inv.clientName),
              ('جهة الاتصال', client?.contact ?? ''),
              ('الهاتف', client?.phone ?? ''),
              ('الرقم الضريبي', client?.vatNumber ?? ''),
              ('العنوان', client?.address ?? ''),
            ]),
          ),
          pw.SizedBox(width: 3 * mm),
          pw.Expanded(
            flex: 9,
            child: dataCard(a, title: isQ ? 'بيانات العرض' : 'بيانات الفاتورة', rows: [
              (isQ ? 'رقم العرض' : 'رقم الفاتورة', inv.number),
              ('تاريخ الإصدار', fmtDate(inv.issueDate)),
              if (isQ) ('ساري حتى', fmtDate(inv.validUntil)),
              ('تاريخ المناسبة', _eventRange(inv)),
              ('الموقع', inv.location),
              ('عدد الحضور', inv.attendees),
            ]),
          ),
        ]),
        pw.SizedBox(height: 3.5 * mm),
        // جدول البنود
        _itemsTable(inv, t),
        pw.SizedBox(height: 3 * mm),
        // الملخّص + التفقيط
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
            flex: 11,
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              _tafqitBox(t.total),
              pw.SizedBox(height: 2.5 * mm),
              if ((isQ ? org.quoteTerms : inv.terms.isNotEmpty ? inv.terms : org.invoiceTerms).isNotEmpty)
                _termsBox(isQ ? 'الشروط والأحكام' : 'ملاحظات وشروط',
                    isQ ? (inv.terms.isNotEmpty ? inv.terms : org.quoteTerms) : (inv.terms.isNotEmpty ? inv.terms : org.invoiceTerms)),
              if (inv.notes.isNotEmpty) pw.SizedBox(height: 2 * mm),
              if (inv.notes.isNotEmpty) _termsBox('ملاحظات', inv.notes),
            ]),
          ),
          pw.SizedBox(width: 3 * mm),
          pw.Expanded(flex: 9, child: _sumsCard(t, paid, remaining, isQ)),
        ]),
        pw.SizedBox(height: 4 * mm),
        if (!isQ) _ackBlock(),
        if (!isQ) pw.SizedBox(height: 3 * mm),
        signatures(a, org, left: isQ ? 'اعتماد العميل' : 'توقيع العميل'),
        pw.SizedBox(height: 2 * mm),
      ],
    ));
    return doc.save();
  }

  String _eventRange(Invoice inv) {
    if (inv.eventDate.isEmpty) return '';
    if (inv.eventDateTo.isNotEmpty && inv.eventDateTo != inv.eventDate) {
      return 'من ${fmtDate(inv.eventDate)} إلى ${fmtDate(inv.eventDateTo)}';
    }
    return fmtDate(inv.eventDate);
  }

  pw.Widget _itemsTable(Invoice inv, Totals t) {
    final hasExt = t.external > 0;
    final unit = inv.items.isNotEmpty && inv.items.every((i) => i.unitLabel == inv.items.first.unitLabel)
        ? inv.items.first.unitLabel
        : 'الكمية';
    final widths = <int, pw.TableColumnWidth>{
      0: const pw.FixedColumnWidth(8 * mm),
      1: const pw.FlexColumnWidth(),
      2: const pw.FixedColumnWidth(24 * mm),
      3: const pw.FixedColumnWidth(16 * mm),
      if (hasExt) 4: const pw.FixedColumnWidth(26 * mm),
      (hasExt ? 5 : 4): const pw.FixedColumnWidth(28 * mm),
    };
    final rows = <pw.TableRow>[
      pw.TableRow(repeat: true, decoration: tableHeadDeco(), children: [
        th(a, 'م'),
        th(a, 'وصف الخدمة', align: pw.Alignment.centerRight),
        th(a, 'السعر'),
        th(a, unit),
        if (hasExt) th(a, 'مشتريات خارجية'),
        th(a, 'الإجمالي (ر.س)'),
      ]),
    ];
    var n = 0;
    for (final li in inv.items) {
      n++;
      final even = n.isEven;
      rows.add(pw.TableRow(
        decoration: pw.BoxDecoration(
          color: even ? K.beigeSoft : K.white,
          border: const pw.Border(bottom: pw.BorderSide(color: K.line, width: 0.3)),
        ),
        verticalAlignment: pw.TableCellVerticalAlignment.middle,
        children: [
          pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 1.5 * mm), child: pw.Center(child: numCircle(a, n))),
          _descCell(li.desc),
          td(a, fmt(li.unitPrice, trimZeros: true)),
          td(a, '${fmtQty(li.qty)}${unit == 'الكمية' ? ' ${li.unitLabel}' : ''}'),
          if (hasExt) td(a, li.external > 0 ? fmt(li.external, trimZeros: true) : '—', color: li.external > 0 ? K.ink : K.muted),
          td(a, fmt(li.total), bold: true, color: K.navy),
        ],
      ));
    }
    if (inv.items.isEmpty) {
      rows.add(pw.TableRow(children: [
        pw.SizedBox(),
        td(a, 'لا توجد بنود', color: K.muted, align: pw.Alignment.centerRight),
        pw.SizedBox(),
        pw.SizedBox(),
        if (hasExt) pw.SizedBox(),
        pw.SizedBox(),
      ]));
    }
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: K.gold, width: 0.5),
        borderRadius: pw.BorderRadius.circular(1.5 * mm),
      ),
      child: pw.ClipRRect(
        horizontalRadius: 1.5 * mm,
        verticalRadius: 1.5 * mm,
        child: pw.Table(columnWidths: widths, children: rows),
      ),
    );
  }

  /// خلية الوصف: السطر الأول عنوان، والأسطر التالية فرعية بمعيّن ذهبي
  pw.Widget _descCell(String desc) {
    final lines = desc.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (lines.isEmpty) return td(a, '', align: pw.Alignment.centerRight);
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      padding: const pw.EdgeInsets.symmetric(horizontal: 2 * mm, vertical: 1.6 * mm),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(lines.first, style: a.t(8.6, color: K.ink, bold: true)),
        for (final l in lines.skip(1))
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 0.4 * mm, right: 1.5 * mm),
            child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              goldDiamond(1.4 * mm),
              pw.SizedBox(width: 1.2 * mm),
              pw.Expanded(child: pw.Text(l, style: a.t(7.4, color: K.muted))),
            ]),
          ),
      ]),
    );
  }

  pw.Widget _sumRow(String l, String v, {bool strong = false, PdfColor? color, bool last = false}) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 1.3 * mm, horizontal: 3 * mm),
        decoration: last
            ? null
            : const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: K.line, width: 0.3, style: pw.BorderStyle.dashed))),
        child: pw.Row(children: [
          pw.Text(l, style: a.t(strong ? 8.8 : 8, color: color ?? (strong ? K.navy : K.muted), bold: strong)),
          pw.Spacer(),
          pw.Text(v, style: a.t(strong ? 9.5 : 8.4, color: color ?? K.ink, bold: true)),
        ]),
      );

  pw.Widget _sumsCard(Totals t, int paid, int remaining, bool isQ) {
    final vatPct = t.vatRateBp % 100 == 0 ? '${t.vatRateBp ~/ 100}' : (t.vatRateBp / 100).toStringAsFixed(1);
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: K.beigeSoft,
        border: pw.Border.all(color: K.gold, width: 0.5),
        borderRadius: pw.BorderRadius.circular(2 * mm),
      ),
      child: pw.ClipRRect(
        horizontalRadius: 2 * mm,
        verticalRadius: 2 * mm,
        child: pw.Column(children: [
          if (t.external > 0) _sumRow('الخدمات', fmt(t.services)),
          if (t.external > 0) _sumRow('المشتريات الخارجية', fmt(t.external)),
          _sumRow('المجموع', fmt(t.subtotal)),
          if (t.discount > 0) _sumRow('الخصم', '- ${fmt(t.discount)}', color: K.red),
          _sumRow(t.vatRateBp > 0 ? 'ضريبة القيمة المضافة ($vatPct%)' : 'ضريبة القيمة المضافة', t.vatRateBp > 0 ? fmt(t.vat) : 'معفاة'),
          // الإجمالي — شريط كحلي
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 2.2 * mm, horizontal: 3 * mm),
            decoration: pw.BoxDecoration(gradient: const pw.LinearGradient(colors: [K.navyDeep, K.navy, K.navyLight])),
            child: pw.Row(children: [
              pw.Text(isQ ? 'إجمالي العرض' : 'الإجمالي المستحق', style: a.t(9.5, color: K.goldLight, bold: true)),
              pw.Spacer(),
              pw.Text(fmtSAR(t.total), style: a.t(12, color: K.white, black: true)),
            ]),
          ),
          if (!isQ && paid > 0) _sumRow('العربون / المدفوع', fmt(paid), color: K.green),
          if (!isQ && paid > 0) _sumRow('المتبقي', fmtSAR(remaining), strong: true, color: remaining > 0 ? K.red : K.green, last: true),
        ]),
      ),
    );
  }

  pw.Widget _tafqitBox(int total) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3 * mm, vertical: 2 * mm),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: K.gold, width: 0.4),
          borderRadius: pw.BorderRadius.circular(1.5 * mm),
          color: K.white,
        ),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Container(width: 1.2 * mm, height: 5 * mm, color: K.gold),
          pw.SizedBox(width: 2 * mm),
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('المبلغ كتابةً', style: a.t(6.8, color: K.muted)),
              pw.Text(tafqit(total), style: a.t(8.4, color: K.navy, bold: true)),
            ]),
          ),
        ]),
      );

  pw.Widget _termsBox(String title, String body) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(title, style: a.t(7.8, color: K.goldDark, bold: true)),
        pw.SizedBox(height: 0.6 * mm),
        pw.Text(body, style: a.t(7.4, color: K.muted)),
      ]);

  pw.Widget _ackBlock() => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4 * mm, vertical: 2 * mm),
        decoration: pw.BoxDecoration(
          gradient: const pw.LinearGradient(colors: [K.navyDeep, K.navy]),
          borderRadius: pw.BorderRadius.circular(1.5 * mm),
        ),
        child: pw.Row(children: [
          pw.Text('إقرار  ', style: a.t(8, color: K.goldLight, bold: true)),
          pw.Expanded(
            child: pw.Text(
              'أُقرّ بأنني استلمت الخدمات الموضحة أعلاه بحالة جيدة ومطابقة للاتفاق، وأن المبالغ المذكورة صحيحة.',
              style: a.t(7.6, color: K.white),
            ),
          ),
        ]),
      );

  /* ==========================================================
     كشف الحساب — متعدد الصفحات
     ========================================================== */
  Future<Uint8List> statement(Statement s) async {
    final label = 'كشف حساب ${s.number}';
    final period = s.from.isEmpty && s.to.isEmpty
        ? 'كل الفترات'
        : 'من ${s.from.isEmpty ? 'البداية' : fmtDate(s.from)} إلى ${s.to.isEmpty ? 'اليوم' : fmtDate(s.to)}';
    final doc = _doc(label);

    final rows = <pw.TableRow>[
      pw.TableRow(repeat: true, decoration: tableHeadDeco(), children: [
        th(a, 'التاريخ'),
        th(a, 'المرجع'),
        th(a, 'البيان', align: pw.Alignment.centerRight),
        th(a, 'مدين (فواتير)'),
        th(a, 'دائن (دفعات)'),
        th(a, 'الرصيد'),
      ]),
      pw.TableRow(decoration: const pw.BoxDecoration(color: K.beige), children: [
        td(a, ''),
        td(a, ''),
        td(a, 'رصيد افتتاحي', align: pw.Alignment.centerRight, bold: true, color: K.navy),
        td(a, ''),
        td(a, ''),
        td(a, fmt(s.opening), bold: true, color: K.navy),
      ]),
    ];
    var i = 0;
    for (final r in s.rows) {
      i++;
      final isInv = r.type == 'invoice';
      rows.add(pw.TableRow(
        decoration: pw.BoxDecoration(
          color: i.isEven ? K.beigeSoft : K.white,
          border: const pw.Border(bottom: pw.BorderSide(color: K.line, width: 0.3)),
        ),
        children: [
          td(a, fmtDate(r.date), size: 7.6),
          td(a, r.ref, size: 7.4, color: K.muted, ltr: true),
          td(a, r.desc, align: pw.Alignment.centerRight, size: 7.8),
          td(a, isInv ? fmt(r.debit) : '', color: K.ink),
          td(a, !isInv ? fmt(r.credit) : '', color: K.green),
          td(a, fmt(r.balance), bold: true, color: r.balance > 0 ? K.navy : K.green),
        ],
      ));
    }
    if (s.rows.isEmpty) {
      rows.add(pw.TableRow(children: [
        pw.SizedBox(),
        pw.SizedBox(),
        td(a, 'لا توجد حركات خلال الفترة', align: pw.Alignment.centerRight, color: K.muted),
        pw.SizedBox(),
        pw.SizedBox(),
        pw.SizedBox(),
      ]));
    }

    doc.addPage(pw.MultiPage(
      pageTheme: royalPageTheme(a, org),
      header: (ctx) => pw.Column(children: [
        royalHeader(a, org),
        pw.SizedBox(height: 3 * mm),
        titleBand(a, s.title, 'STATEMENT OF ACCOUNT', badge: s.closing > 0 ? 'مستحق: ${fmtSARSmart(s.closing)}' : 'لا مستحقات', badgeColor: s.closing > 0 ? K.red : K.green),
        pw.SizedBox(height: 3 * mm),
        if (ctx.pageNumber > 1)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2 * mm),
            child: pw.Text('${s.client.name}  —  $period  (تابع)', style: a.t(8, color: K.muted)),
          ),
      ]),
      footer: (ctx) => pw.Column(children: [
        royalFooter(a, org),
        pageNum(a, ctx, '$label — ${s.client.name}'),
      ]),
      build: (ctx) => [
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
            flex: 11,
            child: dataCard(a, title: 'بيانات العميل', rows: [
              ('العميل', s.client.name),
              ('جهة الاتصال', s.client.contact),
              ('الهاتف', s.client.phone),
              ('الرقم الضريبي', s.client.vatNumber),
            ]),
          ),
          pw.SizedBox(width: 3 * mm),
          pw.Expanded(
            flex: 9,
            child: dataCard(a, title: 'بيانات الكشف', rows: [
              ('رقم الكشف', s.number),
              ('تاريخ الإصدار', fmtDate(s.issueDate)),
              ('الفترة', period),
              ('عدد الفواتير', '${s.count}'),
            ]),
          ),
        ]),
        pw.SizedBox(height: 3.5 * mm),
        pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all(color: K.gold, width: 0.5), borderRadius: pw.BorderRadius.circular(1.5 * mm)),
          child: pw.ClipRRect(
            horizontalRadius: 1.5 * mm,
            verticalRadius: 1.5 * mm,
            child: pw.Table(
              columnWidths: const {
                0: pw.FixedColumnWidth(19 * mm),
                1: pw.FixedColumnWidth(20 * mm),
                2: pw.FlexColumnWidth(),
                3: pw.FixedColumnWidth(24 * mm),
                4: pw.FixedColumnWidth(24 * mm),
                5: pw.FixedColumnWidth(25 * mm),
              },
              children: rows,
            ),
          ),
        ),
        pw.SizedBox(height: 3.5 * mm),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
            flex: 11,
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              _tafqitBox(s.closing.abs()),
              pw.SizedBox(height: 2 * mm),
              _termsBox('ملاحظة', s.closing > 0
                  ? 'نأمل تسوية الرصيد المستحق عبر التحويل البنكي على الحساب المذكور أدناه مع ذكر رقم الكشف. للاستفسار عن أي حركة يرجى التواصل معنا.'
                  : 'حسابكم مسدَّد بالكامل حتى تاريخ هذا الكشف. نشكر لكم حسن تعاونكم.'),
            ]),
          ),
          pw.SizedBox(width: 3 * mm),
          pw.Expanded(
            flex: 9,
            child: pw.Container(
              decoration: pw.BoxDecoration(color: K.beigeSoft, border: pw.Border.all(color: K.gold, width: 0.5), borderRadius: pw.BorderRadius.circular(2 * mm)),
              child: pw.ClipRRect(
                horizontalRadius: 2 * mm,
                verticalRadius: 2 * mm,
                child: pw.Column(children: [
                  _sumRow('الرصيد الافتتاحي', fmt(s.opening)),
                  _sumRow('إجمالي الفواتير', fmt(s.billed)),
                  _sumRow('إجمالي المدفوعات', fmt(s.paid), color: K.green),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2.2 * mm, horizontal: 3 * mm),
                    decoration: pw.BoxDecoration(gradient: const pw.LinearGradient(colors: [K.navyDeep, K.navy, K.navyLight])),
                    child: pw.Row(children: [
                      pw.Text(s.closing >= 0 ? 'الرصيد المستحق' : 'رصيد دائن للعميل', style: a.t(9.5, color: K.goldLight, bold: true)),
                      pw.Spacer(),
                      pw.Text(fmtSAR(s.closing.abs()), style: a.t(12, color: K.white, black: true)),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ]),
        pw.SizedBox(height: 4 * mm),
        signatures(a, org, right: 'المحاسب / المدير العام', left: 'مصادقة العميل'),
      ],
    ));
    return doc.save();
  }

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
              pw.Text(fmtSAR(p.amount), style: a.t(20, color: K.white, black: true)),
            ]),
            pw.Spacer(),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('التاريخ', style: a.t(8, color: K.goldLight)),
              pw.Text(fmtDate(p.date), style: a.t(11, color: K.white, bold: true)),
              pw.SizedBox(height: 1 * mm),
              pw.Text('طريقة الدفع', style: a.t(8, color: K.goldLight)),
              pw.Text(p.method, style: a.t(10, color: K.white, bold: true)),
            ]),
          ]),
        ),
        pw.SizedBox(height: 4 * mm),
        dataCard(a, title: 'تفاصيل السند', rows: [
          ('استلمنا من', c.name),
          ('مبلغًا وقدره', tafqit(p.amount)),
          ('وذلك عن', inv != null ? 'فاتورة رقم ${inv.number}${inv.eventDate.isNotEmpty ? ' — ${fmtDate(inv.eventDate)}' : ''}' : 'دفعة على الحساب'),
          ('رقم العملية / المرجع', p.reference),
          ('ملاحظات', p.notes),
        ]),
        pw.SizedBox(height: 4 * mm),
        if (inv != null) _receiptInvoiceState(inv, p),
        pw.Spacer(),
        signatures(a, org, right: 'المستلم / المدير العام', left: 'توقيع الدافع'),
        pw.SizedBox(height: 4 * mm),
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
        pw.Text(v, style: a.t(10, color: color, bold: true)),
      ]);
}
