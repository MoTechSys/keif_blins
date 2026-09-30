/// update_screen.dart — شاشة «تحديث التطبيق» + حوار التحديث المتاح | نظام الفواتير
///
/// المسار: الإعدادات → تحديث التطبيق. الزر يفحص update.json في diafa-apps، وإن وُجد إصدار
/// أحدث لمعمارية هذا التطبيق يعرض «ما الجديد» وزر «تنزيل وتثبيت»:
///   تنزيل مع شريط تقدّم → تحقق SHA-256 → (أندرويد 8+) إن لم يُسمح بالتثبيت من هذا التطبيق
///   نفتح شاشة النظام المناسبة ونعيد المحاولة عند الرجوع → مثبّت النظام.
/// الفحص التلقائي (مرة كل 24 ساعة عند التشغيل) يعرض حوارًا مختصرًا بزرَي «تحديث الآن» و«لاحقًا».
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/store.dart';
import '../../core/update_service.dart';
import '../theme.dart';
import '../widgets.dart';

class UpdateScreen extends StatefulWidget {
  const UpdateScreen({super.key});
  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  InstalledInfo? _inst;

  @override
  void initState() {
    super.initState();
    UpdateService.installed().then((i) {
      if (mounted) setState(() => _inst = i);
    });
    final u = context.read<UpdateService>();
    if (u.last == null) u.check();
  }

  @override
  Widget build(BuildContext context) {
    final u = context.watch<UpdateService>();
    final r = u.last;
    return Scaffold(
      appBar: AppBar(title: const Text('تحديث التطبيق')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
        children: [
          GoldCard(
            child: Row(
              children: [
                Icon(
                  r?.available == true
                      ? Icons.system_update_rounded
                      : Icons.verified_rounded,
                  color: r?.available == true ? C.gold : C.green,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الإصدار المثبّت: ${_inst?.versionName ?? '…'}',
                        style: TextStyle(
                          color: C.text,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        _inst == null
                            ? ''
                            : 'رقم البناء ${_inst!.versionCode} • ${_abiLabel(_inst!.abi)}',
                        style: TextStyle(color: C.text3, fontSize: 11.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        u.checking
                            ? 'جارٍ الفحص…'
                            : (r?.message ?? 'لم يُفحص بعد'),
                        style: TextStyle(
                          color: r?.available == true ? C.goldInk : C.text2,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: u.checking
                ? null
                : () async {
                    final store = context.read<Store>();
                    await u.check();
                    await store.setKv(
                      'lastUpdateCheck',
                      DateTime.now().toIso8601String(),
                    );
                  },
            icon: u.checking
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            label: const Text('فحص التحديثات الآن'),
          ),
          if (r?.available == true && r!.info != null) ...[
            const SectionTitle('تحديث متاح'),
            GoldCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الإصدار ${r.info!.version}${r.info!.publishedAt.isNotEmpty ? ' • ${r.info!.publishedAt}' : ''}',
                    style: TextStyle(
                      color: C.text,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  if (r.apk != null && r.apk!.size > 0)
                    Text(
                      'الحجم ${(r.apk!.size / 1024 / 1024).toStringAsFixed(1)} MB • ${_abiLabel(r.installed!.abi)}',
                      style: TextStyle(color: C.text3, fontSize: 11.5),
                    ),
                  if (r.info!.notes.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      r.info!.notes,
                      style: TextStyle(color: C.text2, height: 1.6),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _InstallButton(check: r),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            'التحديث يُثبَّت فوق النسخة الحالية — بياناتك تبقى كما هي. يُتحقق من بصمة الملف (SHA-256) قبل التثبيت، وأندرويد يرفض أي ملف بمفتاح توقيع مختلف.',
            textAlign: TextAlign.center,
            style: TextStyle(color: C.text3, fontSize: 11.5, height: 1.6),
          ),
        ],
      ),
    );
  }

  static String _abiLabel(String abi) => switch (abi) {
    'arm64' => 'arm64 (أغلب الجوالات)',
    'armv7' => 'armv7 (الجوالات القديمة)',
    '' => 'معمارية غير معروفة',
    _ => abi,
  };
}

/// زر «تنزيل وتثبيت» مع شريط تقدّم ومعالجة صلاحية «تثبيت تطبيقات غير معروفة»
class _InstallButton extends StatefulWidget {
  final UpdateCheck check;
  const _InstallButton({required this.check});
  @override
  State<_InstallButton> createState() => _InstallButtonState();
}

class _InstallButtonState extends State<_InstallButton>
    with WidgetsBindingObserver {
  bool _busy = false;
  String? _path; // ملف منزَّل ومُتحقَّق منه
  bool _waitingPermission = false;

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

  /// بعد الرجوع من شاشة «تثبيت التطبيقات غير المعروفة»: نتابع التثبيت تلقائيًا
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed && _waitingPermission) {
      _waitingPermission = false;
      _installIfAllowed();
    }
  }

  Future<void> _installIfAllowed() async {
    final p = _path;
    if (p == null) return;
    if (!await UpdateService.canInstall()) {
      if (!mounted) return;
      final go = await confirm(
        context,
        'السماح بالتثبيت',
        'لتثبيت التحديث يطلب أندرويد السماح لهذا التطبيق بـ«تثبيت تطبيقات غير معروفة» (مرة واحدة).\n\nاضغط «فتح الإعدادات»، فعّل الخيار، ثم ارجع — سيتابع التثبيت تلقائيًا.',
        ok: 'فتح الإعدادات',
        danger: false,
      );
      if (!go) return;
      _waitingPermission = true;
      await UpdateService.openInstallSettings();
      return;
    }
    try {
      await UpdateService.install(p);
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    }
  }

  Future<void> _run() async {
    final apk = widget.check.apk;
    if (apk == null) return;
    setState(() => _busy = true);
    try {
      final u = context.read<UpdateService>();
      _path = await u.download(apk);
      await _installIfAllowed();
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = context.read<UpdateService>();
    return ValueListenableBuilder<double?>(
      valueListenable: u.progress,
      builder: (_, p, __) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (p != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: p, minHeight: 8),
            ),
            const SizedBox(height: 6),
            Text(
              'جارٍ التنزيل ${(p * 100).toStringAsFixed(0)}%',
              textAlign: TextAlign.center,
              style: TextStyle(color: C.text3, fontSize: 12),
            ),
            const SizedBox(height: 8),
          ],
          FilledButton.icon(
            onPressed: _busy ? null : _run,
            icon: Icon(
              _path == null ? Icons.download_rounded : Icons.install_mobile,
            ),
            label: Text(_path == null ? 'تنزيل وتثبيت' : 'تثبيت الآن'),
          ),
        ],
      ),
    );
  }
}

/// حوار مختصر يظهر عند الفحص التلقائي إن وُجد تحديث. يعيد true إذا اختار «تحديث الآن»
Future<void> showUpdateAvailableDialog(
  BuildContext context,
  UpdateCheck r,
) async {
  final info = r.info!;
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.system_update_rounded, color: C.gold),
          const SizedBox(width: 8),
          Expanded(child: Text('تحديث جديد ${info.version}')),
        ],
      ),
      content: Text(
        info.notes.trim().isEmpty
            ? 'يتوفر إصدار أحدث من التطبيق. التثبيت فوق النسخة الحالية ولا يؤثر على بياناتك.'
            : info.notes,
        style: TextStyle(color: C.text2, height: 1.6),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('لاحقًا', style: TextStyle(color: C.text3)),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(ctx, true),
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text('تحديث الآن'),
        ),
      ],
    ),
  );
  if (!context.mounted) return;
  final store = context.read<Store>();
  if (go == true) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UpdateScreen()),
    );
  } else {
    // «لاحقًا» = لا نزعجه بهذا الإصدار تلقائيًا مرة أخرى (الزر اليدوي يبقى)
    await store.setKv(
      'updateSkippedCode',
      info.versionCodes[r.installed?.abi ?? ''] ?? info.build,
    );
  }
}

/// الفحص التلقائي عند التشغيل (يُستدعى من Shell بعد أول إطار)
Future<void> autoCheckForUpdate(BuildContext context) async {
  if (!UpdateService.supported) return;
  final store = context.read<Store>();
  if (!UpdateService.isCheckDue(store.kv('lastUpdateCheck'))) return;
  final u = context.read<UpdateService>();
  final r = await u.check();
  if (!context.mounted) return;
  await store.setKv('lastUpdateCheck', DateTime.now().toIso8601String());
  if (!r.available) return;
  final skipped = (store.kv('updateSkippedCode') as num?)?.toInt() ?? 0;
  final target = r.info!.versionCodes[r.installed?.abi ?? ''] ?? 0;
  if (target <= skipped) return;
  if (!context.mounted) return;
  await showUpdateAvailableDialog(context, r);
}
