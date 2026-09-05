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
  static const red = PdfColor.fromInt(0xFFB3372E); // المتبقي
  static const headFill = PdfColor.fromInt(0xFFF0E3CC); // رأس الجدول
  static const line = PdfColor.fromInt(0xFFCCBDA8); // حدود الجدول
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

pw.TableBorder tableBorder() => pw.TableBorder.all(color: O.line, width: 0.6);

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
pw.Table officialTable({required Map<int, pw.TableColumnWidth> columnWidths, required List<pw.TableRow> children}) {
  final n = children.first.children.length;
  final widths = <int, pw.TableColumnWidth>{};
  columnWidths.forEach((k, v) => widths[n - 1 - k] = v);
  return pw.Table(
    border: tableBorder(),
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
