/// money.dart — نواة المال والتفقيط | كيف الضيافة
/// كل المبالغ تُخزَّن كأعداد صحيحة بالهللة (1 ريال = 100 هللة)
/// لمنع أخطاء الفاصلة العائمة تمامًا.
library;

/// تقريب نصفي لأعلى (2.5 → 3، -2.5 → -3)
int roundHalfUp(num x) =>
    x >= 0 ? (x + 0.5).floor() : -((-x + 0.5).floor());

/// تحويل أي إدخال (نص/رقم) إلى هللات صحيحة
int toHalalas(Object? v) {
  if (v == null) return 0;
  if (v is num) return v.isFinite ? (v * 100).round() : 0;
  const ar = '٠١٢٣٤٥٦٧٨٩';
  var s = v.toString().trim();
  if (s.isEmpty) return 0;
  // أرقام عربية -> لاتينية
  s = s.replaceAllMapped(RegExp('[٠-٩]'), (m) => '${ar.indexOf(m[0]!)}');
  // الفاصلة العشرية العربية -> نقطة
  s = s.replaceAll('٫', '.');
  // إزالة رموز العملة (تحتوي نقاطًا تُفسد القراءة: "ر.س")
  s = s.replaceAll(RegExp(r'ر\.?\s*س|ريال|SAR|SR', caseSensitive: false), ' ');
  // الصيغة العلمية مرفوضة
  if (RegExp(r'\de\s*[+-]?\d', caseSensitive: false).hasMatch(s)) return 0;
  // إزالة فواصل الآلاف والمسافات
  s = s.replaceAll(RegExp('[,\\s\u00A0\u066C]'), '');
  final m = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(s);
  if (m == null) return 0;
  final n = double.tryParse(m[0]!);
  if (n == null || !n.isFinite) return 0;
  return (n * 100).round();
}

/// مبلغ غير سالب — للأسعار والكميات والدفعات
int toHalalasPositive(Object? v) {
  final n = toHalalas(v);
  return n < 0 ? 0 : n;
}

/// تحويل نص كمية إلى عدد (يقبل الأرقام العربية)
double toQty(Object? v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  const ar = '٠١٢٣٤٥٦٧٨٩';
  var s = v.toString().trim();
  s = s.replaceAllMapped(RegExp('[٠-٩]'), (m) => '${ar.indexOf(m[0]!)}');
  s = s.replaceAll('٫', '.').replaceAll(',', '');
  final m = RegExp(r'\d+(?:\.\d+)?').firstMatch(s);
  return m == null ? 0 : (double.tryParse(m[0]!) ?? 0);
}

String _group(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

/// تنسيق الرقم: 2131000 -> "21,310.00"
String fmt(int halalas, {int decimals = 2, bool trimZeros = false}) {
  final neg = halalas < 0;
  final abs = halalas.abs();
  final int_ = abs ~/ 100;
  final frac = abs % 100;
  final intStr = _group(int_);
  var out = decimals == 0
      ? intStr
      : '$intStr.${frac.toString().padLeft(2, '0')}';
  if (trimZeros && frac == 0) out = intStr;
  return (neg ? '-' : '') + out;
}

/// "5,780.00 ر.س"
String fmtSAR(int halalas, {bool trimZeros = false}) =>
    '${fmt(halalas, trimZeros: trimZeros)} ر.س';

/// "21,310 ر.س" — يحذف الكسور إذا كانت صفرًا
String fmtSARSmart(int halalas) => fmtSAR(halalas, trimZeros: true);

/// تنسيق كمية: 2 -> "2"، 1.5 -> "1.5"
String fmtQty(double q) {
  if (q == q.roundToDouble()) return q.toInt().toString();
  var s = q.toStringAsFixed(2);
  s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  return s;
}

/* ------------------------------------------------------------
   التفقيط — قواعد تمييز العدد العربية
   ------------------------------------------------------------ */

const _onesM = ['', 'واحد', 'اثنان', 'ثلاثة', 'أربعة', 'خمسة', 'ستة', 'سبعة', 'ثمانية', 'تسعة'];
const _onesF = ['', 'واحدة', 'اثنتان', 'ثلاث', 'أربع', 'خمس', 'ست', 'سبع', 'ثماني', 'تسع'];
const _teensM = ['', 'أحد', 'اثنا', 'ثلاثة', 'أربعة', 'خمسة', 'ستة', 'سبعة', 'ثمانية', 'تسعة'];
const _teensF = ['', 'إحدى', 'اثنتا', 'ثلاث', 'أربع', 'خمس', 'ست', 'سبع', 'ثماني', 'تسع'];
const _tens = ['', 'عشرة', 'عشرون', 'ثلاثون', 'أربعون', 'خمسون', 'ستون', 'سبعون', 'ثمانون', 'تسعون'];
const _hundreds = ['', 'مائة', 'مائتان', 'ثلاثمائة', 'أربعمائة', 'خمسمائة', 'ستمائة', 'سبعمائة', 'ثمانمائة', 'تسعمائة'];

/// [مفرد, مثنى, جمع(3-10), منصوب مُنوَّن(11-99)]
const _scales = <List<String>?>[
  null,
  ['ألف', 'ألفان', 'آلاف', 'ألفًا'],
  ['مليون', 'مليونان', 'ملايين', 'مليونًا'],
  ['مليار', 'ملياران', 'مليارات', 'مليارًا'],
  ['تريليون', 'تريليونان', 'تريليونات', 'تريليونًا'],
];

String _toConstruct(String w) {
  const map = {
    'مائتان': 'مائتا',
    'ألفان': 'ألفا',
    'مليونان': 'مليونا',
    'ملياران': 'مليارا',
    'تريليونان': 'تريليونا',
    'ألفًا': 'ألف',
    'مليونًا': 'مليون',
    'مليارًا': 'مليار',
    'تريليونًا': 'تريليون',
    'اثنان': 'اثنا',
    'اثنتان': 'اثنتا',
  };
  for (final e in map.entries) {
    if (w.endsWith(e.key)) {
      return w.substring(0, w.length - e.key.length) + e.value;
    }
  }
  return w;
}

String _under1000(int n, bool fem) {
  final parts = <String>[];
  final h = n ~/ 100;
  final rem = n % 100;
  if (h > 0) parts.add(_hundreds[h]);
  if (rem > 0) {
    final u = rem % 10;
    final t = rem ~/ 10;
    final ones = fem ? _onesF : _onesM;
    if (rem < 10) {
      parts.add(ones[rem]);
    } else if (rem == 10) {
      parts.add(fem ? 'عشر' : 'عشرة');
    } else if (rem < 20) {
      final teens = fem ? _teensF : _teensM;
      parts.add('${teens[u]} ${fem ? 'عشرة' : 'عشر'}');
    } else {
      if (u > 0) parts.add(ones[u]);
      parts.add(_tens[t]);
    }
  }
  return parts.join(' و');
}

/// العدد الصحيح إلى كلمات
String intToWords(int num, {bool fem = false}) {
  if (num == 0) return 'صفر';
  final groups = <int>[];
  var n = num.abs();
  while (n > 0) {
    groups.add(n % 1000);
    n ~/= 1000;
  }
  final chunks = <String>[];
  for (var i = groups.length - 1; i >= 0; i--) {
    final g = groups[i];
    if (g == 0) continue;
    if (i == 0) {
      chunks.add(_under1000(g, fem));
      continue;
    }
    final sc = _scales[i < _scales.length ? i : 4]!;
    final last2 = g % 100;
    if (g == 1) {
      chunks.add(sc[0]);
    } else if (g == 2) {
      chunks.add(sc[1]);
    } else if (last2 >= 3 && last2 <= 10) {
      chunks.add('${_under1000(g, false)} ${sc[2]}');
    } else if (last2 == 0) {
      chunks.add('${_toConstruct(_under1000(g, false))} ${sc[0]}');
    } else {
      chunks.add('${_under1000(g, false)} ${sc[3]}');
    }
  }
  return chunks.join(' و');
}

class _Forms {
  final String one, two, plural, acc;
  const _Forms(this.one, this.two, this.plural, this.acc);
}

const _riyal = _Forms('ريال سعودي', 'ريالان سعوديان', 'ريالات سعودية', 'ريالًا سعوديًا');
const _halala = _Forms('هللة', 'هللتان', 'هللات', 'هللة');

String _amountPhrase(int n, _Forms f, bool fem) {
  if (n == 1) return f.one;
  if (n == 2) return f.two;
  final last2 = n % 100;
  String unit;
  var construct = false;
  if (last2 >= 3 && last2 <= 10) {
    unit = f.plural;
  } else if (last2 == 0) {
    unit = f.one;
    construct = true;
  } else if (last2 == 1 || last2 == 2) {
    unit = f.one;
  } else {
    unit = f.acc;
  }
  var words = intToWords(n, fem: fem);
  if (construct) words = _toConstruct(words);
  return '$words $unit';
}

/// التفقيط الكامل: "فقط واحد وعشرون ألفًا وثلاثمائة وعشرة ريالات سعودية لا غير"
String tafqit(int halalas) {
  final h = halalas.abs();
  final riyals = h ~/ 100;
  final cents = h % 100;
  if (riyals == 0 && cents == 0) return 'فقط صفر ريال سعودي لا غير';
  final parts = <String>[];
  if (riyals > 0) parts.add(_amountPhrase(riyals, _riyal, false));
  if (cents > 0) parts.add(_amountPhrase(cents, _halala, true));
  final sign = halalas < 0 ? 'سالب ' : '';
  return 'فقط $sign${parts.join(' و')} لا غير';
}
