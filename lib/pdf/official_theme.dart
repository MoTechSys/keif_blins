/// official_theme.dart — التصميم الرسمي البسيط للمستندات | كيف الضيافة
/// مطابق لنماذج المؤسسة المعتمدة: خلفية بيضاء، بنّي/ذهبي، خطوط Tajawal،
/// ترويسة (شعار يمين + اسم المؤسسة في المنتصف + شارة المستند يسار)، خط ذهبي مزدوج،
/// جدول بسيط برأس بيج، تذييل بنكي + ختم، علامة مائية خفيفة، ترقيم صفحات.
library;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/models.dart';
import 'pdf_theme.dart' show PdfAssets;

/* ---------- الألوان (مستخرجة من النماذج المعتمدة) ---------- */
class O {
  static const ink = PdfColor.fromInt(0xFF2B2118); // نص أساسي
  static const brown = PdfColor.fromInt(0xFF5B4232); // عناوين وتسميات
  static const gold = PdfColor.fromInt(0xFFB8894A); // خطوط وأرقام مميزة
  static const red = PdfColor.fromInt(0xFFB3372E); // المتبقي / المدين
  static const green = PdfColor.fromInt(0xFF2E7D4F); // الدائن (المدفوعات)
  static const zebra = PdfColor.fromInt(0xFFFAF5EC); // تظليل الصفوف المتناوبة
  static const headFill = PdfColor.fromInt(0xFFF0E3CC); // رأس الجدول
  static const line = PdfColor.fromInt(0xFFB5A386); // حدود الجدول (أوضح قليلاً)
  static const white = PdfColors.white;
}

/// المسافات القياسية (A4 بالنقاط: 595 × 842)
const double _side = 20.0; // الهامش الجانبي
const double _top = 40.0;
const double _bottom = 28.0;

/* ---------- الصفحة ---------- */
/// [leaves] يرسم شريط الأوراق أعلى وأسفل الصفحة (كشف الحساب فقط).
pw.PageTheme officialPageTheme(PdfAssets a, Org org, {bool leaves = false}) {
  final leafBand = leaves ? _leafBand(a) : null;
  return pw.PageTheme(
    pageFormat: PdfPageFormat.a4,
    theme: pw.ThemeData.withFont(base: a.regular, bold: a.bold).copyWith(
      defaultTextStyle: pw.TextStyle(font: a.regular, fontSize: 10.2, color: O.ink, lineSpacing: 1.4),
    ),
    textDirection: pw.TextDirection.rtl,
    margin: pw.EdgeInsets.fromLTRB(_side, leaves ? _top + 8 : _top, _side, leaves ? _bottom + 14 : _bottom),
    buildBackground: (ctx) => pw.FullPage(
      ignoreMargins: true,
      child: pw.Stack(children: [
        if (org.showWatermark)
          pw.Positioned(
            left: 0,
            right: 0,
            top: 250,
            child: pw.Center(
              child: pw.Opacity(opacity: 0.08, child: pw.Image(a.logo, width: 300)),
            ),
          ),
        if (leafBand != null) pw.Positioned(left: 0, right: 0, top: 0, child: leafBand),
        if (leafBand != null) pw.Positioned(left: 0, right: 0, bottom: 0, child: leafBand),
      ]),
    ),
  );
}

/// شريط زخرفة الأوراق: تكرار وحدة SVG (122×99) بارتفاع 37pt عبر عرض الصفحة.
pw.Widget _leafBand(PdfAssets a) {
  const h = 37.0;
  const unitW = 122 * h / 99;
  final n = (PdfPageFormat.a4.width / unitW).ceil() + 1;
  return pw.ClipRect(
    child: pw.SizedBox(
      width: PdfPageFormat.a4.width,
      height: h,
      child: pw.Row(children: [
        for (var i = 0; i < n; i++) pw.SizedBox(width: unitW, height: h, child: pw.SvgImage(svg: a.leafSvg, fit: pw.BoxFit.fill)),
      ]),
    ),
  );
}

/* ---------- الترويسة ---------- */
/// الشعار يمين، اسم المؤسسة في المنتصف، شارة المستند يسار، ثم خط ذهبي مزدوج.
/// [badgeLines] سطر أو سطران داخل الشارة (مثل: «فاتورة» أو «كشف حساب / أغسطس 2026»).
pw.Widget officialHeader(PdfAssets a, Org org, {required List<String> badgeLines}) {
  return pw.Column(children: [
    pw.SizedBox(
      height: 96,
      child: pw.Stack(children: [
        // الشعار يمين
        pw.Positioned(right: 0, top: 6, child: pw.Image(a.logo, height: 90, fit: pw.BoxFit.contain)),
        // الاسم في المنتصف
        pw.Positioned(
          left: 0,
          right: 0,
          top: 10,
          child: pw.Column(children: [
            pw.Text(org.kingdom, style: a.t(10.2, color: O.ink)),
            pw.SizedBox(height: 2),
            pw.Text(org.name, style: a.t(16.2, color: O.brown, black: true)),
            pw.SizedBox(height: 2),
            if (org.showCr && org.cr.isNotEmpty)
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
                pw.Text('س-ت ', style: a.t(10.2, color: O.gold, bold: true)),
                pw.Text(org.cr, style: a.t(10.2, color: O.gold, bold: true), textDirection: pw.TextDirection.ltr),
              ]),
            if (org.showVatNumber && org.vat.isNotEmpty)
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
                pw.Text('الرقم الضريبي ', style: a.t(9.2, color: O.gold, bold: true)),
                pw.Text(org.vat, style: a.t(9.2, color: O.gold, bold: true), textDirection: pw.TextDirection.ltr),
              ]),
          ]),
        ),
        // الشارة يسار
        pw.Positioned(left: 0, top: 36, child: officialBadge(a, badgeLines)),
      ]),
    ),
    pw.SizedBox(height: 8),
    doubleRule(),
  ]);
}

/// شارة المستند: مستطيل بحد بنّي 1.5pt وزوايا مدوّرة.
pw.Widget officialBadge(PdfAssets a, List<String> lines) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: O.brown, width: 1.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(mainAxisSize: pw.MainAxisSize.min, children: [
        for (final l in lines) pw.Text(l, style: a.t(10.8, color: O.brown, black: true)),
      ]),
    );

/// خط ذهبي مزدوج بعرض الصفحة
pw.Widget doubleRule() => pw.Column(children: [
      pw.Container(height: 1.2, color: O.gold),
      pw.SizedBox(height: 1.6),
      pw.Container(height: 0.5, color: O.gold),
    ]);

/// خط ذهبي مفرد
pw.Widget singleRule({double width = 0.8}) => pw.Container(height: width, color: O.gold);

/* ---------- بيانات المستند: عمودان (يمين/يسار) ---------- */
/// كل عنصر: (التسمية، القيمة، هل القيمة رقمية LTR). تُخفى القيم الفارغة.
pw.Widget metaRow(PdfAssets a, List<(String, String, bool)> items, {double size = 10.8}) {
  final vis = items.where((e) => e.$2.isNotEmpty).toList();
  return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
    for (final e in vis)
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, mainAxisSize: pw.MainAxisSize.min, children: [
          pw.Text('${e.$1}: ', style: a.t(size, color: O.brown, bold: true)),
          pw.Flexible(child: pw.Text(e.$2, style: a.t(size, color: O.ink), textDirection: e.$3 ? pw.TextDirection.ltr : null)),
        ]),
      ),
  ]);
}

pw.Widget metaBlock(PdfAssets a, {required List<(String, String, bool)> right, required List<(String, String, bool)> left, double size = 10.8}) {
  return pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
    pw.Expanded(flex: 55, child: metaRow(a, right, size: size)),
    pw.SizedBox(width: 12),
    pw.Expanded(flex: 45, child: metaRow(a, left, size: size)),
  ]);
}

/* ---------- الجدول ---------- */
pw.BoxDecoration headDeco() => const pw.BoxDecoration(color: O.headFill);

/// حدود الجدول: الإطار الخارجي أوضح قليلاً من خطوط الصفوف/الأعمدة الداخلية.
pw.TableBorder tableBorder() => const pw.TableBorder(
      left: pw.BorderSide(color: O.line, width: 1.1),
      right: pw.BorderSide(color: O.line, width: 1.1),
      top: pw.BorderSide(color: O.line, width: 1.1),
      bottom: pw.BorderSide(color: O.line, width: 1.1),
      horizontalInside: pw.BorderSide(color: O.line, width: 0.85),
      verticalInside: pw.BorderSide(color: O.line, width: 0.85),
    );

pw.Widget oth(PdfAssets a, String t, {double size = 10.8}) => pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 9),
      child: pw.Text(t, style: a.t(size, color: O.ink, black: true), textAlign: pw.TextAlign.center),
    );

pw.Widget otd(PdfAssets a, String t,
        {pw.Alignment align = pw.Alignment.center,
        bool bold = false,
        PdfColor color = O.ink,
        double size = 10.2,
        bool ltr = false,
        double vPad = 9}) =>
    pw.Container(
      alignment: align,
      padding: pw.EdgeInsets.symmetric(horizontal: 5, vertical: vPad),
      child: pw.Text(
        t,
        style: a.t(size, color: color, bold: bold),
        textDirection: ltr ? pw.TextDirection.ltr : null,
        textAlign: align == pw.Alignment.centerRight ? pw.TextAlign.right : pw.TextAlign.center,
      ),
    );

/// جدول يبدأ من اليمين مع حدود كاملة (pw.Table لا يحترم RTL فنعكس الخلايا والأعرض).
/// حدود داخلية فقط (للجداول المُدرجة داخل بطاقة مؤطَّرة)؛ [top]/[bottom] اختياريان
pw.TableBorder innerBorder({double top = 0, double bottom = 0}) => pw.TableBorder(
      top: top > 0 ? pw.BorderSide(color: O.line, width: top) : pw.BorderSide.none,
      bottom: bottom > 0 ? pw.BorderSide(color: O.line, width: bottom) : pw.BorderSide.none,
      horizontalInside: const pw.BorderSide(color: O.line, width: 0.85),
      verticalInside: const pw.BorderSide(color: O.line, width: 0.85),
    );

/// إطار بطاقة موحّد (فاتورة داخل الكشف التفصيلي، دفعات على الحساب، ملخص)
pw.BoxDecoration cardDeco() => pw.BoxDecoration(border: pw.Border.all(color: O.line, width: 1.1));

/// شريط عنوان البطاقة (خلفية رأس الجدول + خط سفلي)
pw.Widget cardHeader(List<pw.Widget> children) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: const pw.BoxDecoration(color: O.headFill, border: pw.Border(bottom: pw.BorderSide(color: O.line, width: 1.1))),
      child: pw.Row(children: children),
    );

pw.Table officialTable({required Map<int, pw.TableColumnWidth> columnWidths, required List<pw.TableRow> children, pw.TableBorder? border}) {
  final n = children.first.children.length;
  final widths = <int, pw.TableColumnWidth>{};
  columnWidths.forEach((k, v) => widths[n - 1 - k] = v);
  return pw.Table(
    border: border ?? tableBorder(),
    columnWidths: widths,
    defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
    children: [
      for (final r in children)
        pw.TableRow(
          children: r.children.reversed.toList(),
          decoration: r.decoration,
          repeat: r.repeat,
          verticalAlignment: r.verticalAlignment,
        ),
    ],
  );
}

/* ---------- التذييل: بيانات البنك يسار + الختم يمين ---------- */
pw.Widget officialFooter(PdfAssets a, Org org, {bool website = false}) {
  final showBank = org.showBank && (org.bankAccount.isNotEmpty || org.iban.isNotEmpty);
  final contact = <String>[
    if (website && org.website.isNotEmpty) org.website,
    if (org.email.isNotEmpty) org.email,
    if (org.phone.isNotEmpty) org.phone,
  ];
  return pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
    // الختم يمين
    if (org.showStamp)
      pw.Row(children: [
        pw.Text('الختم:', style: a.t(10.2, color: O.ink)),
        pw.SizedBox(width: 4),
        pw.Image(a.stamp, width: 72, height: 72, fit: pw.BoxFit.contain),
      ]),
    pw.Spacer(),
    // البنك والتواصل يسار
    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
      if (showBank && org.bankAccount.isNotEmpty)
        pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
          pw.Text('رقم الحساب لدى ${org.bankName}: ', style: a.t(10.2, color: O.ink)),
          pw.Text(org.bankAccount, style: a.t(10.2, color: O.ink), textDirection: pw.TextDirection.ltr),
        ]),
      if (showBank && org.iban.isNotEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 3),
          // نص واحد LTR حتى لا يتبدّل ترتيب «IBAN:» والرقم داخل صف RTL
          child: pw.Text('IBAN: ${org.iban}', style: a.t(10.2, color: O.ink), textDirection: pw.TextDirection.ltr),
        ),
      if (contact.isNotEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 5),
          child: pw.Text(contact.join(' · '), style: a.t(10.2, color: O.brown, bold: true), textDirection: pw.TextDirection.ltr),
        ),
    ]),
  ]);
}

/// سطر ترقيم الصفحات (ذهبي، في المنتصف)
pw.Widget officialPageNum(PdfAssets a, pw.Context ctx, {String prefix = ''}) => pw.Center(
      child: pw.Text(
        '${prefix.isNotEmpty ? '$prefix — ' : ''}صفحة ${ctx.pageNumber} من ${ctx.pagesCount}',
        style: a.t(8.6, color: O.gold),
      ),
    );

/* ---------- سند القبض (نصف صفحة A4 = A5 عرضي) ---------- */
pw.PageTheme receiptPageTheme(PdfAssets a, Org org) => pw.PageTheme(
      pageFormat: PdfPageFormat.a5.landscape,
      theme: pw.ThemeData.withFont(base: a.regular, bold: a.bold).copyWith(
        defaultTextStyle: pw.TextStyle(font: a.regular, fontSize: 10.2, color: O.ink, lineSpacing: 1.3),
      ),
      textDirection: pw.TextDirection.rtl,
      margin: const pw.EdgeInsets.fromLTRB(18, 16, 18, 14),
      buildBackground: (ctx) => pw.FullPage(
        ignoreMargins: true,
        child: pw.Stack(children: [
          if (org.showWatermark)
            pw.Positioned(
              left: 0,
              right: 0,
              top: 110,
              child: pw.Center(child: pw.Opacity(opacity: 0.07, child: pw.Image(a.logo, width: 200))),
            ),
        ]),
      ),
    );

/// ترويسة مدمجة للسند: الشعار يمين، اسم المؤسسة بجواره، شارة مملوءة يسار.
pw.Widget receiptHeader(PdfAssets a, Org org, {required String title, required String subtitle}) => pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Image(a.logo, height: 58, fit: pw.BoxFit.contain),
        pw.SizedBox(width: 10),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(org.kingdom, style: a.t(9.4, color: O.ink)),
          pw.Text(org.name, style: a.t(14.2, color: O.brown, black: true)),
          if (org.showCr && org.cr.isNotEmpty)
            pw.Row(children: [
              pw.Text('س-ت ', style: a.t(9.2, color: O.gold, bold: true)),
              pw.Text(org.cr, style: a.t(9.2, color: O.gold, bold: true), textDirection: pw.TextDirection.ltr),
            ]),
          if (org.showVatNumber && org.vat.isNotEmpty)
            pw.Row(children: [
              pw.Text('الرقم الضريبي ', style: a.t(8.6, color: O.gold, bold: true)),
              pw.Text(org.vat, style: a.t(8.6, color: O.gold, bold: true), textDirection: pw.TextDirection.ltr),
            ]),
        ]),
        pw.Spacer(),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 7),
          decoration: pw.BoxDecoration(
            color: O.brown,
            borderRadius: pw.BorderRadius.circular(4),
            border: pw.Border.all(color: O.gold, width: 0.8),
          ),
          child: pw.Column(children: [
            pw.Text(title, style: a.t(15, color: O.white, black: true)),
            pw.SizedBox(height: 1),
            pw.Text(subtitle, style: a.t(7.4, color: O.gold, bold: true), textDirection: pw.TextDirection.ltr),
          ]),
        ),
      ],
    );

/// حقل بخط منقّط: التسمية بنية عريضة والقيمة بعدها.
pw.Widget dottedField(PdfAssets a, String label, String value, {bool ltr = false, double size = 10.4, int flex = 1}) => pw.Expanded(
      flex: flex,
      child: pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 3),
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: O.gold, width: 0.7, style: pw.BorderStyle.dotted))),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text('$label: ', style: a.t(size, color: O.brown, bold: true)),
          pw.Expanded(
            child: pw.Text(value.isEmpty ? '—' : value,
                style: a.t(size, color: O.ink), textDirection: ltr ? pw.TextDirection.ltr : null, textAlign: ltr ? pw.TextAlign.right : null),
          ),
        ]),
      ),
    );

/// مربع اختيار مع تسمية (مملوء عند التحديد)
pw.Widget checkBox(PdfAssets a, String label, bool on, {double size = 9.6}) => pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
      pw.Container(
        width: 9,
        height: 9,
        decoration: pw.BoxDecoration(border: pw.Border.all(color: O.brown, width: 0.9), borderRadius: pw.BorderRadius.circular(1.5)),
        child: on ? pw.Center(child: pw.Container(width: 5, height: 5, color: O.brown)) : null,
      ),
      pw.SizedBox(width: 4),
      pw.Text(label, style: a.t(size, color: O.ink, bold: on)),
    ]);

/// صندوق بإطار (يُستخدم لرقم السند/التاريخ/المبلغ/طريقة الدفع)
pw.Widget framedBox(pw.Widget child, {PdfColor? fill, double hPad = 10, double vPad = 6}) => pw.Container(
      padding: pw.EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: pw.BoxDecoration(color: fill, border: pw.Border.all(color: O.line, width: 1.1), borderRadius: pw.BorderRadius.circular(3)),
      child: child,
    );

/// شريط التذييل البني: البريد · الموقع · الجوال
pw.Widget receiptFooterBand(PdfAssets a, Org org) {
  final items = <String>[
    if (org.email.isNotEmpty) org.email,
    if (org.website.isNotEmpty) org.website,
    if (org.phone.isNotEmpty) org.phone,
  ];
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 5),
    decoration: pw.BoxDecoration(color: O.brown, borderRadius: pw.BorderRadius.circular(3)),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        for (final s in items) pw.Text(s, style: a.t(9, color: O.white), textDirection: pw.TextDirection.ltr),
      ],
    ),
  );
}
