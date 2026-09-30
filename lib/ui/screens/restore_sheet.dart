/// restore_sheet.dart — ورقة الاستعادة: قائمة النسخ الاحتياطية فورًا | نظام الفواتير
///
/// (قرار المالك 2.6.0) عند فتح «استعادة» تظهر قائمة النسخ الموجودة على الجهاز مباشرة
/// (الأحدث أولًا، مع حالة التحقق وعدد السجلات) + خيار اختيار ملف من مكان آخر.
///
/// تُستخدم من:
///  • شاشة النسخة الاحتياطية (زر «استعادة»)
///  • العرض التلقائي بعد إعادة التثبيت (Shell): قاعدة فارغة + نسخ موجودة في المجلد
///    ⇐ تُعرض مرة واحدة (kv restoreOffered) حتى لا يفقد المستخدم بياناته دون أن يعلم.
library;

import 'package:flutter/material.dart';

import '../../core/backup_service.dart';
import '../../core/file_service.dart';
import '../../core/store.dart';
import '../storage_guard.dart';
import '../theme.dart';
import '../widgets.dart';
import 'settings_screen.dart' show applyBackupImport, importBackupFromFile;

class BackupEntry {
  final SavedFile file;
  final BackupCheck? check;
  const BackupEntry(this.file, this.check);
}

/// يقرأ كل النسخ في مجلد التطبيق ويتحقق منها (الأحدث أولًا)
Future<List<BackupEntry>> loadBackupEntries() async {
  if (!FileService.supported) return const [];
  final files = await FileService.list(FileKind.backup);
  final out = <BackupEntry>[];
  for (final f in files) {
    BackupCheck? chk;
    try {
      chk = BackupService.verify(await FileService.readText(f.path));
    } catch (_) {}
    out.add(BackupEntry(f, chk));
  }
  return out;
}

/// هل يجب عرض الاستعادة تلقائيًا؟ قاعدة فارغة (تثبيت جديد/إعادة تثبيت) + نسخ سليمة موجودة
Future<bool> shouldOfferRestore(Store s) async {
  if (!FileService.supported || !s.isEmpty) return false;
  if (s.kv('restoreOffered') == true) return false;
  final list = await loadBackupEntries();
  return list.any((e) => e.check?.ok == true);
}

/// يعرض الورقة. [auto] = عرض تلقائي بعد إعادة التثبيت (نص مختلف + زر «تخطي»)
Future<void> showRestoreSheet(
  BuildContext context,
  Store store, {
  bool auto = false,
}) async {
  if (!auto) {
    final ok = await StorageGuard.ensure(
      context,
      what: 'قراءة النسخ الاحتياطية من مجلد التطبيق',
    );
    if (!ok || !context.mounted) return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _RestoreSheet(store: store, auto: auto),
  );
  if (auto) await store.setKv('restoreOffered', true);
}

class _RestoreSheet extends StatefulWidget {
  final Store store;
  final bool auto;
  const _RestoreSheet({required this.store, required this.auto});
  @override
  State<_RestoreSheet> createState() => _RestoreSheetState();
}

class _RestoreSheetState extends State<_RestoreSheet> {
  List<BackupEntry>? _list;

  @override
  void initState() {
    super.initState();
    loadBackupEntries().then((l) {
      if (mounted) setState(() => _list = l);
    });
  }

  Future<void> _restore(BackupEntry b) async {
    try {
      final text = await FileService.readText(b.file.path);
      if (!mounted) return;
      await applyBackupImport(
        context,
        widget.store,
        text,
        sourceName: '${whenLabel(b.file.modified)} (${b.file.name})',
      );
      if (mounted && !widget.store.isEmpty) Navigator.pop(context);
    } catch (e) {
      if (mounted) toast(context, 'تعذّر قراءة النسخة: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    final h = MediaQuery.sizeOf(context).height;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: h * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
              child: Row(
                children: [
                  Icon(Icons.restore_rounded, color: C.gold, size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.auto
                              ? 'وجدنا نسخًا احتياطية سابقة'
                              : 'استعادة نسخة احتياطية',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: C.text,
                          ),
                        ),
                        Text(
                          widget.auto
                              ? 'بياناتك الحالية فارغة. اختر نسخة لاسترجاعها، أو تخطَّ للبدء من جديد (يمكنك الاسترجاع لاحقًا من النسخة الاحتياطية).'
                              : 'اختر نسخة من القائمة (الأحدث أولًا). الاسترجاع يضيف إلى بياناتك ولا يحذف شيئًا.',
                          style: TextStyle(
                            color: C.text3,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: list == null
                  ? const Padding(
                      padding: EdgeInsets.all(30),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : list.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'لا نسخ في مجلد التطبيق. يمكنك اختيار ملف نسخة من مكان آخر.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: C.text3),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
                      itemCount: list.length,
                      itemBuilder: (_, i) => _row(list[i]),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final nav = Navigator.of(context);
                        await importBackupFromFile(context, widget.store);
                        if (mounted && !widget.store.isEmpty) nav.pop();
                      },
                      icon: const Icon(Icons.folder_open_rounded, size: 18),
                      label: const Text('ملف من مكان آخر'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        widget.auto ? 'تخطّي — البدء من جديد' : 'إغلاق',
                        style: TextStyle(color: C.text3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BackupEntry b) {
    final ok = b.check?.ok != false;
    final verified = b.check?.hasHash == true && ok;
    final c = b.check?.counts ?? const {};
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GoldCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        onTap: ok ? () => _restore(b) : null,
        child: Row(
          children: [
            Icon(
              !ok
                  ? Icons.gpp_bad_rounded
                  : (verified ? Icons.verified_rounded : Icons.save_rounded),
              color: !ok ? C.red : (verified ? C.green : C.gold),
              size: 24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    whenLabel(b.file.modified),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: C.text,
                    ),
                  ),
                  Text(
                    b.check == null
                        ? b.file.sizeLabel
                        : '${c['clients']} عميل • ${c['docs']} مستند • ${c['payments']} دفعة${FileService.isAutoBackup(b.file.name) ? ' • تلقائية' : ' • يدوية'}',
                    style: TextStyle(color: C.text3, fontSize: 11.5),
                  ),
                  Text(
                    b.check?.message ?? 'تعذّرت القراءة',
                    style: TextStyle(
                      color: !ok ? C.red : C.muted,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            if (ok) Icon(Icons.chevron_left_rounded, color: C.text3),
          ],
        ),
      ),
    );
  }
}

/// 2026-09-30  10:15
String whenLabel(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)}  ${two(t.hour)}:${two(t.minute)}';
}
