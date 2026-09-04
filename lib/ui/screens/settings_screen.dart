/// settings_screen.dart — الإعدادات: الترويسة، الترقيم، النسخ الاحتياطي | كيف الضيافة
library;

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models.dart';
import '../../core/store.dart';
import '../theme.dart';
import '../widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final o = store.org;
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(padding: const EdgeInsets.fromLTRB(14, 4, 14, 30), children: [
        GoldCard(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrgForm())),
          child: Row(children: [
            // الشعار مباشرة على الخلفية بدون صندوق أبيض
            const SizedBox(
              width: 58,
              height: 58,
              child: Image(image: AssetImage('assets/img/logo.png'), fit: BoxFit.contain),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(o.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                Text('س.ت ${o.cr} • ${o.phone}', style: const TextStyle(color: C.muted, fontSize: 12.5)),
                const Text('بيانات الترويسة والبنك', style: TextStyle(color: C.goldLight, fontSize: 12)),
              ]),
            ),
            const Icon(Icons.chevron_left, color: C.muted),
          ]),
        ),
        const SectionTitle('المستندات'),
        GoldCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            SwitchListTile(
              title: const Text('إظهار الختم في المستندات', style: TextStyle(fontWeight: FontWeight.w700)),
              value: o.showStamp,
              onChanged: (v) => store.saveOrg(o..showStamp = v),
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('العلامة المائية (الشعار)', style: TextStyle(fontWeight: FontWeight.w700)),
              value: o.showWatermark,
              onChanged: (v) => store.saveOrg(o..showWatermark = v),
            ),
          ]),
        ),
        const SectionTitle('النسخة الاحتياطية'),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Text(
            'بياناتك محفوظة على هذا الجهاز فقط. احفظ نسخة احتياطية بشكل دوري (مثلًا كل أسبوع) وأرسلها لنفسك على واتساب أو البريد، حتى لا تفقد شيئًا لو ضاع الجهاز أو تغيّر.',
            style: TextStyle(color: C.muted, fontSize: 12.5, height: 1.5),
          ),
        ),
        GoldCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.save_alt_rounded),
              title: const Text('حفظ نسخة احتياطية', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${store.clients.length} عميل • ${store.docs.length} مستند • ${store.payments.length} دفعة — يُنشأ ملف واحد يمكنك إرساله لنفسك',
                  style: const TextStyle(color: C.muted, fontSize: 12)),
              onTap: () => runBusy(context, 'جارٍ تجهيز النسخة…', () async {
                final json = store.exportJson();
                final name = 'keif-diafa-backup-${todayISO()}.json';
                await Share.shareXFiles([XFile.fromData(utf8.encode(json), mimeType: 'application/json', name: name)], subject: name);
              }),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.restore_rounded),
              title: const Text('استرجاع نسخة احتياطية', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('اختر ملف النسخة (keif-diafa-backup-…json) من جهازك', style: TextStyle(color: C.muted, fontSize: 12)),
              onTap: () => _importFromFile(context, store),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.content_paste_rounded),
              title: const Text('استرجاع بلصق النص (للمتقدمين)', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('إن تعذّر اختيار الملف: افتح ملف النسخة، انسخ محتواه كاملًا ثم الصقه هنا', style: TextStyle(color: C.muted, fontSize: 12)),
              onTap: () => _import(context, store),
            ),
          ]),
        ),
        const SectionTitle('منطقة الخطر'),
        GoldCard(
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.delete_forever_rounded, color: C.red),
            title: const Text('مسح جميع البيانات', style: TextStyle(fontWeight: FontWeight.w700, color: C.red)),
            subtitle: const Text('لا يمكن التراجع. احفظ نسخة احتياطية أولًا.', style: TextStyle(color: C.muted, fontSize: 12)),
            onTap: () async {
              if (!await confirm(context, 'مسح كل البيانات', 'سيتم حذف جميع العملاء والفواتير والدفعات نهائيًا ولا يمكن استرجاعها.\n\nهل حفظت نسخة احتياطية؟', ok: 'نعم، امسح الكل')) return;
              if (!context.mounted) return;
              // تأكيد ثانٍ لحماية المستخدم من الضغط بالخطأ
              if (!await confirm(context, 'تأكيد أخير', 'اضغط "مسح نهائي" فقط إذا كنت متأكدًا تمامًا.', ok: 'مسح نهائي')) return;
              await store.wipe();
              if (context.mounted) toast(context, 'تم مسح جميع البيانات');
            },
          ),
        ),
        const SizedBox(height: 24),
        const Center(child: Text('كيف الضيافة • نظام الفواتير وكشوف الحساب • v2.0', style: TextStyle(color: C.muted, fontSize: 12))),
      ]),
    );
  }

  /// استرجاع من ملف عبر منتقي الملفات (الطريقة الأسهل لغير المتخصصين)
  Future<void> _importFromFile(BuildContext context, Store store) async {
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
    await _applyImport(context, store, text, sourceName: f.name);
  }

  /// استرجاع بلصق النص (احتياطي)
  Future<void> _import(BuildContext context, Store store) async {
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
    await _applyImport(context, store, text);
  }

  Future<void> _applyImport(BuildContext context, Store store, String text, {String? sourceName}) async {
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
              ..iban = v('iban').replaceAll(' ', '').toUpperCase()
              ..invPrefix = v('invPrefix')
              ..quotePrefix = v('quotePrefix')
              ..invStart = int.tryParse(v('invStart')) ?? 1
              ..invoiceTerms = v('invoiceTerms')
              ..quoteTerms = v('quoteTerms');
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
