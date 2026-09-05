/// pdf_theme.dart — نظام التصميم الملكي الفاخر للمستندات | كيف الضيافة
/// وفق DESIGN-SPEC: كحلي + ذهبي + كريمي، إطار ذهبي مزدوج، زخارف أركان.
library;

import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/models.dart';

/* ---------- الألوان ---------- */
class K {
  static const navy = PdfColor.fromInt(0xFF17264F);
  static const navyDeep = PdfColor.fromInt(0xFF0E1A3A);
  static const navyLight = PdfColor.fromInt(0xFF1F3266);
  static const gold = PdfColor.fromInt(0xFFC9A961);
  static const goldDark = PdfColor.fromInt(0xFFA88938);
  static const goldLight = PdfColor.fromInt(0xFFDFC689);
  static const cream = PdfColor.fromInt(0xFFFBF5EA);
  static const beige = PdfColor.fromInt(0xFFF3E7D0);
  static const beigeSoft = PdfColor.fromInt(0xFFFAEFDA);
  static const ink = PdfColor.fromInt(0xFF1A1A1A);
  static const muted = PdfColor.fromInt(0xFF5B5B6B);
  static const line = PdfColor.fromInt(0xFFE2D6BC);
  static const red = PdfColor.fromInt(0xFFB4232C);
  static const green = PdfColor.fromInt(0xFF1E7B4F);
  static const white = PdfColors.white;
}

const double mm = PdfPageFormat.mm;

/* ---------- الخطوط والصور ---------- */
class PdfAssets {
  static PdfAssets? _i;
  final pw.Font regular, bold, black;
  final pw.MemoryImage logo, stamp;

  PdfAssets._(this.regular, this.bold, this.black, this.logo, this.stamp);

  static Future<PdfAssets> load() async {
    if (_i != null) return _i!;
    final r = await rootBundle.load('assets/fonts/Tajawal-Regular.ttf');
    final b = await rootBundle.load('assets/fonts/Tajawal-Bold.ttf');
    final k = await rootBundle.load('assets/fonts/Tajawal-Black.ttf');
    final logo = await rootBundle.load('assets/img/logo.png');
    final stamp = await rootBundle.load('assets/img/stamp.png');
    _i = PdfAssets._(
      pw.Font.ttf(r),
      pw.Font.ttf(b),
      pw.Font.ttf(k),
      pw.MemoryImage(_u8(logo)),
      pw.MemoryImage(_u8(stamp)),
    );
    return _i!;
  }

  static Uint8List _u8(ByteData d) => d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes);

  pw.ThemeData theme() => pw.ThemeData.withFont(base: regular, bold: bold).copyWith(
        defaultTextStyle: pw.TextStyle(font: regular, fontSize: 9.5, color: K.ink, lineSpacing: 1.5),
      );

  pw.TextStyle t(double size, {PdfColor color = K.ink, bool bold = false, bool black = false}) =>
      pw.TextStyle(
        font: black ? this.black : (bold ? this.bold : regular),
        fontSize: size,
        color: color,
        fontWeight: bold || black ? pw.FontWeight.bold : pw.FontWeight.normal,
      );
}

/* ---------- الصفحة: إطار ذهبي مزدوج + زخارف أركان + علامة مائية ---------- */
pw.PageTheme royalPageTheme(PdfAssets a, Org org) {
  return pw.PageTheme(
    pageFormat: PdfPageFormat.a4,
    theme: a.theme(),
    textDirection: pw.TextDirection.rtl,
    margin: const pw.EdgeInsets.fromLTRB(11 * mm, 10 * mm, 11 * mm, 10 * mm),
    buildBackground: (ctx) => pw.FullPage(
      ignoreMargins: true,
      child: pw.Stack(children: [
        pw.Positioned.fill(child: pw.Container(color: K.cream)),
        if (org.showWatermark)
          pw.Center(
            child: pw.Opacity(
              opacity: 0.06,
              child: pw.Image(a.logo, width: 110 * mm),
            ),
          ),
        pw.Positioned.fill(child: pw.CustomPaint(painter: _frame)),
      ]),
    ),
  );
}

void _frame(PdfGraphics c, PdfPoint size) {
  final w = size.x, h = size.y;
  // الإطار الخارجي 0.7mm على بعد 5mm
  c
    ..setStrokeColor(K.gold)
    ..setLineWidth(0.7 * mm)
    ..drawRect(5 * mm, 5 * mm, w - 10 * mm, h - 10 * mm)
    ..strokePath();
  // الإطار الداخلي 0.2mm على بعد 7mm
  c
    ..setStrokeColor(K.goldDark)
    ..setLineWidth(0.2 * mm)
    ..drawRect(7 * mm, 7 * mm, w - 14 * mm, h - 14 * mm)
    ..strokePath();
  // زخارف الأركان (16mm)
  const s = 16 * mm;
  _corner(c, 5 * mm, h - 5 * mm, 1, -1, s); // أعلى يسار
  _corner(c, w - 5 * mm, h - 5 * mm, -1, -1, s); // أعلى يمين
  _corner(c, 5 * mm, 5 * mm, 1, 1, s); // أسفل يسار
  _corner(c, w - 5 * mm, 5 * mm, -1, 1, s); // أسفل يمين
}

/// زخرفة ركن: قوس ذهبي مزدوج + معيّن مملوء + نقاط مشعّة
void _corner(PdfGraphics c, double x, double y, int dx, int dy, double s) {
  // منحنى كريمي مملوء يغطي تقاطع الإطارين في الركن
  c
    ..setFillColor(K.cream)
    ..moveTo(x, y)
    ..lineTo(x + dx * s * 0.62, y)
    ..curveTo(x + dx * s * 0.62, y + dy * s * 0.34, x + dx * s * 0.34, y + dy * s * 0.62, x, y + dy * s * 0.62)
    ..closePath()
    ..fillPath();
  // القوس الخارجي السميك
  c
    ..setStrokeColor(K.gold)
    ..setLineWidth(0.7 * mm)
    ..moveTo(x + dx * s * 0.62, y)
    ..curveTo(x + dx * s * 0.62, y + dy * s * 0.34, x + dx * s * 0.34, y + dy * s * 0.62, x, y + dy * s * 0.62)
    ..strokePath();
  // القوس الداخلي الرفيع
  c
    ..setStrokeColor(K.goldDark)
    ..setLineWidth(0.2 * mm)
    ..moveTo(x + dx * s * 0.62, y + dy * 2 * mm)
    ..curveTo(x + dx * s * 0.62, y + dy * s * 0.30, x + dx * s * 0.30, y + dy * s * 0.62, x + dx * 2 * mm, y + dy * s * 0.62)
    ..strokePath();
  // معيّن ذهبي في قلب الركن
  final cx = x + dx * s * 0.28, cy = y + dy * s * 0.28;
  const r = 1.6 * mm;
  c
    ..setFillColor(K.gold)
    ..moveTo(cx, cy - r)
    ..lineTo(cx + r, cy)
    ..lineTo(cx, cy + r)
    ..lineTo(cx - r, cy)
    ..closePath()
    ..fillPath();
  // نقاط مشعّة على الضلعين
  c.setFillColor(K.goldDark);
  for (final f in [0.48, 0.58]) {
    c
      ..drawEllipse(x + dx * s * f, y + dy * s * 0.12, 0.5 * mm, 0.5 * mm)
      ..fillPath()
      ..drawEllipse(x + dx * s * 0.12, y + dy * s * f, 0.5 * mm, 0.5 * mm)
      ..fillPath();
  }
  c
    ..setFillColor(K.gold)
    ..drawEllipse(x + dx * s * 0.08, y + dy * s * 0.08, 0.7 * mm, 0.7 * mm)
    ..fillPath();
}

/* ---------- الترويسة ---------- */
pw.Widget royalHeader(PdfAssets a, Org org) {
  return pw.Column(children: [
    pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
      // الشعار مباشرة على الخلفية بدون صندوق
      pw.SizedBox(
        width: 26 * mm,
        height: 26 * mm,
        child: pw.Image(a.logo, fit: pw.BoxFit.contain),
      ),
      pw.SizedBox(width: 4 * mm),
      pw.Expanded(
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 3 * mm, vertical: 0.8 * mm),
            decoration: pw.BoxDecoration(
              gradient: const pw.LinearGradient(colors: [K.goldDark, K.gold, K.goldLight]),
              borderRadius: pw.BorderRadius.circular(3 * mm),
            ),
            child: pw.Text(org.kingdom, style: a.t(7.5, color: K.navyDeep, bold: true)),
          ),
          pw.SizedBox(height: 1.2 * mm),
          pw.Text(org.name, style: a.t(15, color: K.navy, black: true)),
          pw.Text(org.nameEn, style: pw.TextStyle(font: a.bold, fontSize: 8, color: K.goldDark, letterSpacing: 1.2)),
          pw.SizedBox(height: 1.2 * mm),
          pw.Row(children: [
            if (org.showCr && org.cr.isNotEmpty) _pill(a, 'س.ت', org.cr),
            if (org.showCr && org.cr.isNotEmpty && org.showVatNumber && org.vat.isNotEmpty) pw.SizedBox(width: 2 * mm),
            if (org.showVatNumber && org.vat.isNotEmpty) _pill(a, 'الرقم الضريبي', org.vat),
          ]),
        ]),
      ),
      // بطاقة الاتصال يسار الترويسة
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        _contact(a, org.phone),
        _contact(a, org.website),
        _contact(a, org.email),
        _contact(a, '${org.city}، ${org.kingdom}', ltr: false),
      ]),
    ]),
    pw.SizedBox(height: 2.5 * mm),
    goldRule(),
  ]);
}

pw.Widget _pill(PdfAssets a, String label, String value) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 2.2 * mm, vertical: 0.6 * mm),
      decoration: pw.BoxDecoration(
        color: K.navy,
        borderRadius: pw.BorderRadius.circular(2.5 * mm),
        border: pw.Border.all(color: K.gold, width: 0.3),
      ),
      child: pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
        pw.Text('$label  ', style: a.t(6.8, color: K.goldLight)),
        pw.Text(value, style: pw.TextStyle(font: a.bold, fontSize: 7.5, color: K.white, letterSpacing: 0.4)),
      ]),
    );

/// سطر اتصال في الترويسة. [ltr] للأرقام/الروابط/البريد، و false للنص العربي (العنوان).
pw.Widget _contact(PdfAssets a, String v, {bool ltr = true}) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 0.9 * mm),
      child: pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
        pw.Text(v, style: a.t(7.6, color: K.navy), textDirection: ltr ? pw.TextDirection.ltr : pw.TextDirection.rtl),
        pw.SizedBox(width: 1.5 * mm),
        pw.Container(width: 1.6 * mm, height: 1.6 * mm, decoration: const pw.BoxDecoration(color: K.gold, shape: pw.BoxShape.circle)),
      ]),
    );

/// خط ذهبي مزدوج فاصل
pw.Widget goldRule() => pw.Column(children: [
      pw.Container(height: 0.6, decoration: const pw.BoxDecoration(gradient: pw.LinearGradient(colors: [K.goldLight, K.gold, K.goldDark, K.gold, K.goldLight]))),
      pw.SizedBox(height: 0.7 * mm),
      pw.Container(height: 0.25, color: K.goldDark),
    ]);

/* ---------- شريط العنوان الذهبي ---------- */
pw.Widget titleBand(PdfAssets a, String ar, String en, {String? badge, PdfColor badgeColor = K.navy}) {
  return pw.Container(
    height: 12 * mm,
    decoration: pw.BoxDecoration(
      gradient: const pw.LinearGradient(colors: [K.goldDark, K.gold, K.goldLight, K.gold, K.goldDark]),
      borderRadius: pw.BorderRadius.circular(1.5 * mm),
    ),
    padding: const pw.EdgeInsets.symmetric(horizontal: 4 * mm),
    child: pw.Row(children: [
      pw.Text(ar, style: a.t(15, color: K.navyDeep, black: true)),
      pw.SizedBox(width: 3 * mm),
      pw.Container(width: 0.4, height: 6 * mm, color: K.navy),
      pw.SizedBox(width: 3 * mm),
      pw.Text(en, style: pw.TextStyle(font: a.bold, fontSize: 10.5, color: K.navyDeep, letterSpacing: 2), textDirection: pw.TextDirection.ltr),
      pw.Spacer(),
      if (badge != null)
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3 * mm, vertical: 1 * mm),
          decoration: pw.BoxDecoration(color: badgeColor, borderRadius: pw.BorderRadius.circular(2 * mm)),
          child: pw.Text(badge, style: a.t(8, color: K.white, bold: true)),
        ),
    ]),
  );
}

/* ---------- بطاقة البيانات البيج ---------- */
pw.Widget dataCard(PdfAssets a, {required String title, required List<(String, String)> rows, pw.Widget? trailing}) {
  return pw.Container(
    decoration: pw.BoxDecoration(
      color: K.beigeSoft,
      border: pw.Border.all(color: K.gold, width: 0.4),
      borderRadius: pw.BorderRadius.circular(2 * mm),
    ),
    padding: const pw.EdgeInsets.fromLTRB(3 * mm, 2 * mm, 3 * mm, 2 * mm),
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Row(children: [
        pw.Container(width: 1.2 * mm, height: 4 * mm, color: K.gold),
        pw.SizedBox(width: 1.5 * mm),
        pw.Text(title, style: a.t(8.5, color: K.navy, bold: true)),
        if (trailing != null) pw.Spacer(),
        if (trailing != null) trailing,
      ]),
      pw.SizedBox(height: 1.2 * mm),
      for (final r in rows)
        if (r.$2.isNotEmpty)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 0.9 * mm),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: K.line, width: 0.3, style: pw.BorderStyle.dashed)),
            ),
            child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              goldDiamond(1.6 * mm),
              pw.SizedBox(width: 1.2 * mm),
              pw.SizedBox(width: 26 * mm, child: pw.Text(r.$1, style: a.t(7.6, color: K.muted), maxLines: 1, softWrap: false)),
              pw.Expanded(child: pw.Text(r.$2, style: a.t(8.2, color: K.ink, bold: true))),
            ]),
          ),
    ]),
  );
}

/* ---------- الدائرة الذهبية المرقّمة ---------- */
pw.Widget numCircle(PdfAssets a, int n) => pw.Container(
      width: 5 * mm,
      height: 5 * mm,
      alignment: pw.Alignment.center,
      decoration: const pw.BoxDecoration(
        shape: pw.BoxShape.circle,
        gradient: pw.LinearGradient(colors: [K.goldDark, K.gold, K.goldLight]),
      ),
      child: pw.Text('$n', style: a.t(7.5, color: K.navyDeep, bold: true)),
    );

/// رأس جدول كحلي متدرّج بنص ذهبي
pw.BoxDecoration tableHeadDeco() => const pw.BoxDecoration(
      gradient: pw.LinearGradient(colors: [K.navyDeep, K.navy, K.navyLight]),
    );

pw.Widget th(PdfAssets a, String t, {pw.Alignment align = pw.Alignment.center}) => pw.Container(
      alignment: align,
      padding: const pw.EdgeInsets.symmetric(horizontal: 2 * mm, vertical: 2.2 * mm),
      child: pw.Text(t, style: a.t(8, color: K.goldLight, bold: true)),
    );

pw.Widget td(PdfAssets a, String t,
        {pw.Alignment align = pw.Alignment.center, bool bold = false, PdfColor color = K.ink, double size = 8.2, bool ltr = false}) =>
    pw.Container(
      alignment: align,
      padding: const pw.EdgeInsets.symmetric(horizontal: 2 * mm, vertical: 1.8 * mm),
      child: pw.Text(t, style: a.t(size, color: color, bold: bold), textDirection: ltr ? pw.TextDirection.ltr : null),
    );

/// جدول يبدأ من اليمين (ملاحظة 6): pw.Table لا يحترم اتجاه RTL،
/// لذا نعكس ترتيب الخلايا وأعرض الأعمدة يدويًا ليصبح العمود الأول أقصى اليمين.
pw.Table rtlTable({required Map<int, pw.TableColumnWidth> columnWidths, required List<pw.TableRow> children}) {
  if (children.isEmpty) return pw.Table(columnWidths: columnWidths, children: children);
  final n = children.first.children.length;
  final widths = <int, pw.TableColumnWidth>{};
  columnWidths.forEach((k, v) => widths[n - 1 - k] = v);
  return pw.Table(
    columnWidths: widths,
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

/* ---------- كتلة التذييل الكحلية ---------- */
/// التذييل: سطر بنكي واضح (رقم الحساب + IBAN) ثم سطر التواصل. خطوط مقروءة 8.5–9.5pt.
/// لا يظهر إلا ما فُعِّل في «إعدادات الفواتير» (showBank / showCr).
pw.Widget royalFooter(PdfAssets a, Org org, {bool bank = true}) {
  final showBank = bank && org.showBank && (org.bankAccount.isNotEmpty || org.iban.isNotEmpty);
  final contacts = <(String, String)>[
    if (org.phone.isNotEmpty) ('الهاتف', org.phone),
    if (org.website.isNotEmpty) ('الموقع', org.website),
    if (org.email.isNotEmpty) ('البريد', org.email),
    if (org.showCr && org.cr.isNotEmpty) ('س.ت', org.cr),
  ];
  return pw.Container(
    decoration: pw.BoxDecoration(
      gradient: const pw.LinearGradient(colors: [K.navyDeep, K.navy]),
      borderRadius: pw.BorderRadius.circular(2 * mm),
      border: pw.Border.all(color: K.gold, width: 0.4),
    ),
    padding: const pw.EdgeInsets.symmetric(horizontal: 4 * mm, vertical: 2.4 * mm),
    child: pw.Column(children: [
      if (showBank)
        pw.Row(children: [
          if (org.bankAccount.isNotEmpty) ...[
            pw.Text('رقم الحساب لدى ${org.bankName}  ', style: a.t(8.6, color: K.goldLight, bold: true)),
            pw.Text(org.bankAccount, style: pw.TextStyle(font: a.bold, fontSize: 9.6, color: K.white, letterSpacing: 0.4), textDirection: pw.TextDirection.ltr),
          ],
          pw.Spacer(),
          if (org.iban.isNotEmpty) ...[
            pw.Text('   IBAN', style: pw.TextStyle(font: a.bold, fontSize: 8.6, color: K.goldLight), textDirection: pw.TextDirection.ltr),
            pw.Text(org.ibanSpaced, style: pw.TextStyle(font: a.bold, fontSize: 9.6, color: K.white, letterSpacing: 0.5), textDirection: pw.TextDirection.ltr),
          ],
        ]),
      if (showBank) pw.SizedBox(height: 1.8 * mm),
      if (showBank) pw.Container(height: 0.3, color: K.gold),
      if (showBank) pw.SizedBox(height: 1.8 * mm),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        for (final c in contacts) _fcol(a, c.$1, c.$2),
      ]),
    ]),
  );
}

pw.Widget _fcol(PdfAssets a, String l, String v) => pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
      pw.Container(width: 1.5 * mm, height: 1.5 * mm, decoration: const pw.BoxDecoration(color: K.gold, shape: pw.BoxShape.circle)),
      pw.SizedBox(width: 1.5 * mm),
      pw.Text('$l  ', style: a.t(8, color: K.goldLight)),
      pw.Text(v, style: a.t(8.8, color: K.white, bold: true), textDirection: pw.TextDirection.ltr),
    ]);

/// سطر ترقيم الصفحات
pw.Widget pageNum(PdfAssets a, pw.Context ctx, String docLabel) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 1.5 * mm),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(docLabel, style: a.t(7.6, color: K.muted)),
        pw.Text('صفحة ${ctx.pageNumber} من ${ctx.pagesCount}', style: a.t(7.6, color: K.muted)),
      ]),
    );

/// صناديق التوقيع + الختم
pw.Widget signatures(PdfAssets a, Org org, {String right = 'المدير العام', String left = 'توقيع العميل'}) {
  return pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
    pw.Expanded(child: _sigBox(a, right, stamp: org.showStamp ? a.stamp : null)),
    pw.SizedBox(width: 6 * mm),
    pw.Expanded(child: _sigBox(a, left)),
  ]);
}

pw.Widget _sigBox(PdfAssets a, String label, {pw.MemoryImage? stamp}) => pw.Container(
      height: 24 * mm,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: K.gold, width: 0.4),
        borderRadius: pw.BorderRadius.circular(1.5 * mm),
      ),
      child: pw.Stack(children: [
        if (stamp != null)
          pw.Positioned(left: 4 * mm, top: 1 * mm, child: pw.Opacity(opacity: 0.9, child: pw.Image(stamp, height: 20 * mm))),
        pw.Positioned(
          right: 0,
          top: 0,
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 2.5 * mm, vertical: 0.8 * mm),
            decoration: pw.BoxDecoration(
              color: K.navy,
              borderRadius: const pw.BorderRadius.only(topRight: pw.Radius.circular(1.5 * mm), bottomLeft: pw.Radius.circular(1.5 * mm)),
            ),
            child: pw.Text(label, style: a.t(7, color: K.goldLight, bold: true)),
          ),
        ),
        pw.Positioned(
          right: 3 * mm,
          left: 3 * mm,
          bottom: 3 * mm,
          child: pw.Container(height: 0.3, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: K.goldDark, width: 0.3, style: pw.BorderStyle.dotted)))),
        ),
      ]),
    );

/// معيّن ذهبي صغير مرسوم (بديل رمز ◆ غير المتوفر في الخط).
pw.Widget goldDiamond(double size, {PdfColor color = K.gold}) => pw.Padding(
      padding: pw.EdgeInsets.only(top: size * 0.55),
      child: pw.Transform.rotateBox(
        angle: 0.785398,
        child: pw.Container(width: size, height: size, color: color),
      ),
    );
