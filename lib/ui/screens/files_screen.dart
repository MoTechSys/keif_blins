/// files_screen.dart — الملفات المحفوظة على الهاتف (مجلدات حسب النوع) | كيف الضيافة
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/file_service.dart';
import '../../core/models.dart';
import '../../core/store.dart';
import '../theme.dart';
import '../widgets.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});
  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> with SingleTickerProviderStateMixin {
  static const _kinds = [FileKind.invoice, FileKind.quote, FileKind.statement, FileKind.receipt, FileKind.backup];
  late final TabController _tabs = TabController(length: _kinds.length, vsync: this);
  final Map<FileKind, List<SavedFile>?> _cache = {};
  String? _base;

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) _load(_kinds[_tabs.index]);
    });
    FileService.base().then((d) {
      if (mounted) setState(() => _base = d?.path);
    });
    _load(_kinds.first);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load(FileKind k, {bool force = false}) async {
    if (!force && _cache[k] != null) return;
    final l = await FileService.list(k);
    if (mounted) setState(() => _cache[k] = l);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الملفات المحفوظة'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _load(_kinds[_tabs.index], force: true),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [for (final k in _kinds) Tab(text: k.folder)],
        ),
      ),
      body: Column(children: [
        if (_base != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: C.bg2,
            child: Row(children: [
              const Icon(Icons.folder_open_rounded, color: C.gold, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _display(_base!),
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: C.muted, fontSize: 11.5),
                  maxLines: 2,
                ),
              ),
            ]),
          ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [for (final k in _kinds) _list(k)],
          ),
        ),
      ]),
    );
  }

  /// يعرض المسار بشكل مفهوم للمستخدم
  static String _display(String p) {
    var s = p;
    if (s.startsWith('/storage/emulated/0/')) s = 'الذاكرة الداخلية/${s.substring('/storage/emulated/0/'.length)}';
    return s;
  }

  Widget _list(FileKind k) {
    final files = _cache[k];
    if (files == null) return const Center(child: CircularProgressIndicator());
    if (files.isEmpty) {
      return EmptyState(
        icon: k == FileKind.backup ? Icons.backup_outlined : Icons.folder_off_outlined,
        title: 'لا توجد ملفات في "${k.folder}"',
        hint: k == FileKind.backup
            ? 'تُحفظ نسخة تلقائيًا عند أي تعديل، ويمكنك الحفظ يدويًا من الإعدادات.'
            : 'عند معاينة أو مشاركة أي مستند يُحفظ هنا تلقائيًا (مرتّبًا بالسنة).',
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(k, force: true),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 30),
        itemCount: files.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _FileTile(
          f: files[i],
          onChanged: () => _load(k, force: true),
        ),
      ),
    );
  }
}

class _FileTile extends StatelessWidget {
  final SavedFile f;
  final VoidCallback onChanged;
  const _FileTile({required this.f, required this.onChanged});

  bool get isBackup => f.kind == FileKind.backup;

  @override
  Widget build(BuildContext context) {
    final d = f.modified;
    final when = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    // مجلد السنة (إن وُجد) من المسار
    final segs = f.path.split('/');
    final year = segs.length >= 2 && RegExp(r'^\d{4}$').hasMatch(segs[segs.length - 2]) ? segs[segs.length - 2] : null;
    return GoldCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      onTap: () => isBackup ? _restore(context) : _open(context),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: C.bg2, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.line)),
          child: Icon(isBackup ? Icons.settings_backup_restore_rounded : Icons.picture_as_pdf_rounded, color: C.gold),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(f.name, style: const TextStyle(fontWeight: FontWeight.w800), textDirection: TextDirection.ltr, textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text('$when • ${f.sizeLabel}${year != null ? ' • مجلد $year' : ''}', style: const TextStyle(color: C.muted, fontSize: 11.5)),
          ]),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: C.muted),
          onSelected: (v) => switch (v) {
            'open' => _open(context),
            'share' => _share(context),
            'restore' => _restore(context),
            'delete' => _delete(context),
            _ => null,
          },
          itemBuilder: (_) => [
            if (!isBackup) const PopupMenuItem(value: 'open', child: ListTile(leading: Icon(Icons.open_in_new_rounded), title: Text('فتح'))),
            const PopupMenuItem(value: 'share', child: ListTile(leading: Icon(Icons.share_rounded), title: Text('مشاركة الملف'))),
            if (isBackup) const PopupMenuItem(value: 'restore', child: ListTile(leading: Icon(Icons.restore_rounded), title: Text('استرجاع هذه النسخة'))),
            const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline, color: C.red), title: Text('حذف', style: TextStyle(color: C.red)))),
          ],
        ),
      ]),
    );
  }

  Future<void> _open(BuildContext context) async {
    final err = await FileService.open(f.path);
    if (err != null && context.mounted) toast(context, err, error: true);
  }

  Future<void> _share(BuildContext context) async {
    try {
      await FileService.share(f.path, subject: f.name);
    } catch (e) {
      if (context.mounted) toast(context, 'تعذّرت المشاركة: $e', error: true);
    }
  }

  Future<void> _delete(BuildContext context) async {
    if (!await confirm(context, 'حذف الملف', 'سيتم حذف "${f.name}" من مجلد الهاتف.')) return;
    try {
      await FileService.delete(f.path);
      onChanged();
      if (context.mounted) toast(context, 'تم حذف الملف');
    } catch (e) {
      if (context.mounted) toast(context, 'تعذّر الحذف: $e', error: true);
    }
  }

  Future<void> _restore(BuildContext context) async {
    final store = context.read<Store>();
    String text;
    try {
      text = await FileService.readText(f.path);
    } catch (e) {
      if (context.mounted) toast(context, 'تعذّر قراءة الملف: $e', error: true);
      return;
    }
    if (!context.mounted) return;
    final go = await confirm(
      context,
      'استرجاع النسخة الاحتياطية',
      'الملف: ${f.name}\n\nسيتم إضافة بيانات النسخة إلى بياناتك الحالية (وتحديث السجلات المتطابقة) دون حذف أي شيء.',
      ok: 'استرجاع',
      danger: false,
    );
    if (!go || !context.mounted) return;
    try {
      final n = await store.importJson(text);
      if (context.mounted) toast(context, 'تم استرجاع $n سجلًا بنجاح');
    } catch (e) {
      if (context.mounted) toast(context, 'تعذّر الاسترجاع: $e', error: true);
    }
  }
}

/// كرت مختصر للإعدادات يفتح شاشة الملفات
class FilesEntryTile extends StatelessWidget {
  const FilesEntryTile({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final last = store.lastAutoBackupAt;
    return ListTile(
      leading: const Icon(Icons.folder_rounded),
      title: const Text('الملفات المحفوظة على الهاتف', style: TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        'Documents/${FileService.appFolder}/ — الفواتير، عروض الأسعار، كشوف الحساب، سندات القبض، النسخ الاحتياطية'
        '${last != null ? '\nآخر نسخة تلقائية: ${fmtDate(last.toIso8601String())}' : ''}',
        style: const TextStyle(color: C.muted, fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_left, color: C.muted),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FilesScreen())),
    );
  }
}
