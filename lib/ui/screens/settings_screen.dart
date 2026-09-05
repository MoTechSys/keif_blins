/// settings_screen.dart — شاشات الإعدادات (تُفتح من القائمة الجانبية) | كيف الضيافة
library;

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/file_service.dart';
import '../../core/lock_service.dart';
import '../../core/models.dart';
import '../../core/store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'files_screen.dart';
import 'lock_screen.dart';

/* ============================================================
   إعدادات المستندات: الضريبة/الخصم/العربون (تشك بوكس) + الختم + الترقيم والشروط
   ============================================================ */
class DocSettingsScreen extends StatefulWidget {
  final int initialTab;
  const DocSettingsScreen({super.key, this.initialTab = 0});
  @override
  State<DocSettingsScreen> createState() => _DocSettingsScreenState();
}

class _DocSettingsScreenState extends State<DocSettingsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tc = TabController(length: 3, vsync: this, initialIndex: widget.initialTab);
  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات المستندات'),
        bottom: TabBar(controller: _tc, tabs: const [Tab(text: 'الحسابات'), Tab(text: 'الختم والشعار'), Tab(text: 'الترقيم والشروط')]),
      ),
      body: TabBarView(controller: _tc, children: const [_CalcTab(), _StampTab(), _NumberingTab()]),
    );
  }
}

/// تبويب الحسابات — الضريبة والخصم والعربون تشك بوكس
class _CalcTab extends StatelessWidget {
  const _CalcTab();
  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final o = store.org;
    return ListView(padding: const EdgeInsets.fromLTRB(14, 12, 14, 30), children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
        child: Text('فعّل فقط ما تحتاجه. الخيارات غير المفعّلة لا تظهر عند إنشاء الفاتورة ولا في المستند — لتبقى الفاتورة بسيطة.',
            style: TextStyle(color: C.text2, fontSize: 12.5, height: 1.6)),
      ),
      GoldCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          CheckboxListTile(
            secondary: const KIcon(Ic.cash, size: 30),
            title: Text('ضريبة القيمة المضافة', style: TextStyle(fontWeight: FontWeight.w800, color: C.text)),
            subtitle: Text(o.vatEnabled ? 'تُضاف ${o.vatRateBp ~/ 100}% على الفواتير وعروض الأسعار الجديدة' : 'الفواتير بدون ضريبة', style: TextStyle(color: C.text3, fontSize: 12)),
            value: o.vatEnabled,
            controlAffinity: ListTileControlAffinity.trailing,
            onChanged: (v) => store.saveOrg(o..vatEnabled = v ?? false),
          ),
          if (o.vatEnabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(children: [
                Text('نسبة الضريبة', style: TextStyle(color: C.text2, fontWeight: FontWeight.w700, fontSize: 13)),
                const Spacer(),
                SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: const [ButtonSegment(value: 500, label: Text('5%')), ButtonSegment(value: 1000, label: Text('10%')), ButtonSegment(value: 1500, label: Text('15%'))],
                  selected: {o.vatRateBp},
                  onSelectionChanged: (s) => store.saveOrg(o..vatRateBp = s.first),
                ),
              ]),
            ),
          const Divider(),
          CheckboxListTile(
            secondary: const KIcon(Ic.edit, size: 30),
            title: Text('الخصم', style: TextStyle(fontWeight: FontWeight.w800, color: C.text)),
            subtitle: Text(o.discountEnabled ? 'يظهر حقل الخصم عند إنشاء المستند' : 'بدون حقل خصم', style: TextStyle(color: C.text3, fontSize: 12)),
            value: o.discountEnabled,
            controlAffinity: ListTileControlAffinity.trailing,
            onChanged: (v) => store.saveOrg(o..discountEnabled = v ?? false),
          ),
          const Divider(),
          CheckboxListTile(
            secondary: const KIcon(Ic.check, size: 30),
            title: Text('العربون (الدفعة المقدمة)', style: TextStyle(fontWeight: FontWeight.w800, color: C.text)),
            subtitle: Text(o.depositEnabled ? 'يظهر حقل العربون في الفاتورة ويُخصم من المستحق' : 'بدون حقل عربون', style: TextStyle(color: C.text3, fontSize: 12)),
            value: o.depositEnabled,
            controlAffinity: ListTileControlAffinity.trailing,
            onChanged: (v) => store.saveOrg(o..depositEnabled = v ?? false),
          ),
        ]),
      ),
    ]);
  }
}

class _StampTab extends StatelessWidget {
  const _StampTab();
  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final o = store.org;
    return ListView(padding: const EdgeInsets.fromLTRB(14, 12, 14, 30), children: [
      GoldCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          CheckboxListTile(
            secondary: const KIcon(Ic.stamp, size: 30),
            title: Text('إظهار الختم في المستندات', style: TextStyle(fontWeight: FontWeight.w800, color: C.text)),
            subtitle: Text('يظهر ختم المؤسسة أسفل الفاتورة والكشف والسند', style: TextStyle(color: C.text3, fontSize: 12)),
            value: o.showStamp,
            controlAffinity: ListTileControlAffinity.trailing,
            onChanged: (v) => store.saveOrg(o..showStamp = v ?? true),
          ),
          const Divider(),
          CheckboxListTile(
            secondary: const KIcon(Ic.dallah, size: 30),
            title: Text('العلامة المائية (الشعار)', style: TextStyle(fontWeight: FontWeight.w800, color: C.text)),
            subtitle: Text('شعار شفاف خلف محتوى المستند', style: TextStyle(color: C.text3, fontSize: 12)),
            value: o.showWatermark,
            controlAffinity: ListTileControlAffinity.trailing,
            onChanged: (v) => store.saveOrg(o..showWatermark = v ?? true),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: _AssetPreview('الشعار', 'assets/img/logo.png')),
        const SizedBox(width: 10),
        Expanded(child: _AssetPreview('الختم', 'assets/img/stamp.png')),
      ]),
    ]);
  }
}

class _AssetPreview extends StatelessWidget {
  final String label, asset;
  const _AssetPreview(this.label, this.asset);
  @override
  Widget build(BuildContext context) => GoldCard(
        child: Column(children: [
          Container(
            height: 110,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.all(10),
            child: Image.asset(asset, fit: BoxFit.contain),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: C.text2, fontSize: 12.5)),
        ]),
      );
}

class _NumberingTab extends StatefulWidget {
  const _NumberingTab();
  @override
  State<_NumberingTab> createState() => _NumberingTabState();
}

class _NumberingTabState extends State<_NumberingTab> {
  late final Org o = Org.fromMap(context.read<Store>().org.toMap());
  late final c = <String, TextEditingController>{
    'invPrefix': TextEditingController(text: o.invPrefix),
    'quotePrefix': TextEditingController(text: o.quotePrefix),
    'invStart': TextEditingController(text: '${o.invStart}'),
    'invoiceTerms': TextEditingController(text: o.invoiceTerms),
    'quoteTerms': TextEditingController(text: o.quoteTerms),
  };
  @override
  void dispose() {
    for (final t in c.values) {
      t.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(14, 12, 14, 30), children: [
        const SectionTitle('الترقيم'),
        Row(children: [
          Expanded(child: Field('بادئة الفاتورة', controller: c['invPrefix'], direction: TextDirection.ltr)),
          const SizedBox(width: 10),
          Expanded(child: Field('بادئة العرض', controller: c['quotePrefix'], direction: TextDirection.ltr)),
          const SizedBox(width: 10),
          Expanded(child: Field('يبدأ من', controller: c['invStart'], type: TextInputType.number)),
        ]),
        const SectionTitle('الشروط الافتراضية'),
        Field('شروط الفاتورة', controller: c['invoiceTerms'], maxLines: 4),
        Field('شروط عرض السعر', controller: c['quoteTerms'], maxLines: 4),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () async {
            String v(String k) => c[k]!.text.trim();
            final cur = context.read<Store>().org
              ..invPrefix = v('invPrefix')
              ..quotePrefix = v('quotePrefix')
              ..invStart = int.tryParse(v('invStart')) ?? 1
              ..invoiceTerms = v('invoiceTerms')
              ..quoteTerms = v('quoteTerms');
            await context.read<Store>().saveOrg(cur);
            if (context.mounted) toast(context, 'تم الحفظ');
          },
          icon: const Icon(Icons.save_rounded),
          label: const Text('حفظ'),
        ),
      ]);
}

/* ============================================================
   الحماية
   ============================================================ */
class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final lock = context.watch<LockService>();
    return Scaffold(
      appBar: AppBar(title: const Text('الحماية')),
      body: ListView(padding: const EdgeInsets.fromLTRB(14, 12, 14, 30), children: [
        GoldCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            SwitchListTile(
              secondary: Icon(lock.enabled ? Icons.lock_rounded : Icons.lock_open_rounded, color: lock.enabled ? C.gold : C.text3),
              title: Text('قفل التطبيق برمز سري', style: TextStyle(fontWeight: FontWeight.w800, color: C.text)),
              subtitle: Text(
                lock.enabled
                    ? 'مفعّل — يُطلب الرمز عند التشغيل وبعد ${LockService.relockAfterSeconds} ثانية من ترك التطبيق'
                    : 'رمز من 4 إلى 6 أرقام يحمي بياناتك من الغير',
                style: TextStyle(color: C.text3, fontSize: 12),
              ),
              value: lock.enabled,
              onChanged: (v) => v ? enableLock(context, lock) : disableLock(context, lock),
            ),
            if (lock.enabled) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.password_rounded),
                title: const Text('تغيير الرمز'),
                onTap: () => changePin(context, lock),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.lock_clock_rounded),
                title: const Text('قفل الآن'),
                onTap: lock.lockNow,
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}

/* ============================================================
   ملفات الهاتف (مدخل)
   ============================================================ */
class FilesEntryScreen extends StatelessWidget {
  const FilesEntryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    if (FileService.supported) return const FilesScreen();
    return Scaffold(
      appBar: AppBar(title: const Text('ملفات الهاتف')),
      body: const EmptyState(
        icon: Icons.folder_off_outlined,
        title: 'متاح في تطبيق أندرويد فقط',
        hint: 'على الويب استخدم "مشاركة/تنزيل" من شاشة معاينة المستند.',
      ),
    );
  }
}

/* ============================================================
   منطقة الخطر
   ============================================================ */
class DangerScreen extends StatelessWidget {
  const DangerScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.read<Store>();
    final lock = context.read<LockService>();
    return Scaffold(
      appBar: AppBar(title: const Text('منطقة الخطر')),
      body: ListView(padding: const EdgeInsets.fromLTRB(14, 12, 14, 30), children: [
        GoldCard(
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: Icon(Icons.delete_forever_rounded, color: C.red),
            title: Text('مسح جميع البيانات', style: TextStyle(fontWeight: FontWeight.w800, color: C.red)),
            subtitle: Text('لا يمكن التراجع. احفظ نسخة احتياطية أولًا.', style: TextStyle(color: C.text3, fontSize: 12)),
            onTap: () async {
              if (!await confirm(context, 'مسح كل البيانات', 'سيتم حذف جميع العملاء والفواتير والدفعات نهائيًا ولا يمكن استرجاعها.\n\nهل حفظت نسخة احتياطية؟', ok: 'نعم، امسح الكل')) return;
              if (!context.mounted) return;
              if (!await confirm(context, 'تأكيد أخير', 'اضغط "مسح نهائي" فقط إذا كنت متأكدًا تمامًا.', ok: 'مسح نهائي')) return;
              if (!context.mounted) return;
              if (lock.enabled) {
                final pin = await askPin(context, 'أدخل رمز القفل للتأكيد');
                if (pin == null || !context.mounted) return;
                if (!lock.verify(pin)) {
                  toast(context, 'الرمز غير صحيح', error: true);
                  return;
                }
              }
              if (FileService.supported) await FileService.saveBackup(store.exportJson(), 'before-wipe-${DateTime.now().millisecondsSinceEpoch}.json');
              await store.wipe();
              if (context.mounted) {
                toast(context, 'تم مسح جميع البيانات (حُفظت نسخة أمان في مجلد الهاتف)');
                Navigator.pop(context);
              }
            },
          ),
        ),
      ]),
    );
  }
}

/* ============================================================
   حول التطبيق
   ============================================================ */
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('حول التطبيق')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Image(image: AssetImage('assets/img/logo.png'), width: 140),
              const SizedBox(height: 18),
              Text('كيف الضيافة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: C.text)),
              Text('نظام الفواتير وكشوف الحساب', style: TextStyle(color: C.text2)),
              const SizedBox(height: 8),
              Text('الإصدار 2.2.0', style: TextStyle(color: C.goldInk, fontWeight: FontWeight.w800)),
              const SizedBox(height: 18),
              Text('بياناتك محفوظة على جهازك فقط. استخدم النسخة الاحتياطية لحمايتها.', textAlign: TextAlign.center, style: TextStyle(color: C.text3, fontSize: 12.5, height: 1.6)),
            ]),
          ),
        ),
      );
}

/* ============================================================
   النسخة الاحتياطية (نسخة مبدئية — تُستكمل في الجزء 4)
   ============================================================ */
class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    return Scaffold(
      appBar: AppBar(title: const Text('النسخة الاحتياطية')),
      body: ListView(padding: const EdgeInsets.fromLTRB(14, 12, 14, 30), children: [
        GoldCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            if (FileService.supported) ...[
              SwitchListTile(
                secondary: const Icon(Icons.cloud_sync_rounded),
                title: Text('نسخة احتياطية تلقائية', style: TextStyle(fontWeight: FontWeight.w800, color: C.text)),
                subtitle: Text('بعد كل تعديل تُحفظ نسخة اليوم في مجلد الهاتف', style: TextStyle(color: C.text3, fontSize: 12)),
                value: store.autoBackupEnabled,
                onChanged: store.setAutoBackup,
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.save_rounded),
                title: const Text('حفظ نسخة في مجلد الهاتف الآن'),
                onTap: () => runBusy(context, 'جارٍ الحفظ…', () async {
                  final p = await store.backupNow();
                  if (p == null) throw Exception('تعذّر الوصول إلى مجلد الهاتف');
                }).then((ok) {
                  if (ok && context.mounted) toast(context, 'تم حفظ النسخة في مجلد الهاتف');
                }),
              ),
              const Divider(),
            ],
            ListTile(
              leading: const Icon(Icons.send_rounded),
              title: const Text('إرسال نسخة (واتساب / بريد)'),
              subtitle: Text('${store.clients.length} عميل • ${store.docs.length} مستند • ${store.payments.length} دفعة', style: TextStyle(color: C.text3, fontSize: 12)),
              onTap: () => runBusy(context, 'جارٍ تجهيز النسخة…', () async {
                final json = store.exportJson();
                final name = 'keif-diafa-backup-${todayISO()}.json';
                await Share.shareXFiles([XFile.fromData(utf8.encode(json), mimeType: 'application/json', name: name)], subject: name);
              }),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.restore_rounded),
              title: const Text('استرجاع نسخة احتياطية'),
              onTap: () => importBackupFromFile(context, store),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.content_paste_rounded),
              title: const Text('استرجاع بلصق النص (للمتقدمين)'),
              onTap: () => importBackupByPaste(context, store),
            ),
          ]),
        ),
      ]),
    );
  }
}

/* ---------- دوال مساعدة مشتركة (القفل / الاسترجاع) ---------- */
/* ---------- القفل ---------- */
Future<void> enableLock(BuildContext context, LockService lock) async {
  final p1 = await askPin(context, 'اختر رمز القفل', hint: 'من 4 إلى 6 أرقام. احفظه جيدًا — لا يمكن استرجاعه إن نسيته.');
  if (p1 == null || !context.mounted) return;
  if (!LockService.isValidPin(p1)) {
    toast(context, 'الرمز يجب أن يكون من 4 إلى 6 أرقام', error: true);
    return;
  }
  final p2 = await askPin(context, 'أعد إدخال الرمز للتأكيد');
  if (p2 == null || !context.mounted) return;
  if (p1 != p2) {
    toast(context, 'الرمزان غير متطابقين، حاول مرة أخرى', error: true);
    return;
  }
  try {
    await lock.setPin(p1);
    if (context.mounted) toast(context, 'تم تفعيل قفل التطبيق');
  } catch (e) {
    if (context.mounted) toast(context, 'تعذّر التفعيل: $e', error: true);
  }
}

Future<void> disableLock(BuildContext context, LockService lock) async {
  final pin = await askPin(context, 'أدخل الرمز الحالي لإلغاء القفل');
  if (pin == null || !context.mounted) return;
  if (!lock.verify(pin)) {
    toast(context, 'الرمز غير صحيح', error: true);
    return;
  }
  await lock.disable();
  if (context.mounted) toast(context, 'تم إلغاء قفل التطبيق');
}

Future<void> changePin(BuildContext context, LockService lock) async {
  final cur = await askPin(context, 'أدخل الرمز الحالي');
  if (cur == null || !context.mounted) return;
  if (!lock.verify(cur)) {
    toast(context, 'الرمز غير صحيح', error: true);
    return;
  }
  await enableLock(context, lock);
}

/// استرجاع من ملف عبر منتقي الملفات (الطريقة الأسهل لغير المتخصصين)
Future<void> importBackupFromFile(BuildContext context, Store store) async {
  FilePickerResult? res;
  try {
    res = await FilePicker.pickFiles(
      dialogTitle: 'اختر ملف النسخة الاحتياطية',
      type: FileType.any,
      withData: true,
    );
  } catch (e) {
    if (context.mounted) toast(context, 'تعذّر فتح منتقي الملفات: $e', error: true);
    return;
  }
  if (res == null || res.files.isEmpty || !context.mounted) return;
  final f = res.files.first;
  final bytes = f.bytes;
  if (bytes == null) {
    toast(context, 'تعذّر قراءة الملف. جرّب طريقة "لصق النص".', error: true);
    return;
  }
  String text;
  try {
    text = utf8.decode(bytes);
  } catch (_) {
    toast(context, 'هذا الملف ليس نسخة احتياطية صالحة.', error: true);
    return;
  }
  await applyBackupImport(context, store, text, sourceName: f.name);
}

/// استرجاع بلصق النص (احتياطي)
Future<void> importBackupByPaste(BuildContext context, Store store) async {
  final ctl = TextEditingController();
  final clip = await Clipboard.getData('text/plain');
  if (clip?.text != null && clip!.text!.trim().startsWith('{')) ctl.text = clip.text!;
  if (!context.mounted) return;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('استرجاع بلصق النص'),
      content: TextField(controller: ctl, maxLines: 8, style: const TextStyle(fontSize: 11, fontFamily: 'monospace'), decoration: const InputDecoration(hintText: 'الصق محتوى ملف النسخة هنا')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('استرجاع')),
      ],
    ),
  );
  final text = ctl.text;
  ctl.dispose();
  if (ok != true || !context.mounted) return;
  await applyBackupImport(context, store, text);
}

Future<void> applyBackupImport(BuildContext context, Store store, String text, {String? sourceName}) async {
  if (text.trim().isEmpty) {
    toast(context, 'لا يوجد محتوى للاسترجاع.', error: true);
    return;
  }
  // تحقق مسبق حتى لا نسأل المستخدم عن ملف غير صالح
  Map? parsed;
  try {
    final m = jsonDecode(text);
    if (m is Map && m['data'] is Map) parsed = m['data'] as Map;
  } catch (_) {}
  if (parsed == null) {
    toast(context, 'هذا الملف ليس نسخة احتياطية من كيف الضيافة.', error: true);
    return;
  }
  final nc = (parsed['clients'] as List?)?.length ?? 0;
  final nd = ((parsed['docs'] as List?)?.length ?? 0) + ((parsed['invoices'] as List?)?.length ?? 0);
  final np = (parsed['payments'] as List?)?.length ?? 0;
  final go = await confirm(
    context,
    'استرجاع النسخة الاحتياطية',
    '${sourceName != null ? 'الملف: $sourceName\n\n' : ''}تحتوي النسخة على: $nc عميل • $nd مستند • $np دفعة.\n\nسيتم إضافتها إلى بياناتك الحالية (وتحديث السجلات المتطابقة) دون حذف أي شيء.',
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

/* ============================================================
   نموذج المؤسسة
   ============================================================ */
class OrgForm extends StatefulWidget {
  const OrgForm({super.key});
  @override
  State<OrgForm> createState() => _OrgFormState();
}

class _OrgFormState extends State<OrgForm> {
  late final Org o = Org.fromMap(context.read<Store>().org.toMap());
  late final c = <String, TextEditingController>{
    'name': TextEditingController(text: o.name),
    'nameEn': TextEditingController(text: o.nameEn),
    'cr': TextEditingController(text: o.cr),
    'vat': TextEditingController(text: o.vat),
    'city': TextEditingController(text: o.city),
    'phone': TextEditingController(text: o.phone),
    'website': TextEditingController(text: o.website),
    'email': TextEditingController(text: o.email),
    'bankName': TextEditingController(text: o.bankName),
    'bankAccount': TextEditingController(text: o.bankAccount),
    'iban': TextEditingController(text: o.iban),
  };

  @override
  void dispose() {
    for (final t in c.values) {
      t.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('بيانات المؤسسة')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const SectionTitle('الترويسة'),
        Field('اسم المؤسسة', controller: c['name'], icon: Icons.business_outlined),
        Field('الاسم بالإنجليزية', controller: c['nameEn'], icon: Icons.translate, direction: TextDirection.ltr),
        Row(children: [
          Expanded(child: Field('السجل التجاري', controller: c['cr'], type: TextInputType.number, direction: TextDirection.ltr)),
          const SizedBox(width: 10),
          Expanded(child: Field('الرقم الضريبي', controller: c['vat'], type: TextInputType.number, direction: TextDirection.ltr)),
        ]),
        Field('المدينة', controller: c['city'], icon: Icons.location_city_outlined),
        Field('الهاتف', controller: c['phone'], icon: Icons.phone_outlined, type: TextInputType.phone, direction: TextDirection.ltr),
        Field('الموقع الإلكتروني', controller: c['website'], icon: Icons.language, direction: TextDirection.ltr),
        Field('البريد الإلكتروني', controller: c['email'], icon: Icons.mail_outline, direction: TextDirection.ltr),
        const SectionTitle('الحساب البنكي'),
        Field('اسم البنك', controller: c['bankName'], icon: Icons.account_balance_outlined),
        Field('رقم الحساب', controller: c['bankAccount'], type: TextInputType.number, direction: TextDirection.ltr),
        Field('IBAN', controller: c['iban'], direction: TextDirection.ltr),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () async {
            String v(String k) => c[k]!.text.trim();
            o
              ..name = v('name')
              ..nameEn = v('nameEn')
              ..cr = v('cr')
              ..vat = v('vat')
              ..city = v('city')
              ..phone = v('phone')
              ..website = v('website')
              ..email = v('email')
              ..bankName = v('bankName')
              ..bankAccount = v('bankAccount')
              ..iban = v('iban').replaceAll(' ', '').toUpperCase();
            await context.read<Store>().saveOrg(o);
            if (context.mounted) {
              toast(context, 'تم حفظ بيانات المؤسسة');
              Navigator.pop(context);
            }
          },
          icon: const Icon(Icons.save_rounded),
          label: const Text('حفظ'),
        ),
      ]),
    );
  }
}
