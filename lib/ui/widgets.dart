/// widgets.dart — عناصر واجهة مشتركة | كيف الضيافة
library;

import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/money.dart';
import 'theme.dart';

/* ============================================================
   الأيقونات ثلاثية الأبعاد (assets/ic — PNG من التصميم الأصلي)
   ============================================================ */
class Ic {
  static const alert = 'alert', calendar = 'calendar', cash = 'cash', chart = 'chart', check = 'check';
  static const clients = 'clients', dallah = 'dallah', edit = 'edit', gear = 'gear', invoice = 'invoice';
  static const pdf = 'pdf', phone = 'phone', pin = 'pin', plus = 'plus', print = 'print', search = 'search';
  static const share = 'share', stamp = 'stamp', statement = 'statement', trash = 'trash';
}

class KIcon extends StatelessWidget {
  final String name;
  final double size;
  final double opacity;
  const KIcon(this.name, {super.key, this.size = 28, this.opacity = 1});
  @override
  Widget build(BuildContext context) => Opacity(
        opacity: opacity,
        child: Image.asset('assets/ic/$name.png', width: size, height: size, filterQuality: FilterQuality.medium),
      );
}

/* ============================================================
   Plate — اللوح الزجاجي ثلاثي الأبعاد (premium.css .plate)
   ============================================================ */
class Plate extends StatelessWidget {
  final Widget child;
  final PlateColor color;
  final double size;
  final VoidCallback? onTap;
  const Plate({super.key, required this.child, this.color = PlateColor.gold, this.size = 56, this.onTap});

  /// لوح يحمل أيقونة 3D (الأيقونة ≈ 60% من اللوح)
  factory Plate.icon(String icon, {Key? key, PlateColor color = PlateColor.gold, double size = 56, VoidCallback? onTap}) =>
      Plate(key: key, color: color, size: size, onTap: onTap, child: KIcon(icon, size: size * 0.6));

  /// لوح يحمل أيقونة Material (لون الحبر من اللوح)
  factory Plate.material(IconData icon, {Key? key, PlateColor color = PlateColor.gold, double size = 56, VoidCallback? onTap}) =>
      Plate(key: key, color: color, size: size, onTap: onTap, child: Icon(icon, size: size * 0.5, color: PlateTones.of(color).ink));

  @override
  Widget build(BuildContext context) {
    final t = PlateTones.of(color);
    final r = BorderRadius.circular(size * 0.28);
    Widget plate = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: r,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.top, Color.lerp(t.top, t.body, 0.55)!, t.body, Color.lerp(t.body, t.bottom, 0.45)!, t.bottom],
          stops: const [0, 0.22, 0.52, 0.78, 1],
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: C.isDark ? 0.42 : 0.18), blurRadius: 8, offset: const Offset(0, 4)),
          BoxShadow(color: Colors.black.withValues(alpha: C.isDark ? 0.5 : 0.12), blurRadius: 22, offset: const Offset(0, 10), spreadRadius: -6),
          BoxShadow(color: t.glow.withValues(alpha: 0.38), blurRadius: 18, offset: const Offset(0, 6), spreadRadius: -4),
        ],
      ),
      child: Stack(children: [
        // حلقة داخلية + خط علوي لامع
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: r,
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white.withValues(alpha: 0.32), Colors.white.withValues(alpha: 0.06), Colors.transparent, Colors.black.withValues(alpha: 0.22)],
                stops: const [0, 0.18, 0.55, 1],
              ),
            ),
          ),
        ),
        // بريق العدسة العلوي
        Positioned(
          top: size * 0.06,
          left: size * 0.12,
          right: size * 0.12,
          height: size * 0.36,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(size * 0.22), bottom: Radius.elliptical(size * 0.4, size * 0.2)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white.withValues(alpha: 0.42), Colors.white.withValues(alpha: 0.0)],
              ),
            ),
          ),
        ),
        Center(child: child),
      ]),
    );
    if (onTap == null) return plate;
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: plate);
  }
}

/// زر كبير بلوح 3D + عنوان (الإجراءات السريعة في الرئيسية)
class PlateAction extends StatelessWidget {
  final String icon;
  final String label;
  final PlateColor color;
  final VoidCallback onTap;
  final String? hint;
  const PlateAction({super.key, required this.icon, required this.label, required this.onTap, this.color = PlateColor.gold, this.hint});
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(gradient: C.cardGradient, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.line2)),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Plate.icon(icon, color: color, size: 54),
              const SizedBox(height: 10),
              Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: C.text), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
              if (hint != null) ...[const SizedBox(height: 2), Text(hint!, style: TextStyle(fontSize: 10.5, color: C.text3), textAlign: TextAlign.center)],
            ]),
          ),
        ),
      );
}

/// صورة رمزية للعميل: الحرف الأول على لوح ذهبي (row__ic في التصميم الأصلي)
class Avatar extends StatelessWidget {
  final String name;
  final double size;
  const Avatar(this.name, {super.key, this.size = 44});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [C.surface3, C.surface2], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(size * 0.3),
          border: Border.all(color: C.line),
        ),
        child: Text(name.trim().isEmpty ? '؟' : name.trim()[0], style: TextStyle(color: C.goldInk, fontWeight: FontWeight.w900, fontSize: size * 0.42)),
      );
}

/// شارة ذهبية صغيرة (رأس الصفحة)
class GoldBadge extends StatelessWidget {
  final Widget child;
  final double size;
  const GoldBadge({super.key, required this.child, this.size = 40});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [C.gold2, C.goldDeep], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(size * 0.3),
          boxShadow: [BoxShadow(color: C.gold.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 4))],
        ),
        child: Center(child: child),
      );
}

class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? action;
  const SectionTitle(this.title, {super.key, this.action});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
        child: Row(children: [
          Container(width: 4, height: 18, decoration: BoxDecoration(color: C.gold, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const Spacer(),
          if (action != null) action!,
        ]),
      );
}

class GoldCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  const GoldCard({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.onTap, this.color});
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Ink(
            padding: padding,
            decoration: BoxDecoration(
              color: color,
              gradient: color == null ? C.cardGradient : null,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: C.line2),
              boxShadow: C.isDark ? null : [BoxShadow(color: const Color(0xFF1E2A4A).withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: child,
          ),
        ),
      );
}

class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const StatusChip(this.label, this.color, {super.key});

  factory StatusChip.invoice(InvoiceStatus s) => StatusChip(
        statusLabel[s]!,
        switch (s) {
          InvoiceStatus.paid => C.green,
          InvoiceStatus.partial => C.amber,
          InvoiceStatus.issued => C.red,
          InvoiceStatus.draft => C.muted,
          InvoiceStatus.cancelled => C.muted,
        },
      );

  factory StatusChip.quote(QuoteStatus s) => StatusChip(
        quoteStatusLabel[s]!,
        switch (s) {
          QuoteStatus.accepted => C.green,
          QuoteStatus.converted => C.blue,
          QuoteStatus.sent => C.amber,
          QuoteStatus.rejected => C.red,
          QuoteStatus.draft => C.muted,
        },
      );

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.5))),
        child: Text(label, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w800)),
      );
}

class Money extends StatelessWidget {
  final int halalas;
  final double size;
  final Color color;
  final bool smart;
  Money(this.halalas, {super.key, this.size = 15, Color? color, this.smart = true}) : color = color ?? C.text;
  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(children: [
          TextSpan(text: fmt(halalas, trimZeros: smart), style: moneyStyle(size, color: color)),
          TextSpan(text: ' ر.س', style: TextStyle(fontSize: size * 0.62, color: color.withValues(alpha: 0.75), fontWeight: FontWeight.w700)),
        ]),
        textDirection: TextDirection.rtl,
      );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? hint;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, this.hint, this.action});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(shape: BoxShape.circle, color: C.gold.withValues(alpha: 0.1), border: Border.all(color: C.gold.withValues(alpha: 0.4))),
              child: Icon(icon, size: 40, color: C.gold),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            if (hint != null) ...[SizedBox(height: 6), Text(hint!, textAlign: TextAlign.center, style: TextStyle(color: C.muted))],
            if (action != null) ...[const SizedBox(height: 18), action!],
          ]),
        ),
      );
}

/// حقل إدخال موحّد
class Field extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final String? hint;
  final TextInputType? type;
  final int maxLines;
  final IconData? icon;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final Widget? suffix;
  final bool readOnly;
  final VoidCallback? onTap;
  final TextDirection? direction;
  const Field(this.label,
      {super.key,
      this.controller,
      this.hint,
      this.type,
      this.maxLines = 1,
      this.icon,
      this.validator,
      this.onChanged,
      this.suffix,
      this.readOnly = false,
      this.onTap,
      this.direction});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: controller,
          keyboardType: type,
          maxLines: maxLines,
          validator: validator,
          onChanged: onChanged,
          readOnly: readOnly,
          onTap: onTap,
          textDirection: direction,
          style: const TextStyle(fontWeight: FontWeight.w600),
          decoration: InputDecoration(labelText: label, hintText: hint, prefixIcon: icon != null ? Icon(icon, color: C.muted, size: 20) : null, suffixIcon: suffix),
        ),
      );
}

/// اختيار تاريخ
Future<String?> pickDate(BuildContext context, String current) async {
  DateTime init = DateTime.now();
  try {
    if (current.isNotEmpty) init = DateTime.parse(current);
  } catch (_) {}
  final d = await showDatePicker(
    context: context,
    initialDate: init,
    firstDate: DateTime(2020),
    lastDate: DateTime(2035),
    locale: const Locale('ar'),
    builder: (ctx, child) => Theme(
      data: Theme.of(ctx).copyWith(colorScheme: ColorScheme.dark(primary: C.gold, onPrimary: C.bg, surface: C.bg2, onSurface: C.text)),
      child: child!,
    ),
  );
  if (d == null) return null;
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

void toast(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline : Icons.check_circle_outline, color: error ? C.red : C.green, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(msg)),
      ]),
    ));
}

/// تنفيذ عملية طويلة (إنشاء PDF / مشاركة) مع مؤشر انتظار ورسالة خطأ واضحة
Future<bool> runBusy(BuildContext context, String label, Future<void> Function() task) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 22),
          decoration: BoxDecoration(color: C.bg2, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.line)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 14),
            Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: C.text, decoration: TextDecoration.none, fontSize: 14)),
          ]),
        ),
      ),
    ),
  );
  var ok = true;
  Object? err;
  try {
    await task();
  } catch (e) {
    ok = false;
    err = e;
  }
  if (context.mounted) {
    Navigator.of(context, rootNavigator: true).pop();
    if (!ok) toast(context, 'تعذّر تنفيذ العملية: $err', error: true);
  }
  return ok;
}

Future<bool> confirm(BuildContext context, String title, String body, {String ok = 'حذف', bool danger = true}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body, style: TextStyle(color: C.muted)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: C.red, foregroundColor: Colors.white) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// زر إجراء سريع (شبكة الرئيسية)
class QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const QuickAction({super.key, required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GoldCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Plate.material(icon, size: 48),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
        ]),
      );
}

class KpiTile extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  KpiTile(this.label, this.value, {super.key, Color? color}) : color = color ?? C.text;
  @override
  Widget build(BuildContext context) => Expanded(
        child: GoldCard(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: C.muted, fontSize: 11.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Money(value, size: 16, color: color)),
          ]),
        ),
      );
}

/// قسم قابل للطي — يُخفي التعقيد حتى يحتاجه المستخدم
class Expander extends StatelessWidget {
  final String title, hint;
  final IconData icon;
  final bool open;
  final VoidCallback onToggle;
  final Widget child;
  const Expander({super.key, required this.title, required this.hint, required this.icon, required this.open, required this.onToggle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
        child: Column(children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(children: [
                Icon(icon, color: C.gold, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: C.text)),
                    Text(hint, style: TextStyle(color: C.text3, fontSize: 11.5)),
                  ]),
                ),
                AnimatedRotation(turns: open ? 0.5 : 0, duration: const Duration(milliseconds: 200), child: Icon(Icons.expand_more_rounded, color: C.text2)),
              ]),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: open
                ? Padding(padding: const EdgeInsets.fromLTRB(14, 4, 14, 2), child: child)
                : const SizedBox(width: double.infinity),
          ),
        ]),
      ),
    );
  }
}
