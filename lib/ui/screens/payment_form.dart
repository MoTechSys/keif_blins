/// payment_form.dart — تسجيل دفعة + سند قبض | كيف الضيافة
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/file_service.dart';
import '../../core/models.dart';
import '../../core/money.dart';
import '../../core/share_service.dart';
import '../../core/store.dart';
import '../../pdf/documents.dart';
import '../preview_screen.dart';
import '../theme.dart';
import '../widgets.dart';

class PaymentForm extends StatefulWidget {
  final String? clientId;
  final String? invoiceId;
  final int? suggested;
  final Payment? payment;
  const PaymentForm({super.key, this.clientId, this.invoiceId, this.suggested, this.payment});
  @override
  State<PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends State<PaymentForm> {
  final _f = GlobalKey<FormState>();
  late Payment p;
  late final TextEditingController amount, reference, notes;
  bool _more = false;

  @override
  void initState() {
    super.initState();
    final store = context.read<Store>();
    p = widget.payment != null
        ? Payment.fromMap(widget.payment!.toMap())
        : Payment(clientId: widget.clientId ?? (store.clients.isNotEmpty ? store.clients.first.id : ''), invoiceId: widget.invoiceId ?? '', amount: widget.suggested ?? 0);
    amount = TextEditingController(text: p.amount == 0 ? '' : fmt(p.amount, trimZeros: true));
    reference = TextEditingController(text: p.reference);
    notes = TextEditingController(text: p.notes);
    _more = p.reference.isNotEmpty || p.notes.isNotEmpty;
  }

  @override
  void dispose() {
    amount.dispose();
    reference.dispose();
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final openInvs = store.clientInvoices(p.clientId).where((i) => i.countsInLedger && (invoiceRemaining(i, store.payments) > 0 || i.id == p.invoiceId)).toList();
    final isEdit = widget.payment != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'تعديل الدفعة ${p.receiptNumber}' : 'تسجيل دفعة'),
        actions: [
          if (isEdit)
            IconButton(
              icon: Icon(Icons.delete_outline, color: C.red),
              onPressed: () async {
                if (await confirm(context, 'حذف الدفعة', 'سيُنقل السند ${p.receiptNumber} إلى سلة المحذوفات، ويمكن استرجاعه خلال ${Store.trashDays} يومًا.')) {
                  await store.deletePayment(p.id);
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
        ],
      ),
      body: Form(
        key: _f,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 110), children: [
          DropdownButtonFormField<String>(
            initialValue: store.clients.any((c) => c.id == p.clientId) ? p.clientId : (store.clients.isNotEmpty ? store.clients.first.id : null),
            decoration: InputDecoration(labelText: 'العميل', prefixIcon: Icon(Icons.business_outlined, color: C.muted, size: 20)),
            dropdownColor: C.bg2,
            items: [for (final c in store.clients) DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))],
            onChanged: isEdit ? null : (v) => setState(() {
                  p.clientId = v!;
                  p.invoiceId = '';
                }),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: openInvs.any((i) => i.id == p.invoiceId) ? p.invoiceId : '',
            decoration: InputDecoration(labelText: 'تخصيص لفاتورة', prefixIcon: Icon(Icons.receipt_long_outlined, color: C.muted, size: 20)),
            dropdownColor: C.bg2,
            items: [
              const DropdownMenuItem(value: '', child: Text('دفعة على الحساب (بدون فاتورة)')),
              for (final i in openInvs)
                DropdownMenuItem(value: i.id, child: Text('${i.number} — متبقي ${fmtSARSmart(invoiceRemaining(i, store.payments.where((x) => x.id != p.id)))}', overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() {
              p.invoiceId = v!;
              if (v.isNotEmpty && amount.text.isEmpty) {
                final inv = store.doc(v)!;
                amount.text = fmt(invoiceRemaining(inv, store.payments), trimZeros: true);
              }
            }),
          ),
          const SizedBox(height: 12),
          Field('المبلغ (ر.س) *', controller: amount, icon: Icons.payments_outlined, type: const TextInputType.numberWithOptions(decimal: true), validator: (v) => toHalalasPositive(v) <= 0 ? 'أدخل مبلغًا صحيحًا' : null),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final v = await pickDate(context, p.date);
                if (v != null) setState(() => p.date = v);
              },
              child: InputDecorator(
                decoration: InputDecoration(labelText: 'تاريخ الدفع', prefixIcon: Icon(Icons.event_outlined, color: C.muted, size: 20)),
                child: Text(fmtDate(p.date), style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          DropdownButtonFormField<String>(
            initialValue: payMethods.contains(p.method) ? p.method : payMethods.first,
            decoration: InputDecoration(labelText: 'طريقة الدفع', prefixIcon: Icon(Icons.credit_card_outlined, color: C.muted, size: 20)),
            dropdownColor: C.bg2,
            items: [for (final m in payMethods) DropdownMenuItem(value: m, child: Text(m))],
            onChanged: (v) => setState(() => p.method = v!),
          ),
          const SizedBox(height: 12),
          Expander(
            title: 'تفاصيل إضافية',
            hint: 'رقم العملية البنكية، ملاحظات — اختياري',
            icon: Icons.tag_rounded,
            open: _more,
            onToggle: () => setState(() => _more = !_more),
            child: Column(children: [
              Field('رقم العملية / المرجع', controller: reference, icon: Icons.tag, direction: TextDirection.ltr),
              Field('ملاحظات', controller: notes, icon: Icons.notes_outlined, maxLines: 2),
            ]),
          ),
        ]),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(color: C.bg2, border: Border(top: BorderSide(color: C.line))),
          child: Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () => _save(preview: false), icon: const Icon(Icons.check_rounded, size: 18), label: const Text('حفظ فقط'))),
            const SizedBox(width: 10),
            Expanded(flex: 3, child: FilledButton.icon(onPressed: () => _save(preview: true), icon: const Icon(Icons.receipt_rounded, size: 18), label: const Text('حفظ وإصدار سند قبض'))),
          ]),
        ),
      ),
    );
  }

  Future<void> _save({required bool preview}) async {
    final store0 = context.read<Store>();
    if (!store0.clients.any((c) => c.id == p.clientId)) {
      toast(context, 'اختر العميل أولًا', error: true);
      return;
    }
    if (!_f.currentState!.validate()) return;
    p
      ..amount = toHalalasPositive(amount.text)
      ..reference = reference.text.trim()
      ..notes = notes.text.trim();
    final store = context.read<Store>();
    await store.savePayment(p);
    if (!mounted) return;
    toast(context, 'تم حفظ الدفعة ${p.receiptNumber}');
    if (preview) {
      final c = store.client(p.clientId)!;
      final inv = store.doc(p.invoiceId);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PreviewScreen(
            title: 'سند قبض ${p.receiptNumber}',
            fileName: store.receiptFileName(p),
            message: ShareService.receiptMessage(p, c, store.org),
            build: () async => (await DocPdf.create(store.org)).receipt(p, c, inv),
            kind: FileKind.receipt,
            year: FileService.yearOf(p.date),
          ),
        ),
      );
    } else {
      Navigator.pop(context);
    }
  }
}
