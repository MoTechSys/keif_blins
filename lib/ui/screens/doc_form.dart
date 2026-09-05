/// doc_form.dart — نموذج الفاتورة / عرض السعر (بسيط ومرن) | كيف الضيافة
///
/// المبدأ: العميل + التاريخ + البنود يكفي لإصدار الفاتورة.
/// الضريبة والخصم والعربون تظهر فقط إذا فُعّلت من الإعدادات.
/// تفاصيل المناسبة (الموقع/الحضور/التواريخ) والملاحظات في أقسام قابلة للطي.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../core/money.dart';
import '../../core/store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'client_form.dart';
import 'doc_detail.dart';

class DocForm extends StatefulWidget {
  final DocKind kind;
  final String? clientId;
  final Invoice? doc;
  const DocForm({super.key, required this.kind, this.clientId, this.doc});
  @override
  State<DocForm> createState() => _DocFormState();
}

class _DocFormState extends State<DocForm> {
  final _f = GlobalKey<FormState>();
  late Invoice d;
  late final TextEditingController location, attendees, discount, deposit, notes, terms;
  final List<_ItemCtl> items = [];

  bool _eventOpen = false;
  bool _notesOpen = false;

  bool get isQ => d.isQuote;

  @override
  void initState() {
    super.initState();
    final store = context.read<Store>();
    final org = store.org;
    if (widget.doc != null) {
      d = widget.doc!.copy();
    } else {
      d = Invoice(kind: widget.kind, clientId: widget.clientId ?? (store.clients.isNotEmpty ? store.clients.first.id : ''));
      d.status = isQ ? QuoteStatus.draft.name : InvoiceStatus.issued.name;
      d.terms = '';
      // الضريبة الافتراضية من الإعدادات — إن لم تكن مفعّلة فالفاتورة بلا ضريبة
      d.vatRateBp = org.vatEnabled ? org.vatRateBp : 0;
      if (isQ) {
        final v = DateTime.now().add(const Duration(days: 15));
        d.validUntil = '${v.year}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')}';
      }
      d.items.add(LineItem());
    }
    location = TextEditingController(text: d.location);
    attendees = TextEditingController(text: d.attendees);
    discount = TextEditingController(text: d.discount == 0 ? '' : fmt(d.discount, trimZeros: true));
    deposit = TextEditingController(text: d.deposit == 0 ? '' : fmt(d.deposit, trimZeros: true));
    notes = TextEditingController(text: d.notes);
    terms = TextEditingController(text: d.terms);
    for (final li in d.items) {
      items.add(_ItemCtl(li));
    }
    _eventOpen = d.location.isNotEmpty || d.attendees.isNotEmpty || d.eventDate.isNotEmpty || d.eventDateTo.isNotEmpty;
    _notesOpen = d.notes.isNotEmpty || d.terms.isNotEmpty;
  }

  @override
  void dispose() {
    for (final t in [location, attendees, discount, deposit, notes, terms]) {
      t.dispose();
    }
    for (final it in items) {
      it.dispose();
    }
    super.dispose();
  }

  void _sync(Org org) {
    d.items = items.map((c) => c.toItem()).toList();
    d.discount = org.discountEnabled || d.discount > 0 ? toHalalasPositive(discount.text) : 0;
    d.deposit = (org.depositEnabled || d.deposit > 0) && !isQ ? toHalalasPositive(deposit.text) : (isQ ? 0 : d.deposit);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final org = store.org;
    _sync(org);
    final t = d.totals;
    final title = widget.doc == null ? (isQ ? 'عرض سعر جديد' : 'فاتورة جديدة') : 'تعديل ${d.number}';
    final showVat = org.vatEnabled || d.vatRateBp > 0;
    final showDiscount = org.discountEnabled || d.discount > 0;
    final showDeposit = !isQ && (org.depositEnabled || d.deposit > 0);
    final showMoneyExtras = showVat || showDiscount || showDeposit;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Form(
        key: _f,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 130), children: [
          // 1) العميل والتاريخ
          _StepTitle(1, 'العميل والتاريخ'),
          _clientPicker(store),
          Row(children: [
            Expanded(child: _dateField(isQ ? 'تاريخ العرض' : 'تاريخ الفاتورة', d.issueDate, (v) => d.issueDate = v)),
            if (isQ) const SizedBox(width: 10),
            if (isQ) Expanded(child: _dateField('ساري حتى', d.validUntil, (v) => d.validUntil = v, clearable: true)),
          ]),

          // 2) البنود
          _StepTitle(2, 'الخدمات / البنود'),
          for (var i = 0; i < items.length; i++) _itemCard(i),
          OutlinedButton.icon(
            onPressed: () => setState(() => items.add(_ItemCtl(LineItem(unitLabel: items.isNotEmpty ? items.last.unit : 'فترة')))),
            icon: const Icon(Icons.add_rounded),
            label: const Text('إضافة بند'),
          ),
          const SizedBox(height: 14),

          // 3) الضريبة/الخصم/العربون — فقط عند التفعيل من الإعدادات
          if (showMoneyExtras) ...[
            _StepTitle(3, 'الحسابات'),
            if (showVat) _vatRow(org),
            if (showDiscount || showDeposit)
              Row(children: [
                if (showDiscount)
                  Expanded(child: Field('الخصم (ر.س)', controller: discount, icon: Icons.discount_outlined, type: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}))),
                if (showDiscount && showDeposit) const SizedBox(width: 10),
                if (showDeposit)
                  Expanded(child: Field('العربون المدفوع (ر.س)', controller: deposit, icon: Icons.savings_outlined, type: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}))),
              ]),
          ],

          // تفاصيل المناسبة (اختياري)
          Expander(
            title: 'تفاصيل المناسبة',
            hint: 'الموقع، تاريخ المناسبة، عدد الحضور — اختياري',
            icon: Icons.celebration_outlined,
            open: _eventOpen,
            onToggle: () => setState(() => _eventOpen = !_eventOpen),
            child: Column(children: [
              Field('الموقع / القاعة', controller: location, icon: Icons.location_on_outlined),
              Row(children: [
                Expanded(child: _dateField('تاريخ المناسبة', d.eventDate, (v) => d.eventDate = v, clearable: true)),
                const SizedBox(width: 10),
                Expanded(child: _dateField('إلى تاريخ', d.eventDateTo, (v) => d.eventDateTo = v, clearable: true)),
              ]),
              Field('عدد الحضور', controller: attendees, icon: Icons.groups_outlined, type: TextInputType.number),
            ]),
          ),

          // ملاحظات وشروط (اختياري)
          Expander(
            title: 'ملاحظات وشروط',
            hint: 'تظهر في أسفل المستند — الافتراضي من الإعدادات',
            icon: Icons.notes_outlined,
            open: _notesOpen,
            onToggle: () => setState(() => _notesOpen = !_notesOpen),
            child: Column(children: [
              Field('ملاحظات تظهر في المستند', controller: notes, maxLines: 2, icon: Icons.sticky_note_2_outlined),
              Field(isQ ? 'شروط العرض (فارغ = الافتراضي)' : 'الشروط (فارغ = الافتراضي)', controller: terms, maxLines: 3, icon: Icons.gavel_outlined),
              _statusChips(),
            ]),
          ),
        ]),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(color: C.bg2, border: Border(top: BorderSide(color: C.line))),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(
                  [
                    'المجموع ${fmt(t.subtotal, trimZeros: true)}',
                    if (t.discount > 0) 'خصم ${fmt(t.discount, trimZeros: true)}',
                    if (t.vat > 0) 'ضريبة ${fmt(t.vat, trimZeros: true)}',
                  ].join(' • '),
                  style: TextStyle(color: C.text3, fontSize: 11.5),
                ),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Money(t.total, size: 22, color: C.goldInk),
                  if (d.deposit > 0) ...[
                    const SizedBox(width: 8),
                    Padding(padding: const EdgeInsets.only(bottom: 3), child: Text('المتبقي ${fmt((t.total - d.deposit).clamp(0, 1 << 62), trimZeros: true)}', style: TextStyle(color: C.warn, fontSize: 11.5, fontWeight: FontWeight.w700))),
                  ],
                ]),
              ]),
            ),
            FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check_rounded), label: Text(widget.doc == null ? (isQ ? 'إصدار العرض' : 'إصدار الفاتورة') : 'حفظ')),
          ]),
        ),
      ),
    );
  }

  /* ---------- العميل ---------- */
  Widget _clientPicker(Store store) {
    final has = store.clients.any((c) => c.id == d.clientId);
    final Client? c = has ? store.client(d.clientId) : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _pickClient(store),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c == null ? C.gold : C.line)),
          child: Row(children: [
            c == null ? Plate.material(Icons.person_add_alt_1_rounded, color: PlateColor.violet, size: 40) : Avatar(c.name, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c?.name ?? 'اختر العميل', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: C.text)),
                Text(c == null ? 'اضغط للاختيار أو إضافة عميل جديد' : (c.phone.isNotEmpty ? c.phone : 'اضغط للتغيير'), style: TextStyle(color: C.text3, fontSize: 12)),
              ]),
            ),
            Icon(Icons.unfold_more_rounded, color: C.text2),
          ]),
        ),
      ),
    );
  }

  Future<void> _pickClient(Store store) async {
    final res = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => _ClientSheet(selected: d.clientId),
    );
    if (!mounted || res == null) return;
    if (res == _newClient) {
      final c = await Navigator.push<Client>(context, MaterialPageRoute(builder: (_) => const ClientForm()));
      if (c != null && mounted) setState(() => d.clientId = c.id);
    } else if (res is String) {
      setState(() => d.clientId = res);
    }
  }

  /* ---------- الضريبة ---------- */
  Widget _vatRow(Org org) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Icon(Icons.percent_rounded, color: C.text3, size: 20),
          const SizedBox(width: 8),
          Text('ضريبة القيمة المضافة', style: TextStyle(fontWeight: FontWeight.w700, color: C.text)),
          const Spacer(),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 0, label: Text('0%')),
              ButtonSegment(value: 500, label: Text('5%')),
              ButtonSegment(value: 1500, label: Text('15%')),
            ],
            selected: {d.vatRateBp},
            onSelectionChanged: (s) => setState(() => d.vatRateBp = s.first),
          ),
        ]),
      );

  /* ---------- الحالة ---------- */
  Widget _statusChips() {
    if (!isQ) {
      return Wrap(spacing: 8, children: [
        for (final s in [InvoiceStatus.issued, InvoiceStatus.draft, InvoiceStatus.cancelled])
          ChoiceChip(label: Text(s == InvoiceStatus.issued ? 'صادرة' : statusLabel[s]!), selected: _baseStatus() == s, onSelected: (_) => setState(() => d.status = s.name), showCheckmark: false),
      ]);
    }
    return Wrap(spacing: 8, children: [
      for (final s in [QuoteStatus.draft, QuoteStatus.sent, QuoteStatus.accepted, QuoteStatus.rejected])
        ChoiceChip(label: Text(quoteStatusLabel[s]!), selected: d.status == s.name, onSelected: (_) => setState(() => d.status = s.name), showCheckmark: false),
    ]);
  }

  InvoiceStatus _baseStatus() {
    final s = d.invoiceStatus;
    if (s == InvoiceStatus.draft || s == InvoiceStatus.cancelled) return s;
    return InvoiceStatus.issued;
  }

  Widget _dateField(String label, String value, ValueChanged<String> set, {bool clearable = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final v = await pickDate(context, value);
            if (v != null) setState(() => set(v));
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: Icon(Icons.event_outlined, color: C.text3, size: 20),
              suffixIcon: clearable && value.isNotEmpty ? IconButton(icon: Icon(Icons.close, size: 18, color: C.text3), onPressed: () => setState(() => set(''))) : null,
            ),
            child: Text(value.isEmpty ? '—' : fmtDate(value), style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      );

  /* ---------- البند ---------- */
  Widget _itemCard(int i) {
    final c = items[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GoldCard(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
        child: Column(children: [
          Row(children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: C.goldGradient),
              child: Text('${i + 1}', style: TextStyle(color: C.onGold, fontWeight: FontWeight.w900, fontSize: 12)),
            ),
            const SizedBox(width: 8),
            Expanded(child: Money(c.toItem().total, size: 15, color: C.goldInk)),
            IconButton(
              icon: Icon(Icons.delete_outline, color: C.danger, size: 20),
              tooltip: 'حذف البند',
              onPressed: items.length == 1 ? null : () => setState(() => items.removeAt(i).dispose()),
            ),
          ]),
          Field('وصف الخدمة', hint: 'مثال: خدمة ضيافة قهوة وشاي', controller: c.desc, maxLines: 2, validator: (v) => (v ?? '').trim().isEmpty ? 'مطلوب' : null),
          Row(children: [
            Expanded(flex: 5, child: Field('السعر (ر.س)', controller: c.price, type: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}))),
            const SizedBox(width: 8),
            Expanded(flex: 3, child: Field('الكمية', controller: c.qty, type: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}))),
            const SizedBox(width: 8),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<String>(
                  initialValue: unitLabels.contains(c.unit) ? c.unit : unitLabels.first,
                  decoration: const InputDecoration(labelText: 'الوحدة', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 14)),
                  dropdownColor: C.bg2,
                  items: [for (final u in unitLabels) DropdownMenuItem(value: u, child: Text(u))],
                  onChanged: (v) => setState(() => c.unit = v!),
                ),
              ),
            ),
          ]),
          // مشتريات خارجية — مخفية خلف زر صغير حتى لا تزدحم البطاقة
          if (c.extOpen || c.external.text.isNotEmpty)
            Field('مشتريات خارجية (ر.س)', controller: c.external, type: const TextInputType.numberWithOptions(decimal: true), icon: Icons.shopping_bag_outlined, onChanged: (_) => setState(() {}))
          else
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6), minimumSize: const Size(0, 32)),
                onPressed: () => setState(() => c.extOpen = true),
                icon: Icon(Icons.add_shopping_cart_rounded, size: 16, color: C.text3),
                label: Text('إضافة مشتريات خارجية', style: TextStyle(color: C.text3, fontSize: 12)),
              ),
            ),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    final store = context.read<Store>();
    if (!store.clients.any((c) => c.id == d.clientId)) {
      toast(context, 'اختر العميل أولًا', error: true);
      return;
    }
    if (!_f.currentState!.validate()) {
      toast(context, 'يرجى إكمال الحقول المطلوبة', error: true);
      return;
    }
    _sync(store.org);
    d
      ..location = location.text.trim()
      ..attendees = attendees.text.trim()
      ..notes = notes.text.trim()
      ..terms = terms.text.trim();
    if (d.items.isEmpty || d.items.every((i) => i.desc.trim().isEmpty)) {
      toast(context, 'أضف بندًا واحدًا على الأقل', error: true);
      return;
    }
    final isNew = widget.doc == null;
    await store.saveDoc(d);
    if (!mounted) return;
    toast(context, isNew ? 'تم إنشاء ${d.number}' : 'تم حفظ التعديلات');
    if (isNew) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DocDetail(id: d.id)));
    } else {
      Navigator.pop(context);
    }
  }
}

const _newClient = Object();

/// ورقة اختيار العميل مع بحث + زر إضافة عميل جديد
class _ClientSheet extends StatefulWidget {
  final String selected;
  const _ClientSheet({required this.selected});
  @override
  State<_ClientSheet> createState() => _ClientSheetState();
}

class _ClientSheetState extends State<_ClientSheet> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final list = store.clients.where((c) => q.isEmpty || c.name.contains(q) || c.phone.contains(q)).toList()..sort((a, b) => a.name.compareTo(b.name));
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (_, ctl) => Column(children: [
        const SizedBox(height: 10),
        Container(width: 44, height: 4, decoration: BoxDecoration(color: C.line2, borderRadius: BorderRadius.circular(9))),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(children: [
            Text('اختر العميل', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: C.text)),
            const Spacer(),
            FilledButton.tonalIcon(onPressed: () => Navigator.pop(context, _newClient), icon: const Icon(Icons.person_add_alt_1_rounded, size: 18), label: const Text('عميل جديد')),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: TextField(
            autofocus: store.clients.length > 6,
            onChanged: (v) => setState(() => q = v.trim()),
            decoration: const InputDecoration(hintText: 'بحث بالاسم أو الجوال', prefixIcon: Icon(Icons.search_rounded, size: 20)),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? Center(child: Text(store.clients.isEmpty ? 'لا يوجد عملاء بعد — أضف أول عميل' : 'لا نتائج', style: TextStyle(color: C.text3)))
              : ListView.builder(
                  controller: ctl,
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final c = list[i];
                    final sel = c.id == widget.selected;
                    return ListTile(
                      leading: Avatar(c.name, size: 40),
                      title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: c.phone.isNotEmpty ? Text(c.phone, style: TextStyle(color: C.text3, fontSize: 12)) : null,
                      trailing: sel ? Icon(Icons.check_circle_rounded, color: C.gold) : null,
                      onTap: () => Navigator.pop(context, c.id),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

class _ItemCtl {
  final String id;
  final TextEditingController desc, price, qty, external;
  String unit;
  bool extOpen;
  _ItemCtl(LineItem li)
      : id = li.id,
        desc = TextEditingController(text: li.desc),
        price = TextEditingController(text: li.unitPrice == 0 ? '' : fmt(li.unitPrice, trimZeros: true)),
        qty = TextEditingController(text: fmtQty(li.qty)),
        external = TextEditingController(text: li.external == 0 ? '' : fmt(li.external, trimZeros: true)),
        unit = li.unitLabel,
        extOpen = li.external != 0;

  void dispose() {
    desc.dispose();
    price.dispose();
    qty.dispose();
    external.dispose();
  }

  LineItem toItem() => LineItem(
        id: id,
        desc: desc.text.trim(),
        unitPrice: toHalalasPositive(price.text),
        qty: toQty(qty.text) == 0 ? 1 : toQty(qty.text),
        unitLabel: unit,
        external: toHalalasPositive(external.text),
      );
}

class _StepTitle extends StatelessWidget {
  final int n;
  final String t;
  const _StepTitle(this.n, this.t);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 6, 0, 10),
        child: Row(children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: C.goldGradient),
            child: Text('$n', style: TextStyle(color: C.onGold, fontWeight: FontWeight.w900, fontSize: 12)),
          ),
          const SizedBox(width: 8),
          Text(t, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: C.text)),
        ]),
      );
}
