/// widgets.dart — عناصر واجهة مشتركة | كيف الضيافة
library;

import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/money.dart';
import 'theme.dart';

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
        color: color ?? C.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: padding,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
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
  const Money(this.halalas, {super.key, this.size = 15, this.color = C.text, this.smart = true});
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
            if (hint != null) ...[const SizedBox(height: 6), Text(hint!, textAlign: TextAlign.center, style: const TextStyle(color: C.muted))],
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
      data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.dark(primary: C.gold, onPrimary: C.bg, surface: C.bg2, onSurface: C.text)),
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
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: C.text, decoration: TextDecoration.none, fontSize: 14)),
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
      content: Text(body, style: const TextStyle(color: C.muted)),
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
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [C.goldDark, C.gold, C.goldLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: C.bg, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
        ]),
      );
}

class KpiTile extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const KpiTile(this.label, this.value, {super.key, this.color = C.text});
  @override
  Widget build(BuildContext context) => Expanded(
        child: GoldCard(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: C.muted, fontSize: 11.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Money(value, size: 16, color: color)),
          ]),
        ),
      );
}
