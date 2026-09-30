/// settings_screen.dart — مركز الإعدادات وشاشاته (ملاحظات 4، 8، 11، 12) | كيف الضيافة
/// الهيكل: الإعدادات → بيانات المؤسسة، إعدادات الفواتير، المظهر، الأمان، سلة المحذوفات، حول التطبيق
// ignore_for_file: use_build_context_synchronously
library;

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/brand.dart';
import '../../core/backup_service.dart';
import '../../core/drive_service.dart';
import '../../core/file_service.dart';
import '../../core/lock_service.dart';
import '../../core/hijri.dart';
import '../../core/models.dart';
import '../../core/money.dart';
import '../../core/store.dart';
import '../drawer.dart';
import '../theme.dart';
import '../widgets.dart';
import 'lock_screen.dart';

/* ============================================================
   مركز الإعدادات (ملاحظة 4/12) — إعدادات حقيقية فقط
   ============================================================ */
class SettingsHub extends StatelessWidget {
  static const version = '2.6.0';
  const SettingsHub({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final lock = context.watch<LockService>();
    final o = store.org;
    void open(Widget page) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 30),
        children: [
          DrawerItem(
            Ic.dallah,
            'بيانات المؤسسة',
            '${o.name} • ${o.city}',
            onTap: () => open(const OrgForm()),
          ),
          DrawerItem(
            Ic.invoice,
            'إعدادات الفواتير',
            'الحسابات، الوحدات، الترقيم، الشروط، الختم والشعار، عناصر المستند',
            onTap: () => open(const DocSettingsScreen()),
          ),
          DrawerItem(
            Ic.stamp,
            'المظهر',
            AppTheme.fromKey(store.themeKey).label,
            onTap: () => open(const AppearanceScreen()),
          ),
          DrawerItem(
            Ic.check,
            'الأمان',
            lock.enabled ? 'قفل التطبيق مفعّل' : 'قفل التطبيق غير مفعّل',
            onTap: () => open(const SecurityScreen()),
          ),
          DrawerItem(
            Ic.trash,
            'سلة المحذوفات',
            store.trashCount == 0
                ? 'فارغة'
                : '${store.trashCount} عنصر • تُحذف نهائيًا بعد ${Store.trashDays} يومًا',
            onTap: () => open(const TrashScreen()),
          ),
          DrawerItem(
            Ic.pin,
            'حول التطبيق',
            'الإصدار $version • معين العباسي',
            onTap: () => open(const AboutScreen()),
          ),
        ],
      ),
    );
  }
}

/* ============================================================
   إعدادات الفواتير — 4 تبويبات
   ============================================================ */
class DocSettingsScreen extends StatefulWidget {
  final int initialTab;
  const DocSettingsScreen({super.key, this.initialTab = 0});
  @override
  State<DocSettingsScreen> createState() => _DocSettingsScreenState();
}

class _DocSettingsScreenState extends State<DocSettingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tc = TabController(
    length: 5,
    vsync: this,
    initialIndex: widget.initialTab,
  );
  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات الفواتير'),
        bottom: TabBar(
          controller: _tc,
          isScrollable: true,
          tabAlignment: TabAlignment.center,
          tabs: const [
            Tab(text: 'الحسابات'),
            Tab(text: 'الوحدات'),
            Tab(text: 'الترقيم'),
            Tab(text: 'عناصر المستند'),
            Tab(text: 'الختم والشعار'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tc,
        children: const [
          _CalcTab(),
          _UnitsTab(),
          _NumberingTab(),
          _ElementsTab(),
          _StampTab(),
        ],
      ),
    );
  }
}

Widget _check(
  String icon,
  String title,
  String sub,
  bool value,
  ValueChanged<bool> on,
) => CheckboxListTile(
  secondary: KIcon(icon, size: 30),
  title: Text(
    title,
    style: TextStyle(fontWeight: FontWeight.w800, color: C.text),
  ),
  subtitle: Text(sub, style: TextStyle(color: C.text3, fontSize: 12)),
  value: value,
  controlAffinity: ListTileControlAffinity.trailing,
  onChanged: (v) => on(v ?? false),
);

Widget _hint(String t) => Padding(
  padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
  child: Text(t, style: TextStyle(color: C.text2, fontSize: 12.5, height: 1.6)),
);

/// تبويب الوحدات — وحدات البنود (فترة/يوم/شخص/موقع…) قابلة للإضافة والتعديل والحذف والترتيب
class _UnitsTab extends StatelessWidget {
  const _UnitsTab();

  Future<void> _save(Store store, List<String> units) =>
      store.saveOrg(store.org..units = normalizeUnits(units));

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final units = store.org.effectiveUnits;
    final isDefault = units.join('\u0000') == unitLabels.join('\u0000');
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
      children: [
        _hint(
          'هذه الوحدات تظهر كأزرار عند إضافة بند في الفاتورة أو عرض السعر. '
          'الوحدة تُضرب في الكمية (مثال: موقع × 2). اسحب من المقبض لإعادة الترتيب. '
          'حذف وحدة لا يغيّر المستندات القديمة التي استخدمتها.',
        ),
        const SectionTitle('الوحدات الحالية'),
        GoldCard(
          padding: EdgeInsets.zero,
          child: ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: units.length,
            onReorder: (a, b) {
              final l = List.of(units);
              final u = l.removeAt(a);
              l.insert(b > a ? b - 1 : b, u);
              _save(store, l);
            },
            itemBuilder: (ctx, i) => ListTile(
              key: ValueKey('unit-${units[i]}'),
              leading: ReorderableDragStartListener(
                index: i,
                child: Icon(Icons.drag_indicator, color: C.text3),
              ),
              title: Text(
                units[i],
                style: TextStyle(fontWeight: FontWeight.w800, color: C.text),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'تعديل',
                    icon: Icon(Icons.edit_outlined, color: C.text2, size: 20),
                    onPressed: () async {
                      final n = await askUnitName(
                        context,
                        initial: units[i],
                        existing: units,
                      );
                      if (n == null || n == units[i]) return;
                      final l = List.of(units)..[i] = n;
                      _save(store, l);
                    },
                  ),
                  IconButton(
                    tooltip: 'حذف',
                    icon: Icon(
                      Icons.delete_outline,
                      color: units.length == 1 ? C.text3 : C.danger,
                      size: 20,
                    ),
                    onPressed: units.length == 1
                        ? null
                        : () async {
                            final ok = await confirm(
                              context,
                              'حذف الوحدة «${units[i]}»؟',
                              'لن تظهر في البنود الجديدة. المستندات القديمة لا تتأثر.',
                            );
                            if (!ok) return;
                            final l = List.of(units)..removeAt(i);
                            _save(store, l);
                          },
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () async {
            final n = await askUnitName(context, existing: units);
            if (n == null) return;
            _save(store, [...units, n]);
          },
          icon: const Icon(Icons.add),
          label: const Text('إضافة وحدة'),
        ),
        if (!isDefault) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final ok = await confirm(
                context,
                'استعادة الوحدات الافتراضية؟',
                'ستُستبدل قائمتك الحالية بـ: ${unitLabels.join('، ')}.',
                ok: 'استعادة',
                danger: false,
              );
              if (ok) _save(store, unitLabels);
            },
            icon: const Icon(Icons.restore),
            label: const Text('استعادة الافتراضي'),
          ),
        ],
      ],
    );
  }
}

/// تبويب الحسابات — الضريبة والخصم والعربون
class _CalcTab extends StatelessWidget {
  const _CalcTab();
  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final o = store.org;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
      children: [
        _hint(
          'فعّل فقط ما تحتاجه. الخيارات غير المفعّلة لا تظهر عند إنشاء الفاتورة ولا في المستند — لتبقى الفاتورة بسيطة.',
        ),
        GoldCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _check(
                Ic.cash,
                'ضريبة القيمة المضافة',
                o.vatEnabled
                    ? 'تُضاف ${o.vatRateBp ~/ 100}% على الفواتير وعروض الأسعار الجديدة'
                    : 'الفواتير بدون ضريبة',
                o.vatEnabled,
                (v) => store.saveOrg(o..vatEnabled = v),
              ),
              if (o.vatEnabled)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: [
                      Text(
                        'نسبة الضريبة',
                        style: TextStyle(
                          color: C.text2,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      SegmentedButton<int>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: 500, label: Text('5%')),
                          ButtonSegment(value: 1000, label: Text('10%')),
                          ButtonSegment(value: 1500, label: Text('15%')),
                        ],
                        selected: {o.vatRateBp},
                        onSelectionChanged: (s) =>
                            store.saveOrg(o..vatRateBp = s.first),
                      ),
                    ],
                  ),
                ),
              const Divider(),
              _check(
                Ic.edit,
                'الخصم',
                o.discountEnabled
                    ? 'يظهر حقل الخصم عند إنشاء المستند'
                    : 'بدون حقل خصم',
                o.discountEnabled,
                (v) => store.saveOrg(o..discountEnabled = v),
              ),
              const Divider(),
              _check(
                Ic.check,
                'العربون (الدفعة المقدمة)',
                o.depositEnabled
                    ? 'يظهر حقل العربون في الفاتورة ويُخصم من المستحق'
                    : 'بدون حقل عربون',
                o.depositEnabled,
                (v) => store.saveOrg(o..depositEnabled = v),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// تبويب عناصر المستند (ملاحظة 11أ) — لا يظهر في PDF إلا ما فُعِّل
class _ElementsTab extends StatelessWidget {
  const _ElementsTab();
  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final o = store.org;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
      children: [
        _hint(
          'كل عنصر هنا يظهر في الفاتورة وعرض السعر والكشف والسند فقط إذا كان مفعّلًا وبياناته موجودة. غير المفعّل لا يُطبع إطلاقًا.',
        ),
        const SectionTitle('الترويسة'),
        GoldCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _check(
                Ic.pin,
                'السجل التجاري',
                o.cr.isEmpty
                    ? 'لا يوجد سجل — لا يظهر في المستندات (اختياري)'
                    : 'س.ت ${o.cr}',
                o.showCr,
                (v) => store.saveOrg(o..showCr = v),
              ),
              const Divider(),
              _check(
                Ic.pin,
                'الرقم الضريبي',
                o.vat.isEmpty
                    ? 'أدخل الرقم من «بيانات المؤسسة»'
                    : 'VAT ${o.vat}',
                o.showVatNumber,
                (v) => store.saveOrg(o..showVatNumber = v),
              ),
              const Divider(),
              _check(
                Ic.calendar,
                'التاريخ الهجري',
                o.hijriEnabled
                    ? 'يظهر بجوار الميلادي في المستندات والتطبيق — اليوم ${UmmAlQura.fromIso(todayISO())}'
                    : 'ميلادي فقط. عند التفعيل يُكتب الهجري (أم القرى) بين قوسين',
                o.hijriEnabled,
                (v) => store.saveOrg(o..hijriEnabled = v),
              ),
            ],
          ),
        ),
        const SectionTitle('جسم المستند'),
        GoldCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _check(
                Ic.calendar,
                'بطاقة تفاصيل المناسبة',
                'التاريخ والموقع وعدد الضيوف',
                o.showEventBlock,
                (v) => store.saveOrg(o..showEventBlock = v),
              ),
              const Divider(),
              _check(
                Ic.cash,
                'المدفوع والمتبقي',
                'سطر العربون/المدفوع والمتبقي في الفاتورة',
                o.showRemaining,
                (v) => store.saveOrg(o..showRemaining = v),
              ),
              const Divider(),
              _check(
                Ic.edit,
                'المبلغ كتابةً (تفقيط)',
                'مثال: «فقط خمسة آلاف ريال لا غير»',
                o.showTafqit,
                (v) => store.saveOrg(o..showTafqit = v),
              ),
              const Divider(),
              _check(
                Ic.statement,
                'الشروط والأحكام',
                'صندوق الشروط أسفل المستند',
                o.showTerms,
                (v) => store.saveOrg(o..showTerms = v),
              ),
              const Divider(),
              _check(
                Ic.check,
                'إقرار الاستلام',
                'نص إقرار العميل باستلام الخدمة',
                o.showAck,
                (v) => store.saveOrg(o..showAck = v),
              ),
            ],
          ),
        ),
        const SectionTitle('التذييل'),
        GoldCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _check(
                Ic.statement,
                'الحساب البنكي و IBAN',
                o.iban.isEmpty && o.bankAccount.isEmpty
                    ? 'أدخل البيانات من «بيانات المؤسسة»'
                    : '${o.bankName} • ${o.iban}',
                o.showBank,
                (v) => store.saveOrg(o..showBank = v),
              ),
              const Divider(),
              _check(
                Ic.stamp,
                'خانات التوقيع',
                'توقيع المؤسسة والعميل',
                o.showSignatures,
                (v) => store.saveOrg(o..showSignatures = v),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StampTab extends StatelessWidget {
  const _StampTab();
  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final o = store.org;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
      children: [
        GoldCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _check(
                Ic.stamp,
                'إظهار الختم في المستندات',
                'يظهر ختم المؤسسة أسفل الفاتورة والكشف والسند',
                o.showStamp,
                (v) => store.saveOrg(o..showStamp = v),
              ),
              const Divider(),
              _check(
                Ic.dallah,
                'العلامة المائية (الشعار)',
                'شعار شفاف خلف محتوى المستند',
                o.showWatermark,
                (v) => store.saveOrg(o..showWatermark = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _AssetPreview(
                'الشعار',
                Brand.current.logo,
                o.logoPath,
                field: 'logo',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _AssetPreview(
                'الختم',
                Brand.current.stamp,
                o.stampPath,
                field: 'stamp',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          FileService.supported
              ? 'اضغط «تغيير» لاختيار صورة شعارك أو ختمك الرسمي من الهاتف (PNG بخلفية شفافة أفضل). تُستخدم في كل المستندات فورًا.'
              : 'تغيير الشعار والختم متاح على الهاتف.',
          textAlign: TextAlign.center,
          style: TextStyle(color: C.text3, fontSize: 11.5),
        ),
      ],
    );
  }
}

class _AssetPreview extends StatelessWidget {
  final String label, asset, custom, field;
  const _AssetPreview(
    this.label,
    this.asset,
    this.custom, {
    required this.field,
  });

  Future<void> _pick(BuildContext context) async {
    final store = context.read<Store>();
    FilePickerResult? r;
    try {
      r = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
        withData: true,
      );
    } catch (e) {
      if (context.mounted) {
        toast(context, 'تعذّر فتح منتقي الصور: $e', error: true);
      }
      return;
    }
    final b = r?.files.firstOrNull?.bytes;
    if (b == null || b.isEmpty) return;
    if (b.length > 3 * 1024 * 1024) {
      if (context.mounted) {
        toast(
          context,
          'الصورة كبيرة جدًا (الحد 3 م.ب) — صغّرها ثم أعد المحاولة',
          error: true,
        );
      }
      return;
    }
    final ext = (r!.files.first.extension ?? 'png').toLowerCase();
    final path = await FileService.saveBrandImage(
      b,
      '${field}_${DateTime.now().millisecondsSinceEpoch}.$ext',
    );
    if (path == null) {
      if (context.mounted) toast(context, 'تعذّر حفظ الصورة', error: true);
      return;
    }
    final o = store.org;
    field == 'logo' ? o.logoPath = path : o.stampPath = path;
    await store.saveOrg(o);
    if (context.mounted) toast(context, 'تم تحديث $label');
  }

  Future<void> _reset(BuildContext context) async {
    final store = context.read<Store>();
    final o = store.org;
    field == 'logo' ? o.logoPath = '' : o.stampPath = '';
    await store.saveOrg(o);
  }

  @override
  Widget build(BuildContext context) => GoldCard(
    child: Column(
      children: [
        Container(
          height: 110,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(10),
          child: custom.isNotEmpty && FileService.supported
              ? FutureBuilder(
                  future: FileService.readBytes(custom),
                  builder: (_, snap) => snap.data == null
                      ? Image.asset(asset, fit: BoxFit.contain)
                      : Image.memory(snap.data!, fit: BoxFit.contain),
                )
              : Image.asset(asset, fit: BoxFit.contain),
        ),
        const SizedBox(height: 8),
        Text(
          custom.isNotEmpty ? '$label (مخصّص)' : label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: C.text2,
            fontSize: 12.5,
          ),
        ),
        if (FileService.supported)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => _pick(context),
                child: Text(
                  'تغيير',
                  style: TextStyle(color: C.gold, fontWeight: FontWeight.w800),
                ),
              ),
              if (custom.isNotEmpty)
                TextButton(
                  onPressed: () => _reset(context),
                  child: Text('الافتراضي', style: TextStyle(color: C.text3)),
                ),
            ],
          ),
      ],
    ),
  );
}

/// تبويب الترقيم والشروط (ملاحظة 11ج) — مع معاينة حيّة للرقم القادم
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

  /// نسخة مؤقتة من الإعدادات بحسب الحقول الحالية (للمعاينة)
  Org get _draft => Org.fromMap(o.toMap())
    ..invPrefix = c['invPrefix']!.text.trim()
    ..quotePrefix = c['quotePrefix']!.text.trim()
    ..invStart = int.tryParse(c['invStart']!.text.trim()) ?? 1;

  @override
  Widget build(BuildContext context) {
    final store = context.read<Store>();
    final d = _draft;
    final seq = o.numberingMode == 'seq';
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
      children: [
        const SectionTitle('نمط الترقيم'),
        GoldCard(
          padding: EdgeInsets.zero,
          child: RadioGroup<String>(
            groupValue: o.numberingMode,
            onChanged: (v) =>
                setState(() => o.numberingMode = v ?? Org.defaultNumberingMode),
            child: Column(
              children: [
                RadioListTile<String>(
                  value: 'datetime',
                  title: Text(
                    'تلقائي من التاريخ والوقت (الافتراضي)',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: C.text,
                    ),
                  ),
                  subtitle: Text(
                    'بادئة + التاريخ والوقت عند الإنشاء (INV-20260509-143522) — فريد دائمًا ولا يحتاج ضبطًا. يشمل الفواتير والعروض والمطالبات وسندات القبض.',
                    style: TextStyle(color: C.text3, fontSize: 12),
                  ),
                ),
                const Divider(height: 1),
                RadioListTile<String>(
                  value: 'seq',
                  title: Text(
                    'تسلسلي',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: C.text,
                    ),
                  ),
                  subtitle: Text(
                    'بادئة + رقم متزايد يبدأ من الرقم الذي تحدده (INV-0001)',
                    style: TextStyle(color: C.text3, fontSize: 12),
                  ),
                ),
                if (seq)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'إدراج السنة في الرقم',
                        style: TextStyle(
                          color: C.text,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        'INV-2026-0001 ويُعاد العدّ كل سنة',
                        style: TextStyle(color: C.text3, fontSize: 12),
                      ),
                      value: o.numberYear,
                      onChanged: (v) => setState(() => o.numberYear = v),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SectionTitle('البادئات'),
        Row(
          children: [
            Expanded(
              child: Field(
                'بادئة الفاتورة',
                controller: c['invPrefix'],
                direction: TextDirection.ltr,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Field(
                'بادئة العرض',
                controller: c['quotePrefix'],
                direction: TextDirection.ltr,
                onChanged: (_) => setState(() {}),
              ),
            ),
            if (seq) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Field(
                  'يبدأ من',
                  controller: c['invStart'],
                  type: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ],
        ),
        // معاينة حيّة
        GoldCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.visibility_outlined, color: C.gold, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الرقم القادم',
                      style: TextStyle(color: C.text3, fontSize: 11.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'فاتورة: ${store.previewNumber(d, DocKind.invoice)}',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        color: C.text,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                    Text(
                      'عرض سعر: ${store.previewNumber(d, DocKind.quotation)}',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        color: C.text,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SectionTitle('الشروط الافتراضية'),
        Field(
          'شروط الفاتورة',
          controller: c['invoiceTerms'],
          minLines: 3,
          maxLines: null,
        ),
        Field(
          'شروط عرض السعر',
          controller: c['quoteTerms'],
          minLines: 3,
          maxLines: null,
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () async {
            String v(String k) => c[k]!.text.trim();
            final cur = store.org
              ..invPrefix = v('invPrefix')
              ..quotePrefix = v('quotePrefix')
              ..invStart = int.tryParse(v('invStart')) ?? 1
              ..numberingMode = o.numberingMode
              ..numberYear = o.numberYear
              ..invoiceTerms = v('invoiceTerms')
              ..quoteTerms = v('quoteTerms');
            await store.saveOrg(cur);
            if (context.mounted) toast(context, 'تم الحفظ');
          },
          icon: const Icon(Icons.save_rounded),
          label: const Text('حفظ'),
        ),
      ],
    );
  }
}

/* ============================================================
   المظهر
   ============================================================ */
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final cur = AppTheme.fromKey(store.themeKey);
    return Scaffold(
      appBar: AppBar(title: const Text('المظهر')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
        children: [
          _hint(
            'اختر الثيم الذي يريحك. يُطبَّق فورًا على كل الشاشات ولا يؤثر على مستندات PDF.',
          ),
          for (final t in AppTheme.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GoldCard(
                onTap: () => store.setTheme(t.key),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    _ThemeDot(t, selected: t == cur),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        t.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: C.text,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                    if (t == cur)
                      Icon(Icons.check_circle_rounded, color: C.gold),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ThemeDot extends StatelessWidget {
  final AppTheme t;
  final bool selected;
  const _ThemeDot(this.t, {required this.selected});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(t);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [p.bg, p.surface2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: p.gold, width: 2.5),
        boxShadow: selected
            ? [BoxShadow(color: C.gold.withValues(alpha: 0.4), blurRadius: 10)]
            : null,
      ),
    );
  }
}

/* ============================================================
   الأمان — القفل + مسح البيانات (بدل «منطقة الخطر» المتفرقة)
   ============================================================ */
class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final lock = context.watch<LockService>();
    final store = context.read<Store>();
    return Scaffold(
      appBar: AppBar(title: const Text('الأمان')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
        children: [
          GoldCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Icon(
                    lock.enabled ? Icons.lock_rounded : Icons.lock_open_rounded,
                    color: lock.enabled ? C.gold : C.text3,
                  ),
                  title: Text(
                    'قفل التطبيق برمز سري',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: C.text,
                    ),
                  ),
                  subtitle: Text(
                    lock.enabled
                        ? 'مفعّل — يُطلب الرمز عند التشغيل وبعد ${LockService.relockAfterSeconds} ثانية من ترك التطبيق'
                        : 'رمز من 4 إلى 6 أرقام يحمي بياناتك من الغير',
                    style: TextStyle(color: C.text3, fontSize: 12),
                  ),
                  value: lock.enabled,
                  onChanged: (v) => v
                      ? enableLock(context, lock)
                      : disableLock(context, lock),
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
              ],
            ),
          ),
          const SectionTitle('إعادة الضبط'),
          GoldCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(Icons.delete_forever_rounded, color: C.red),
              title: Text(
                'مسح جميع البيانات',
                style: TextStyle(fontWeight: FontWeight.w800, color: C.red),
              ),
              subtitle: Text(
                'لا يمكن التراجع. تُحفظ نسخة أمان في مجلد الهاتف قبل المسح.',
                style: TextStyle(color: C.text3, fontSize: 12),
              ),
              onTap: () async {
                if (!await confirm(
                  context,
                  'مسح كل البيانات',
                  'سيتم حذف جميع العملاء والفواتير والدفعات نهائيًا ولا يمكن استرجاعها.\n\nهل حفظت نسخة احتياطية؟',
                  ok: 'نعم، امسح الكل',
                )) {
                  return;
                }
                if (!context.mounted) return;
                if (!await confirm(
                  context,
                  'تأكيد أخير',
                  'اضغط "مسح نهائي" فقط إذا كنت متأكدًا تمامًا.',
                  ok: 'مسح نهائي',
                )) {
                  return;
                }
                if (!context.mounted) return;
                if (lock.enabled) {
                  final pin = await askPin(context, 'أدخل رمز القفل للتأكيد');
                  if (pin == null || !context.mounted) return;
                  if (!lock.verify(pin)) {
                    toast(context, 'الرمز غير صحيح', error: true);
                    return;
                  }
                }
                if (FileService.supported) {
                  await FileService.saveBackup(
                    store.exportJson(),
                    'before-wipe-${Store.backupStamp()}.json',
                  );
                }
                await store.wipe();
                if (context.mounted) {
                  toast(
                    context,
                    'تم مسح جميع البيانات (حُفظت نسخة أمان في مجلد الهاتف)',
                  );
                  Navigator.pop(context);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

/* ============================================================
   سلة المحذوفات (ملاحظة 8) — استرجاع / حذف نهائي / إفراغ
   ============================================================ */
class TrashScreen extends StatelessWidget {
  const TrashScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final total = store.trashCount;
    return Scaffold(
      appBar: AppBar(
        title: Text('سلة المحذوفات ($total)'),
        actions: [
          if (total > 0)
            TextButton.icon(
              onPressed: () async {
                if (await confirm(
                  context,
                  'إفراغ السلة',
                  'سيُحذف $total عنصرًا نهائيًا ولا يمكن استرجاعها.',
                  ok: 'إفراغ نهائي',
                )) {
                  await store.emptyTrash();
                  if (context.mounted) toast(context, 'تم إفراغ السلة');
                }
              },
              icon: Icon(Icons.delete_sweep_rounded, color: C.red, size: 20),
              label: Text(
                'إفراغ',
                style: TextStyle(color: C.red, fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
      body: total == 0
          ? EmptyState(
              icon: Icons.delete_outline_rounded,
              title: 'السلة فارغة',
              hint:
                  'ما تحذفه يبقى هنا ${Store.trashDays} يومًا ثم يُحذف تلقائيًا.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 30),
              children: [
                _hint(
                  'يمكنك استرجاع أي عنصر أو حذفه نهائيًا. العناصر تُحذف تلقائيًا بعد ${Store.trashDays} يومًا من نقلها هنا.',
                ),
                if (store.trashClients.isNotEmpty)
                  SectionTitle('العملاء (${store.trashClients.length})'),
                for (final c in store.trashClients)
                  _TrashRow(
                    icon: Ic.clients,
                    title: c.name,
                    sub: c.phone,
                    deletedAt: c.deletedAt,
                    onRestore: () => store.restoreClient(c.id),
                    onPurge: () => store.purgeClient(c.id),
                  ),
                if (store.trashDocs.isNotEmpty)
                  SectionTitle('الفواتير والعروض (${store.trashDocs.length})'),
                for (final d in store.trashDocs)
                  _TrashRow(
                    icon: d.isQuote ? Ic.edit : Ic.invoice,
                    title: '${d.isQuote ? 'عرض سعر' : 'فاتورة'} ${d.number}',
                    sub:
                        '${store.docClientName(d)} • ${fmtSAR(d.totals.total)}',
                    deletedAt: d.deletedAt,
                    onRestore: () => store.restoreDoc(d.id),
                    onPurge: () => store.purgeDoc(d.id),
                  ),
                if (store.trashClaims.isNotEmpty)
                  SectionTitle('خطابات المطالبة (${store.trashClaims.length})'),
                for (final c in store.trashClaims)
                  _TrashRow(
                    icon: Ic.statement,
                    title: 'خطاب ${c.number}',
                    sub: '${c.recipient} • ${fmtSAR(c.total)}',
                    deletedAt: c.deletedAt,
                    onRestore: () => store.restoreClaim(c.id),
                    onPurge: () => store.purgeClaim(c.id),
                  ),
                if (store.trashPayments.isNotEmpty)
                  SectionTitle('الدفعات (${store.trashPayments.length})'),
                for (final p in store.trashPayments)
                  _TrashRow(
                    icon: Ic.cash,
                    title: 'سند ${p.receiptNumber}',
                    sub: '${fmtSAR(p.amount)} • ${fmtDate(p.date)}',
                    deletedAt: p.deletedAt,
                    onRestore: () => store.restorePayment(p.id),
                    onPurge: () => store.purgePayment(p.id),
                  ),
              ],
            ),
    );
  }
}

class _TrashRow extends StatelessWidget {
  final String icon, title, sub, deletedAt;
  final Future<void> Function() onRestore, onPurge;
  const _TrashRow({
    required this.icon,
    required this.title,
    required this.sub,
    required this.deletedAt,
    required this.onRestore,
    required this.onPurge,
  });
  @override
  Widget build(BuildContext context) {
    final left = Store.daysLeft(deletedAt);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GoldCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            KIcon(icon, size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: C.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    sub,
                    style: TextStyle(color: C.text3, fontSize: 11.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    left <= 0 ? 'يُحذف اليوم' : 'يبقى $left يومًا',
                    style: TextStyle(
                      color: left <= 3 ? C.red : C.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'استرجاع',
              icon: Icon(Icons.restore_rounded, color: C.green),
              onPressed: () async {
                await onRestore();
                if (context.mounted) toast(context, 'تم الاسترجاع');
              },
            ),
            IconButton(
              tooltip: 'حذف نهائي',
              icon: Icon(Icons.delete_forever_rounded, color: C.red),
              onPressed: () async {
                if (await confirm(
                  context,
                  'حذف نهائي',
                  'سيُحذف «$title» نهائيًا ولا يمكن استرجاعه.',
                  ok: 'حذف نهائي',
                )) {
                  await onPurge();
                  if (context.mounted) toast(context, 'حُذف نهائيًا');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/* ============================================================
   حول التطبيق (ملاحظة 4)
   ============================================================ */
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _go(String url) async {
    final u = Uri.parse(url);
    try {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('حول التطبيق')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
      children: [
        Center(
          child: Image(
            image: AssetImage(
              C.isDark ? Brand.current.logoLight : Brand.current.logo,
            ),
            width: 130,
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            Brand.current.appName,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: C.text,
            ),
          ),
        ),
        Center(
          child: Text(
            'نظام الفواتير وكشوف الحساب وسندات القبض',
            style: TextStyle(color: C.text2),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            'الإصدار ${SettingsHub.version}',
            style: TextStyle(color: C.goldInk, fontWeight: FontWeight.w800),
          ),
        ),
        const SectionTitle('المطوّر'),
        GoldCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.person_rounded, color: C.gold),
                title: Text(
                  'معين العباسي',
                  style: TextStyle(fontWeight: FontWeight.w800, color: C.text),
                ),
                subtitle: Text(
                  'تصميم وتطوير',
                  style: TextStyle(color: C.text3, fontSize: 12),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.phone_rounded, color: C.gold),
                title: const Text(
                  '+967 770 941 666',
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  'اتصال / واتساب',
                  style: TextStyle(color: C.text3, fontSize: 12),
                ),
                trailing: Icon(Icons.chat_rounded, color: C.green, size: 20),
                onTap: () => _go('https://wa.me/967770941666'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.language_rounded, color: C.gold),
                title: const Text(
                  'alabbasi.uk',
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  'الموقع الإلكتروني',
                  style: TextStyle(color: C.text3, fontSize: 12),
                ),
                trailing: Icon(
                  Icons.open_in_new_rounded,
                  color: C.text3,
                  size: 18,
                ),
                onTap: () => _go('https://alabbasi.uk'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'بياناتك محفوظة على جهازك فقط. استخدم النسخة الاحتياطية لحمايتها.',
          textAlign: TextAlign.center,
          style: TextStyle(color: C.text3, fontSize: 12.5, height: 1.6),
        ),
      ],
    ),
  );
}

/* ============================================================
   النسخة الاحتياطية بنمط واتساب (ملاحظة 11ب)
   ============================================================ */
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  List<_BackupInfo>? _list;
  List<DriveBackup>? _drive;
  String? _driveErr;
  bool _driveBusy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _loadDrive(silent: true);
  }

  Future<void> _refresh() async {
    if (!FileService.supported) {
      setState(() => _list = const []);
      return;
    }
    final files = await FileService.list(FileKind.backup);
    final out = <_BackupInfo>[];
    for (final f in files) {
      BackupCheck? chk;
      try {
        chk = BackupService.verify(await FileService.readText(f.path));
      } catch (_) {}
      out.add(_BackupInfo(f, chk));
    }
    if (mounted) setState(() => _list = out);
  }

  Future<void> _loadDrive({bool silent = false}) async {
    if (kIsWeb) return;
    if (silent &&
        DriveService.account == null &&
        await DriveService.silent() == null) {
      if (mounted) setState(() => _drive = null);
      return;
    }
    setState(() {
      _driveBusy = true;
      _driveErr = null;
    });
    try {
      final l = await DriveService.list();
      if (mounted) setState(() => _drive = l);
    } catch (e) {
      if (mounted) {
        setState(() => _driveErr = '$e'.replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _driveBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final list = _list;
    final latest = list == null || list.isEmpty ? null : list.first;
    final acc = DriveService.account;
    return Scaffold(
      appBar: AppBar(title: const Text('النسخة الاحتياطية')),
      body: RefreshIndicator(
        onRefresh: () async {
          await _refresh();
          await _loadDrive(silent: true);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
          children: [
            // ── قاعدة البيانات ──
            GoldCard(
              child: Row(
                children: [
                  Icon(
                    store.integrityError == null
                        ? Icons.verified_rounded
                        : Icons.error_rounded,
                    color: store.integrityError == null ? C.green : C.red,
                    size: 30,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'قاعدة البيانات: ${store.database.engine}',
                          style: TextStyle(
                            color: C.text,
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                          ),
                        ),
                        Text(
                          store.integrityError == null
                              ? 'سليمة • كل حفظ يتم في معاملة واحدة ويُكتب على القرص فورًا'
                              : 'تحذير: ${store.integrityError} — استرجع آخر نسخة سليمة',
                          style: TextStyle(
                            color: store.integrityError == null
                                ? C.text3
                                : C.red,
                            fontSize: 11.5,
                          ),
                        ),
                        Text(
                          'بياناتك الآن: ${store.clients.length} عميل • ${store.docs.length} مستند • ${store.payments.length} دفعة • ${store.claims.length} مطالبة',
                          style: TextStyle(color: C.text3, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // ── نسخ الجهاز ──
            GoldCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const KIcon(Ic.share, size: 34),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'آخر نسخة على الجهاز',
                              style: TextStyle(color: C.text3, fontSize: 12),
                            ),
                            Text(
                              latest == null
                                  ? (store.lastAutoBackupAt == null
                                        ? 'لم تُحفظ نسخة بعد'
                                        : agoLabel(store.lastAutoBackupAt!))
                                  : _when(latest.file.modified),
                              style: TextStyle(
                                color: C.text,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () =>
                        runBusy(
                          context,
                          'جارٍ إنشاء النسخة والتحقق منها…',
                          () async {
                            if (!FileService.supported) {
                              await _shareNow(store);
                              return;
                            }
                            final p = await store.backupNow();
                            if (p == null) {
                              throw Exception(
                                'تعذّر إنشاء نسخة سليمة — تحقّق من مساحة التخزين',
                              );
                            }
                          },
                        ).then((ok) {
                          if (!ok || !mounted) return;
                          toast(
                            context,
                            'تم إنشاء النسخة والتحقق منها (SHA-256)',
                          );
                          _refresh();
                        }),
                    icon: const Icon(Icons.backup_rounded),
                    label: const Text('إنشاء نسخة احتياطية الآن'),
                  ),
                  if (FileService.supported)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'المجلد: ${FileService.basePath ?? '—'}/${FileKind.backup.folder}',
                        textDirection: TextDirection.ltr,
                        style: TextStyle(color: C.text3, fontSize: 10.5),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (FileService.supported)
              GoldCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.event_repeat_rounded),
                      title: Text(
                        'نسخة تلقائية كل 24 ساعة',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: C.text,
                        ),
                      ),
                      subtitle: Text(
                        'عند فتح التطبيق إن مرّ يوم على آخر نسخة • ملف واحد لكل يوم • يُحتفظ بآخر ${BackupService.keepDaily} يومًا • كل نسخة يُتحقق منها بعد كتابتها',
                        style: TextStyle(color: C.text3, fontSize: 12),
                      ),
                      value: store.autoBackupEnabled,
                      onChanged: store.setAutoBackup,
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.exit_to_app_rounded),
                      title: Text(
                        'نسخة عند الخروج من التطبيق',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: C.text,
                        ),
                      ),
                      subtitle: Text(
                        'عند إغلاق التطبيق أو تركه للخلفية بعد أي تعديل تُحدَّث نسخة اليوم فورًا (لا تتكاثر الملفات). مطفأة افتراضيًا.',
                        style: TextStyle(color: C.text3, fontSize: 12),
                      ),
                      value: store.backupOnExitEnabled,
                      onChanged: store.setBackupOnExit,
                    ),
                  ],
                ),
              ),

            // ── Google Drive ──
            if (!kIsWeb) ...[
              const SectionTitle('Google Drive (سحابي)'),
              GoldCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.cloud_rounded,
                          color: acc == null ? C.text3 : C.blue,
                          size: 30,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                acc == null ? 'غير متصل' : acc.email,
                                style: TextStyle(
                                  color: C.text,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                ),
                              ),
                              Text(
                                acc == null
                                    ? 'اربط حساب Google لحفظ نسخة مشفّرة النقل في مساحة التطبيق الخاصة في Drive'
                                    : 'آخر رفع: ${_lastDrive(store)}',
                                style: TextStyle(
                                  color: C.text3,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (acc == null)
                      FilledButton.icon(
                        onPressed: () async {
                          try {
                            final a = await DriveService.signIn();
                            if (a == null) return;
                            await store.setAccount(
                              name: a.displayName ?? '',
                              email: a.email,
                              photo: a.photoUrl ?? '',
                            );
                            await store.setKv('driveAuto', true);
                            if (mounted) setState(() {});
                            _loadDrive();
                          } catch (e) {
                            if (mounted) {
                              toast(
                                context,
                                'تعذّر الربط: ${'$e'.replaceFirst('Exception: ', '')}',
                                error: true,
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.link_rounded),
                        label: const Text('ربط حساب Google'),
                      )
                    else ...[
                      FilledButton.icon(
                        onPressed: _driveBusy
                            ? null
                            : () =>
                                  runBusy(
                                    context,
                                    'جارٍ الرفع إلى Google Drive والتحقق…',
                                    () async {
                                      await DriveService.upload(store);
                                    },
                                  ).then((ok) {
                                    if (!ok || !mounted) return;
                                    toast(
                                      context,
                                      'تم رفع النسخة إلى Google Drive والتحقق منها',
                                    );
                                    _loadDrive();
                                  }),
                        icon: const Icon(Icons.cloud_upload_rounded),
                        label: const Text('رفع نسخة الآن'),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'رفع تلقائي يومي',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: C.text,
                            fontSize: 13.5,
                          ),
                        ),
                        subtitle: Text(
                          'مرة يوميًا عند فتح التطبيق (يحتاج إنترنت) • يُحتفظ بآخر ${DriveService.keep} نسخة',
                          style: TextStyle(color: C.text3, fontSize: 11.5),
                        ),
                        value: store.kv('driveAuto') == true,
                        onChanged: (v) => store.setKv('driveAuto', v),
                      ),
                      TextButton(
                        onPressed: () async {
                          await DriveService.signOut();
                          await store.setKv('driveAuto', false);
                          if (mounted) setState(() => _drive = null);
                        },
                        child: Text(
                          'فصل الحساب',
                          style: TextStyle(color: C.red),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_driveErr != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: _hint(_driveErr!),
                ),
              if (acc != null && _drive != null) ...[
                SectionTitle(
                  'نسخ Drive (${_drive!.length})',
                  action: IconButton(
                    onPressed: _loadDrive,
                    icon: Icon(Icons.refresh_rounded, color: C.text3, size: 20),
                    tooltip: 'تحديث',
                  ),
                ),
                if (_drive!.isEmpty) _hint('لا نسخ في Drive بعد.'),
                for (final d in _drive!.take(10))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GoldCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      onTap: () => _restoreDrive(store, d),
                      child: Row(
                        children: [
                          Icon(
                            Icons.cloud_done_rounded,
                            color: C.blue,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d.modified == null
                                      ? d.name
                                      : _when(d.modified!.toLocal()),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                    color: C.text,
                                  ),
                                ),
                                Text(
                                  '${(d.size / 1024).toStringAsFixed(0)} KB • اضغط للاسترجاع',
                                  style: TextStyle(
                                    color: C.text3,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.restore_rounded, color: C.text3),
                        ],
                      ),
                    ),
                  ),
              ],
            ],

            // ── الاسترجاع ──
            const SectionTitle('الاسترجاع'),
            if (latest != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton.icon(
                  onPressed: () => _restore(store, latest),
                  icon: const Icon(Icons.restore_rounded),
                  label: Text(
                    'استرجاع آخر نسخة (${_when(latest.file.modified)})',
                  ),
                ),
              ),
            OutlinedButton.icon(
              onPressed: () => importBackupFromFile(context, store),
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('اختيار ملف نسخة من الجهاز'),
            ),

            // ── قائمة نسخ الجهاز ──
            if (FileService.supported) ...[
              SectionTitle(
                'نسخ الجهاز (${list?.length ?? 0})',
                action: IconButton(
                  onPressed: _refresh,
                  icon: Icon(Icons.refresh_rounded, color: C.text3, size: 20),
                  tooltip: 'تحديث',
                ),
              ),
              if (list == null)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (list.isEmpty)
                _hint('لا نسخ محفوظة بعد. اضغط «إنشاء نسخة احتياطية الآن».')
              else
                for (final b in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GoldCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      onTap: () => _restore(store, b),
                      child: Row(
                        children: [
                          Icon(
                            b.check?.ok == false
                                ? Icons.gpp_bad_rounded
                                : (b.check?.hasHash == true
                                      ? Icons.verified_rounded
                                      : Icons.save_rounded),
                            color: b.check?.ok == false
                                ? C.red
                                : (b.check?.hasHash == true ? C.green : C.gold),
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _when(b.file.modified),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                    color: C.text,
                                  ),
                                ),
                                Text(
                                  '${b.file.sizeLabel}${b.check == null ? '' : ' • ${b.check!.counts['clients']} عميل • ${b.check!.counts['docs']} مستند • ${b.check!.counts['payments']} دفعة'}${FileService.isAutoBackup(b.file.name) ? ' • يومية' : ''}',
                                  style: TextStyle(
                                    color: C.text3,
                                    fontSize: 11.5,
                                  ),
                                  maxLines: 2,
                                ),
                                Text(
                                  b.check?.message ?? 'تعذّرت القراءة',
                                  style: TextStyle(
                                    color: b.check?.ok == false
                                        ? C.red
                                        : C.muted,
                                    fontSize: 10.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (v) async {
                              switch (v) {
                                case 'restore':
                                  _restore(store, b);
                                case 'share':
                                  await FileService.share(
                                    b.file.path,
                                    subject: b.file.name,
                                  );
                                case 'delete':
                                  if (await confirm(
                                    context,
                                    'حذف النسخة',
                                    'سيُحذف الملف ${b.file.name} من الهاتف.',
                                  )) {
                                    await FileService.delete(b.file.path);
                                    _refresh();
                                  }
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'restore',
                                child: Text('استرجاع'),
                              ),
                              const PopupMenuItem(
                                value: 'share',
                                child: Text('مشاركة (واتساب / بريد)'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  'حذف',
                                  style: TextStyle(color: C.red),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
            ],

            const SectionTitle('مشاركة'),
            OutlinedButton.icon(
              onPressed: () => runBusy(
                context,
                'جارٍ تجهيز النسخة…',
                () => _shareNow(store),
              ),
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('إرسال نسخة الآن (واتساب / بريد)'),
            ),
          ],
        ),
      ),
    );
  }

  String _lastDrive(Store store) {
    final t = DateTime.tryParse('${store.kv('lastDriveBackup') ?? ''}');
    return t == null ? 'لم تُرفع نسخة بعد' : agoLabel(t);
  }

  Future<void> _shareNow(Store store) async {
    final json = store.exportJson();
    final name =
        '${Brand.current.backupPrefix}-backup-${Store.backupStamp()}.json';
    await Share.shareXFiles([
      XFile.fromData(
        utf8.encode(json),
        mimeType: 'application/json',
        name: name,
      ),
    ], subject: name);
  }

  Future<void> _restore(Store store, _BackupInfo b) async {
    try {
      final text = await FileService.readText(b.file.path);
      if (!mounted) return;
      await applyBackupImport(
        context,
        store,
        text,
        sourceName: '${_when(b.file.modified)} (${b.file.name})',
      );
    } catch (e) {
      if (mounted) toast(context, 'تعذّر قراءة النسخة: $e', error: true);
    }
  }

  Future<void> _restoreDrive(Store store, DriveBackup d) async {
    String? text;
    await runBusy(
      context,
      'جارٍ تنزيل النسخة من Drive…',
      () async => text = await DriveService.download(d.id),
    );
    if (text == null || !mounted) return;
    await applyBackupImport(
      context,
      store,
      text!,
      sourceName:
          'Google Drive — ${d.modified == null ? d.name : _when(d.modified!.toLocal())}',
    );
  }

  static String _when(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)}  ${two(t.hour)}:${two(t.minute)}';
  }
}

class _BackupInfo {
  final SavedFile file;
  final BackupCheck? check;
  const _BackupInfo(this.file, this.check);
}

/* ---------- دوال مساعدة مشتركة (القفل / الاسترجاع) ---------- */
/* ---------- القفل ---------- */
Future<void> enableLock(BuildContext context, LockService lock) async {
  final p1 = await askPin(
    context,
    'اختر رمز القفل',
    hint: 'من 4 إلى 6 أرقام. احفظه جيدًا — لا يمكن استرجاعه إن نسيته.',
  );
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
    if (context.mounted) {
      toast(context, 'تعذّر فتح منتقي الملفات: $e', error: true);
    }
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

Future<void> applyBackupImport(
  BuildContext context,
  Store store,
  String text, {
  String? sourceName,
}) async {
  if (text.trim().isEmpty) {
    toast(context, 'لا يوجد محتوى للاسترجاع.', error: true);
    return;
  }
  // تحقق مسبق (صيغة + بصمة SHA-256 + نسخة التطبيق الصحيحة) حتى لا نسأل عن ملف غير صالح
  final chk = BackupService.verify(text);
  if (!chk.ok) {
    toast(context, chk.message, error: true);
    return;
  }
  final nc = chk.counts['clients'] ?? 0;
  final nd = chk.counts['docs'] ?? 0;
  final np = chk.counts['payments'] ?? 0;
  final ncl = chk.counts['claims'] ?? 0;
  final go = await confirm(
    context,
    'استرجاع النسخة الاحتياطية',
    '${sourceName != null ? 'الملف: $sourceName\n\n' : ''}تحتوي النسخة على: $nc عميل • $nd مستند • $np دفعة${ncl > 0 ? ' • $ncl مطالبة' : ''}.\nالتحقق: ${chk.message}\n\nسيتم إضافتها إلى بياناتك الحالية (وتحديث السجلات المتطابقة) دون حذف أي شيء.',
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionTitle('الترويسة'),
          Field(
            'اسم المؤسسة',
            controller: c['name'],
            icon: Icons.business_outlined,
          ),
          Field(
            'الاسم بالإنجليزية',
            controller: c['nameEn'],
            icon: Icons.translate,
            direction: TextDirection.ltr,
          ),
          Row(
            children: [
              Expanded(
                child: Field(
                  'السجل التجاري (اختياري)',
                  hint: 'اتركه فارغًا إن لم يوجد',
                  controller: c['cr'],
                  type: TextInputType.number,
                  direction: TextDirection.ltr,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Field(
                  'الرقم الضريبي',
                  controller: c['vat'],
                  type: TextInputType.number,
                  direction: TextDirection.ltr,
                ),
              ),
            ],
          ),
          Field(
            'المدينة',
            controller: c['city'],
            icon: Icons.location_city_outlined,
          ),
          Field(
            'الهاتف',
            controller: c['phone'],
            icon: Icons.phone_outlined,
            type: TextInputType.phone,
            direction: TextDirection.ltr,
          ),
          Field(
            'الموقع الإلكتروني',
            controller: c['website'],
            icon: Icons.language,
            direction: TextDirection.ltr,
          ),
          Field(
            'البريد الإلكتروني',
            controller: c['email'],
            icon: Icons.mail_outline,
            direction: TextDirection.ltr,
          ),
          const SectionTitle('الحساب البنكي'),
          Field(
            'اسم البنك',
            controller: c['bankName'],
            icon: Icons.account_balance_outlined,
          ),
          Field(
            'رقم الحساب',
            controller: c['bankAccount'],
            type: TextInputType.number,
            direction: TextDirection.ltr,
          ),
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
        ],
      ),
    );
  }
}
