/// doc_form.dart — نموذج الفاتورة / عرض السعر | كيف الضيافة
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../core/money.dart';
import '../../core/store.dart';
import '../theme.dart';
import '../widgets.dart';
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

  bool get isQ => d.isQuote;

  @override
  void initState() {
    super.initState();
    final store = context.read<Store>();
    if (widget.doc != null) {
      d = widget.doc!.copy();
    } else {
      d = Invoice(kind: widget.kind, clientId: widget.clientId ?? store.clients.first.id);
      d.status = isQ ? QuoteStatus.draft.name : InvoiceStatus.issued.name;
      d.terms = '';
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

  void _sync() {
    d.items = items.map((c) => c.toItem()).toList();
    d.discount = toHalalasPositive(discount.text);
    d.deposit = toHalalasPositive(deposit.text);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    _sync();
    final t = d.totals;
    final title = widget.doc == null ? (isQ ? 'عرض سعر جديد' : 'فاتورة جديدة') : 'تعديل ${d.number}';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Form(
        key: _f,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 120), children: [
          // العميل
          DropdownButtonFormField<String>(
            initialValue: store.clients.any((c) => c.id == d.clientId) ? d.clientId : store.clients.first.id,
            decoration: const InputDecoration(labelText: 'العميل', prefixIcon: Icon(Icons.business_outlined, color: C.muted, size: 20)),
            dropdownColor: C.bg2,
            items: [for (final c in store.clients) DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))],
            onChanged: (v) => setState(() => d.clientId = v!),
          ),
          const SizedBox(height: 12),
          // التواريخ
          Row(children: [
            Expanded(child: _dateField(isQ ? 'تاريخ العرض' : 'تاريخ الإصدار', d.issueDate, (v) => d.issueDate = v)),
            const SizedBox(width: 10),
            Expanded(
              child: isQ
                  ? _dateField('ساري حتى', d.validUntil, (v) => d.validUntil = v, clearable: true)
                  : _dateField('تاريخ المناسبة', d.eventDate, (v) => d.eventDate = v, clearable: true),
            ),
          ]),
          Row(children: [
            Expanded(child: isQ ? _dateField('تاريخ المناسبة', d.eventDate, (v) => d.eventDate = v, clearable: true) : _dateField('إلى تاريخ (اختياري)', d.eventDateTo, (v) => d.eventDateTo = v, clearable: true)),
            const SizedBox(width: 10),
            Expanded(child: isQ ? _dateField('إلى تاريخ (اختياري)', d.eventDateTo, (v) => d.eventDateTo = v, clearable: true) : Field('عدد الحضور', controller: attendees, icon: Icons.groups_outlined, type: TextInputType.number)),
          ]),
          if (isQ) Field('عدد الحضور', controller: attendees, icon: Icons.groups_outlined, type: TextInputType.number),
          Field('الموقع / القاعة', controller: location, icon: Icons.location_on_outlined),

          // البنود
          const SectionTitle('البنود'),
          for (var i = 0; i < items.length; i++) _itemCard(i),
          OutlinedButton.icon(
            onPressed: () => setState(() => items.add(_ItemCtl(LineItem(unitLabel: items.isNotEmpty ? items.last.unit : 'فترة')))),
            icon: const Icon(Icons.add),
            label: const Text('إضافة بند'),
          ),

          // الضريبة والخصم والعربون
          const SectionTitle('الضريبة والخصم'),
          Row(children: [
            const Text('ضريبة القيمة المضافة', style: TextStyle(fontWeight: FontWeight.w700)),
            const Spacer(),
            SegmentedButton<int>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: C.gold,
                selectedForegroundColor: C.bg,
                foregroundColor: C.text,
                side: const BorderSide(color: C.line),
                textStyle: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w800),
              ),
              segments: const [
                ButtonSegment(value: 0, label: Text('0%')),
                ButtonSegment(value: 500, label: Text('5%')),
                ButtonSegment(value: 1500, label: Text('15%')),
              ],
              selected: {d.vatRateBp},
              onSelectionChanged: (s) => setState(() => d.vatRateBp = s.first),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Field('الخصم (ر.س)', controller: discount, icon: Icons.discount_outlined, type: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}))),
            if (!isQ) const SizedBox(width: 10),
            if (!isQ) Expanded(child: Field('العربون المدفوع (ر.س)', controller: deposit, icon: Icons.savings_outlined, type: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}))),
          ]),

          if (!isQ) ...[
            const SectionTitle('الحالة'),
            Wrap(spacing: 8, children: [
              for (final s in [InvoiceStatus.issued, InvoiceStatus.draft, InvoiceStatus.cancelled])
                ChoiceChip(label: Text(s == InvoiceStatus.issued ? 'صادرة' : statusLabel[s]!), selected: _baseStatus() == s, onSelected: (_) => setState(() => d.status = s.name), showCheckmark: false),
            ]),
          ] else ...[
            const SectionTitle('حالة العرض'),
            Wrap(spacing: 8, children: [
              for (final s in [QuoteStatus.draft, QuoteStatus.sent, QuoteStatus.accepted, QuoteStatus.rejected])
                ChoiceChip(label: Text(quoteStatusLabel[s]!), selected: d.status == s.name, onSelected: (_) => setState(() => d.status = s.name), showCheckmark: false),
            ]),
          ],

          const SectionTitle('ملاحظات وشروط'),
          Field('ملاحظات تظهر في المستند', controller: notes, maxLines: 2, icon: Icons.notes_outlined),
          Field(isQ ? 'شروط العرض (فارغ = الافتراضي من الإعدادات)' : 'الشروط (فارغ = الافتراضي من الإعدادات)', controller: terms, maxLines: 3, icon: Icons.gavel_outlined),
        ]),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(color: C.bg2, border: Border(top: BorderSide(color: C.line))),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('المجموع ${fmt(t.subtotal, trimZeros: true)}${t.discount > 0 ? ' − خصم ${fmt(t.discount, trimZeros: true)}' : ''}${t.vat > 0 ? ' + ضريبة ${fmt(t.vat, trimZeros: true)}' : ''}',
                    style: const TextStyle(color: C.muted, fontSize: 11.5)),
                Money(t.total, size: 22, color: C.goldLight),
              ]),
            ),
            FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_rounded), label: const Text('حفظ')),
          ]),
        ),
      ),
    );
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
              prefixIcon: const Icon(Icons.event_outlined, color: C.muted, size: 20),
              suffixIcon: clearable && value.isNotEmpty ? IconButton(icon: const Icon(Icons.close, size: 18, color: C.muted), onPressed: () => setState(() => set(''))) : null,
            ),
            child: Text(value.isEmpty ? '—' : fmtDate(value), style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      );

  Widget _itemCard(int i) {
    final c = items[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GoldCard(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: Column(children: [
          Row(children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [C.goldDark, C.gold, C.goldLight])),
              child: Text('${i + 1}', style: const TextStyle(color: C.bg, fontWeight: FontWeight.w900, fontSize: 12)),
            ),
            const SizedBox(width: 8),
            Expanded(child: Money(c.toItem().total, size: 15, color: C.goldLight)),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: C.red, size: 20),
              onPressed: items.length == 1 ? null : () => setState(() => items.removeAt(i).dispose()),
            ),
          ]),
          Field('وصف الخدمة (السطر الأول عنوان، والباقي تفاصيل)', controller: c.desc, maxLines: 3, validator: (v) => (v ?? '').trim().isEmpty ? 'مطلوب' : null),
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
          Field('مشتريات خارجية (ر.س) — اختياري', controller: c.external, type: const TextInputType.numberWithOptions(decimal: true), icon: Icons.shopping_bag_outlined, onChanged: (_) => setState(() {})),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    if (!_f.currentState!.validate()) {
      toast(context, 'يرجى إكمال الحقول المطلوبة', error: true);
      return;
    }
    _sync();
    d
      ..location = location.text.trim()
      ..attendees = attendees.text.trim()
      ..notes = notes.text.trim()
      ..terms = terms.text.trim();
    if (d.items.isEmpty || d.items.every((i) => i.desc.trim().isEmpty)) {
      toast(context, 'أضف بندًا واحدًا على الأقل', error: true);
      return;
    }
    final store = context.read<Store>();
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

class _ItemCtl {
  final String id;
  final TextEditingController desc, price, qty, external;
  String unit;
  _ItemCtl(LineItem li)
      : id = li.id,
        desc = TextEditingController(text: li.desc),
        price = TextEditingController(text: li.unitPrice == 0 ? '' : fmt(li.unitPrice, trimZeros: true)),
        qty = TextEditingController(text: fmtQty(li.qty)),
        external = TextEditingController(text: li.external == 0 ? '' : fmt(li.external, trimZeros: true)),
        unit = li.unitLabel;

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
