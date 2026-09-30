/// storage_guard.dart — حارس صلاحية التخزين قبل أي عملية ملفات | نظام الفواتير
///
/// الهدف (ADR-0002): مجلد التطبيق في جذر الذاكرة `/storage/emulated/0/<اسم التطبيق>`
/// يحتاج على أندرويد 11+ صلاحية «الوصول إلى كل الملفات» (MANAGE_EXTERNAL_STORAGE).
/// بدونها يعمل التطبيق في **وضع محدود** (Documents/<التطبيق>) — وهذا يجب أن يكون
/// ظاهرًا للمستخدم لا صامتًا. لذلك قبل كل عملية ملفات مهمة (نسخة احتياطية، استعادة،
/// حفظ PDF من زر صريح) نمرّ من [StorageGuard.ensure]:
///   1. الصلاحية موجودة ⇐ نُكمل فورًا.
///   2. غير موجودة ⇐ حوار يشرح لماذا + زر «فتح الإعدادات» ينقل مباشرة إلى صفحة
///      الصلاحية في النظام. عند الرجوع للتطبيق نعيد الفحص تلقائيًا ونُكمل.
///   3. المستخدم اختار «متابعة بدون» ⇐ نُكمل في الوضع المحدود (لا نمنعه من عمله).
///
/// على الويب/غير أندرويد: يعيد true دائمًا.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/brand.dart';
import '../core/file_service.dart';
import 'theme.dart';

class StorageGuard {
  StorageGuard._();

  /// هل الملفات ستُكتب في جذر الذاكرة (الوضع الكامل)؟
  static Future<bool> get hasFullAccess => FileService.hasRootAccess();

  /// يضمن الصلاحية قبل [what] (وصف قصير للعملية يظهر في الحوار).
  /// يعيد true إذا يمكن المتابعة (بصلاحية كاملة أو بموافقة المستخدم على الوضع المحدود).
  static Future<bool> ensure(
    BuildContext context, {
    required String what,
    bool allowLimited = true,
  }) async {
    if (!FileService.supported) return true;
    if (await hasFullAccess) return true;
    if (!context.mounted) return false;
    final r = await showDialog<_Choice>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PermissionDialog(what: what, allowLimited: allowLimited),
    );
    switch (r) {
      case _Choice.granted:
        await FileService.refresh();
        return true;
      case _Choice.limited:
        await FileService.base();
        return allowLimited;
      case _Choice.cancel:
      case null:
        return false;
    }
  }

  /// يفتح صفحة الصلاحية في النظام (أندرويد 11+: «الوصول إلى كل الملفات»؛ أقدم: حوار عادي)
  static Future<bool> requestOrOpenSettings() async {
    final ok = await FileService.requestRootAccess();
    if (ok) return true;
    // رفض دائم أو لم تُفتح الشاشة: نفتح إعدادات التطبيق مباشرة
    final sdk = await FileService.sdkInt();
    if (sdk >= 30) {
      // على 11+ request() يفتح شاشة النظام نفسها؛ إن لم تُمنح بعد الرجوع نفتح الإعدادات
      final st = await Permission.manageExternalStorage.status;
      if (st.isGranted) return true;
    }
    await openAppSettings();
    return false;
  }
}

enum _Choice { granted, limited, cancel }

class _PermissionDialog extends StatefulWidget {
  final String what;
  final bool allowLimited;
  const _PermissionDialog({required this.what, required this.allowLimited});
  @override
  State<_PermissionDialog> createState() => _PermissionDialogState();
}

class _PermissionDialogState extends State<_PermissionDialog>
    with WidgetsBindingObserver {
  bool _busy = false;
  bool _waitingSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// بعد الرجوع من شاشة إعدادات النظام: نفحص تلقائيًا ونغلق الحوار إن مُنحت
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed && _waitingSettings) {
      _waitingSettings = false;
      unawaited(_recheck());
    }
  }

  Future<void> _recheck() async {
    final ok = await StorageGuard.hasFullAccess;
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, _Choice.granted);
    } else {
      setState(() => _busy = false);
    }
  }

  Future<void> _open() async {
    setState(() {
      _busy = true;
      _waitingSettings = true;
    });
    final ok = await StorageGuard.requestOrOpenSettings();
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, _Choice.granted);
    }
    // وإلا ننتظر resumed ثم _recheck
  }

  @override
  Widget build(BuildContext context) {
    final b = Brand.current;
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.folder_off_rounded, color: C.gold),
          const SizedBox(width: 8),
          const Expanded(child: Text('صلاحية التخزين مطلوبة')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'لـ${widget.what} يحتاج التطبيق صلاحية «الوصول إلى كل الملفات» كي يُنشئ مجلده في الذاكرة الداخلية:',
            style: TextStyle(color: C.text, height: 1.6),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: C.bg2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: C.line),
            ),
            child: Text(
              'الذاكرة الداخلية / ${b.folderName}',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color: C.goldInk,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'الخطوات: اضغط «فتح الإعدادات» ← فعّل «السماح بالوصول لإدارة كل الملفات» ← ارجع للتطبيق (يُكمل تلقائيًا).\n\nالتطبيق يكتب فقط داخل مجلده ولا يقرأ ملفاتك الأخرى.',
            style: TextStyle(color: C.text3, fontSize: 12, height: 1.6),
          ),
          if (widget.allowLimited) ...[
            const SizedBox(height: 8),
            Text(
              'بدون الصلاحية: تُحفظ الملفات في «Documents / ${b.folderName}» (وضع محدود).',
              style: TextStyle(color: C.text3, fontSize: 11.5, height: 1.5),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy
              ? null
              : () => Navigator.pop(context, _Choice.cancel),
          child: const Text('إلغاء'),
        ),
        if (widget.allowLimited)
          TextButton(
            onPressed: _busy
                ? null
                : () => Navigator.pop(context, _Choice.limited),
            child: Text('متابعة بدون', style: TextStyle(color: C.text3)),
          ),
        FilledButton.icon(
          onPressed: _busy ? null : _open,
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.settings_rounded, size: 18),
          label: const Text('فتح الإعدادات'),
        ),
      ],
    );
  }
}

/// شريط تحذير صغير يظهر في شاشات الملفات/النسخ عندما يكون التطبيق في الوضع المحدود
class LimitedStorageBanner extends StatefulWidget {
  const LimitedStorageBanner({super.key});
  @override
  State<LimitedStorageBanner> createState() => _LimitedStorageBannerState();
}

class _LimitedStorageBannerState extends State<LimitedStorageBanner> {
  bool? _full;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!FileService.supported) return;
    final f = await StorageGuard.hasFullAccess;
    if (mounted) setState(() => _full = f);
  }

  @override
  Widget build(BuildContext context) {
    if (!FileService.supported || _full != false) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: C.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final ok = await StorageGuard.ensure(
              context,
              what: 'إنشاء مجلد التطبيق في الذاكرة الداخلية',
              allowLimited: false,
            );
            if (ok) _load();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: C.goldInk, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'وضع محدود: الملفات تُحفظ في Documents. اضغط لمنح الصلاحية وإنشاء المجلد في الذاكرة الداخلية.',
                    style: TextStyle(
                      color: C.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ),
                Icon(Icons.chevron_left_rounded, color: C.text3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
