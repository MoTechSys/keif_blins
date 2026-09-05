/// lock_screen.dart — شاشة القفل ولوحة إدخال الرمز | كيف الضيافة
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/lock_service.dart';
import '../theme.dart';

/// شاشة القفل الكاملة (تُعرض فوق التطبيق عند التشغيل/الرجوع)
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _pin = '';
  bool _shake = false;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // لتحديث عدّاد الانتظار كل ثانية
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && context.read<LockService>().cooldownSeconds > 0) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _submit() async {
    final lock = context.read<LockService>();
    final ok = await lock.unlock(_pin);
    if (!mounted) return;
    if (!ok) {
      HapticFeedback.heavyImpact();
      setState(() {
        _shake = true;
        _pin = '';
      });
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _shake = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lock = context.watch<LockService>();
    final cd = lock.cooldownSeconds;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: C.bg,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(width: 110, height: 110, child: Image(image: AssetImage('assets/img/logo.png'), fit: BoxFit.contain)),
                const SizedBox(height: 18),
                const Text('التطبيق مقفل', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(
                  cd > 0 ? 'محاولات كثيرة خاطئة — انتظر $cd ثانية' : 'أدخل رمز القفل للمتابعة',
                  style: TextStyle(color: cd > 0 ? C.red : C.muted, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 26),
                PinDots(length: _pin.length, error: _shake),
                const SizedBox(height: 26),
                PinPad(
                  enabled: cd == 0,
                  onDigit: (d) {
                    if (_pin.length >= 6) return;
                    setState(() => _pin += d);
                    if (_pin.length >= 4 && lock.verify(_pin)) _submit();
                  },
                  onDelete: () => setState(() => _pin = _pin.isEmpty ? '' : _pin.substring(0, _pin.length - 1)),
                  onSubmit: _pin.length >= 4 ? _submit : null,
                ),
                if (lock.failedAttempts > 0 && cd == 0) ...[
                  const SizedBox(height: 14),
                  Text('محاولات خاطئة: ${lock.failedAttempts}', style: TextStyle(color: C.red, fontSize: 12.5)),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/* ============================================================
   نقاط الرمز
   ============================================================ */
class PinDots extends StatelessWidget {
  final int length;
  final bool error;
  const PinDots({super.key, required this.length, this.error = false});
  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(6, (i) {
          final on = i < length;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 7),
            width: on ? 16 : 14,
            height: on ? 16 : 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: error ? C.red : (on ? C.gold : Colors.transparent),
              border: Border.all(color: error ? C.red : C.gold, width: 1.5),
            ),
          );
        }),
      );
}

/* ============================================================
   لوحة الأرقام
   ============================================================ */
class PinPad extends StatelessWidget {
  final void Function(String) onDigit;
  final VoidCallback onDelete;
  final VoidCallback? onSubmit;
  final bool enabled;
  const PinPad({super.key, required this.onDigit, required this.onDelete, this.onSubmit, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    Widget key(String label, {VoidCallback? onTap, IconData? icon, Color? color}) => Padding(
          padding: const EdgeInsets.all(6),
          child: Material(
            color: onTap == null ? Colors.transparent : C.card,
            shape: CircleBorder(side: BorderSide(color: C.line)),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: enabled ? onTap : null,
              child: SizedBox(
                width: 72,
                height: 72,
                child: Center(
                  child: icon != null
                      ? Icon(icon, color: color ?? C.gold)
                      : Text(label, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: enabled ? C.text : C.muted)),
                ),
              ),
            ),
          ),
        );
    Widget row(List<Widget> ch) => Row(mainAxisAlignment: MainAxisAlignment.center, children: ch);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(children: [
        row([for (final d in ['1', '2', '3']) key(d, onTap: () => onDigit(d))]),
        row([for (final d in ['4', '5', '6']) key(d, onTap: () => onDigit(d))]),
        row([for (final d in ['7', '8', '9']) key(d, onTap: () => onDigit(d))]),
        row([
          key('', icon: Icons.backspace_outlined, color: C.muted, onTap: onDelete),
          key('0', onTap: () => onDigit('0')),
          key('', icon: Icons.check_rounded, color: onSubmit == null ? C.muted : C.green, onTap: onSubmit),
        ]),
      ]),
    );
  }
}

/// حوار إدخال رمز (لتعيين/تغيير/تعطيل) — يعيد الرمز أو null
Future<String?> askPin(BuildContext context, String title, {String? hint}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _PinDialog(title: title, hint: hint),
  );
}

class _PinDialog extends StatefulWidget {
  final String title;
  final String? hint;
  const _PinDialog({required this.title, this.hint});
  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  String _pin = '';
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          if (widget.hint != null) ...[
            Text(widget.hint!, style: TextStyle(color: C.muted, fontSize: 12.5), textAlign: TextAlign.center),
            const SizedBox(height: 14),
          ],
          PinDots(length: _pin.length),
          const SizedBox(height: 16),
          PinPad(
            onDigit: (d) => setState(() => _pin.length < 6 ? _pin += d : null),
            onDelete: () => setState(() => _pin = _pin.isEmpty ? '' : _pin.substring(0, _pin.length - 1)),
            onSubmit: _pin.length >= 4 ? () => Navigator.pop(context, _pin) : null,
          ),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء'))],
      );
}
