/// client_form.dart — نموذج العميل | كيف الضيافة
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../core/money.dart';
import '../../core/store.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.client == null ? 'عميل جديد' : 'تعديل العميل')),
      body: Form(
        key: _f,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Field('اسم العميل / الجهة *', controller: name, icon: Icons.business_outlined, validator: (v) => (v ?? '').trim().isEmpty ? 'مطلوب' : null),
          Field('جهة الاتصال', controller: contact, icon: Icons.person_outline),
          Field('الهاتف', controller: phone, icon: Icons.phone_outlined, type: TextInputType.phone, direction: TextDirection.ltr),
          Field('البريد الإلكتروني', controller: email, icon: Icons.mail_outline, type: TextInputType.emailAddress, direction: TextDirection.ltr),
          Field('الرقم الضريبي', controller: vat, icon: Icons.numbers, type: TextInputType.number, direction: TextDirection.ltr),
          Field('السجل التجاري', controller: cr, icon: Icons.badge_outlined, type: TextInputType.number, direction: TextDirection.ltr),
          Field('العنوان', controller: address, icon: Icons.location_on_outlined),
          Field('رصيد افتتاحي مستحق (ر.س)', controller: opening, icon: Icons.account_balance_outlined, type: const TextInputType.numberWithOptions(decimal: true), hint: 'مبلغ مستحق قبل استخدام التطبيق'),
          Field('ملاحظات', controller: notes, maxLines: 3, icon: Icons.notes_outlined),
          const SizedBox(height: 8),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_rounded), label: const Text('حفظ')),
        ]),
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
      toast(context, 'تم حفظ العميل');
      Navigator.pop(context, c);
    }
  }
}
