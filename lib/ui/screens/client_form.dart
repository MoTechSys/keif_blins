/// client_form.dart — نموذج العميل (بسيط: الاسم والهاتف يكفيان) | كيف الضيافة
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../core/money.dart';
import '../../core/store.dart';
import '../theme.dart';
import '../widgets.dart';

class ClientForm extends StatefulWidget {
  final Client? client;
  const ClientForm({super.key, this.client});
  @override
  State<ClientForm> createState() => _ClientFormState();
}

class _ClientFormState extends State<ClientForm> {
  final _f = GlobalKey<FormState>();
  late final Client c = widget.client == null ? Client() : Client.fromMap(widget.client!.toMap());
  late final name = TextEditingController(text: c.name);
  late final contact = TextEditingController(text: c.contact);
  late final phone = TextEditingController(text: c.phone);
  late final email = TextEditingController(text: c.email);
  late final vat = TextEditingController(text: c.vatNumber);
  late final cr = TextEditingController(text: c.crNumber);
  late final address = TextEditingController(text: c.address);
  late final notes = TextEditingController(text: c.notes);
  late final opening = TextEditingController(text: c.openingBalance == 0 ? '' : fmt(c.openingBalance, trimZeros: true));

  /// تُفتح التفاصيل الإضافية تلقائيًا إذا كان العميل يحوي بيانات فيها
  late bool _more = c.contact.isNotEmpty || c.email.isNotEmpty || c.vatNumber.isNotEmpty || c.crNumber.isNotEmpty || c.address.isNotEmpty || c.notes.isNotEmpty;
  late bool _openingOpen = c.openingBalance != 0;

  @override
  void dispose() {
    for (final t in [name, contact, phone, email, vat, cr, address, notes, opening]) {
      t.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.client == null;
    return Scaffold(
      appBar: AppBar(title: Text(isNew ? 'عميل جديد' : 'تعديل العميل')),
      body: Form(
        key: _f,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 110), children: [
          // الأساسيات — يكفي الاسم
          Row(children: [
            Plate.icon(Ic.clients, color: PlateColor.violet, size: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('البيانات الأساسية', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: C.text)),
                Text('يكفي الاسم للبدء، والباقي اختياري', style: TextStyle(color: C.text3, fontSize: 12)),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          Field('اسم العميل / الجهة *', controller: name, icon: Icons.business_outlined, validator: (v) => (v ?? '').trim().isEmpty ? 'مطلوب' : null),
          Field('رقم الجوال', controller: phone, icon: Icons.phone_outlined, type: TextInputType.phone, direction: TextDirection.ltr, hint: '05xxxxxxxx'),

          // تفاصيل إضافية (قابلة للطي)
          Expander(
            title: 'تفاصيل إضافية',
            hint: 'جهة الاتصال، البريد، الرقم الضريبي، العنوان',
            icon: Icons.tune_rounded,
            open: _more,
            onToggle: () => setState(() => _more = !_more),
            child: Column(children: [
              Field('جهة الاتصال (اسم الشخص)', controller: contact, icon: Icons.person_outline),
              Field('البريد الإلكتروني', controller: email, icon: Icons.mail_outline, type: TextInputType.emailAddress, direction: TextDirection.ltr),
              Row(children: [
                Expanded(child: Field('الرقم الضريبي', controller: vat, icon: Icons.numbers, type: TextInputType.number, direction: TextDirection.ltr)),
                const SizedBox(width: 10),
                Expanded(child: Field('السجل التجاري', controller: cr, icon: Icons.badge_outlined, type: TextInputType.number, direction: TextDirection.ltr)),
              ]),
              Field('العنوان', controller: address, icon: Icons.location_on_outlined),
              Field('ملاحظات داخلية', controller: notes, maxLines: 2, icon: Icons.notes_outlined),
            ]),
          ),

          // رصيد سابق (قابل للطي)
          Expander(
            title: 'رصيد سابق مستحق',
            hint: 'مبلغ كان مستحقًا على العميل قبل استخدام التطبيق',
            icon: Icons.account_balance_outlined,
            open: _openingOpen,
            onToggle: () => setState(() => _openingOpen = !_openingOpen),
            child: Field('الرصيد الافتتاحي (ر.س)', controller: opening, icon: Icons.account_balance_outlined, type: const TextInputType.numberWithOptions(decimal: true)),
          ),
        ]),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(color: C.bg2, border: Border(top: BorderSide(color: C.line))),
          child: FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check_rounded), label: Text(isNew ? 'إضافة العميل' : 'حفظ التعديلات')),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_f.currentState!.validate()) return;
    c
      ..name = name.text.trim()
      ..contact = contact.text.trim()
      ..phone = phone.text.trim()
      ..email = email.text.trim()
      ..vatNumber = vat.text.trim()
      ..crNumber = cr.text.trim()
      ..address = address.text.trim()
      ..notes = notes.text.trim()
      ..openingBalance = toHalalas(opening.text);
    await context.read<Store>().saveClient(c);
    if (mounted) {
      toast(context, widget.client == null ? 'تمت إضافة العميل' : 'تم حفظ العميل');
      Navigator.pop(context, c);
    }
  }
}
