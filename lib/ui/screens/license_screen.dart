/// license_screen.dart — شاشة الإيقاف/التفعيل (القفل عن بُعد)
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/brand.dart';
import '../../core/license_service.dart';
import '../theme.dart';

class LicenseScreen extends StatefulWidget {
  const LicenseScreen({super.key});
  @override
  State<LicenseScreen> createState() => _LicenseScreenState();
}

class _LicenseScreenState extends State<LicenseScreen> {
  final _ctl = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _rechecking = false;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    if (_ctl.text.trim().isEmpty) {
      setState(() => _error = 'أدخل كود التفعيل');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await context.read<LicenseService>().unlock(_ctl.text);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _busy = false;
        _error = 'الكود غير صحيح أو غير مسموح حاليًا';
      });
    }
  }

  Future<void> _recheck() async {
    setState(() => _rechecking = true);
    final st = await context.read<LicenseService>().refresh();
    if (!mounted) return;
    setState(() => _rechecking = false);
    if (!st.allowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            st.offline
                ? 'لا يوجد اتصال بالإنترنت للتحقق'
                : 'النسخة ما زالت موقوفة',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<LicenseService>().state;
    final deleted = !(st?.codeAccepted ?? true);
    final msg = (st?.message ?? '').trim();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image(image: AssetImage(Brand.current.logo), width: 96),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: C.gold.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.lock_outline, size: 46, color: C.gold),
                ),
                const SizedBox(height: 18),
                Text(
                  deleted ? 'انتهى ترخيص النسخة' : 'النسخة موقوفة مؤقتًا',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: C.text,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  msg.isNotEmpty
                      ? msg
                      : 'يرجى التواصل مع المطوّر للحصول على كود التفعيل.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: C.muted, height: 1.6),
                ),
                const SizedBox(height: 8),
                Text(
                  'بياناتك محفوظة كما هي ولن تُحذف.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: C.text3, fontSize: 12),
                ),
                const SizedBox(height: 26),
                if (!deleted) ...[
                  TextField(
                    controller: _ctl,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.ltr,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(letterSpacing: 2, fontSize: 16),
                    onSubmitted: (_) => _activate(),
                    decoration: InputDecoration(
                      labelText: 'كود التفعيل',
                      errorText: _error,
                      prefixIcon: const Icon(Icons.vpn_key_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _activate,
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_rounded),
                      label: const Text('تفعيل'),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                TextButton.icon(
                  onPressed: _rechecking ? null : _recheck,
                  icon: _rechecking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: const Text('إعادة التحقق'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
