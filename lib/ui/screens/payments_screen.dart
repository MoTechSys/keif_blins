/// payments_screen.dart — الدفعات وسندات القبض (كل العملاء) | كيف الضيافة
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/file_service.dart';
import '../../core/models.dart';
import '../../core/share_service.dart';
import '../../core/store.dart';
import '../../pdf/documents.dart';
import '../preview_screen.dart';
import '../theme.dart';
import '../widgets.dart';
import 'payment_form.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});
  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  String _q = '';
  String _method = 'all';

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final list = store.payments.where((p) {
      if (_method != 'all' && p.method != _method) return false;
      if (_q.isEmpty) return true;
      final cn = store.client(p.clientId)?.name ?? '';
      return p.receiptNumber.contains(_q) || cn.contains(_q) || p.reference.contains(_q) || p.date.contains(_q);
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final total = list.fold<int>(0, (s, p) => s + p.amount);

    return Scaffold(
      appBar: AppBar(title: Text('الدفعات وسندات القبض (${store.payments.length})')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (store.clients.isEmpty) {
            toast(context, 'أضف عميلًا أولًا', error: true);
            return;
          }
          Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentForm()));
        },
        backgroundColor: C.gold,
        foregroundColor: C.bg,
        icon: const Icon(Icons.add),
        label: const Text('تسجيل دفعة', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: TextField(
            onChanged: (v) => setState(() => _q = v.trim()),
            decoration: InputDecoration(hintText: 'بحث برقم السند أو العميل أو المرجع…', prefixIcon: Icon(Icons.search, color: C.muted), isDense: true),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            children: [
              _chip('all', 'الكل'),
              for (final m in payMethods) _chip(m, m),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 2, 18, 6),
          child: Row(children: [
            Text('${list.length} دفعة', style: TextStyle(color: C.muted, fontSize: 12.5)),
            const Spacer(),
            Text('المجموع: ', style: TextStyle(color: C.muted, fontSize: 12.5)),
            Money(total, size: 14, color: C.green),
          ]),
        ),
        Expanded(
          child: list.isEmpty
              ? const EmptyState(icon: Icons.payments_outlined, title: 'لا دفعات', hint: 'سجّل دفعة من زر «تسجيل دفعة» أو من صفحة العميل.')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 90),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final p = list[i];
                    final c = store.client(p.clientId);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GoldCard(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentForm(clientId: p.clientId, payment: p))),
                        child: Row(children: [
                          Plate.icon(Ic.cash, color: PlateColor.green, size: 36),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(c?.name ?? 'عميل محذوف', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text('${p.receiptNumber} • ${p.method} • ${fmtDate(p.date)}', style: TextStyle(color: C.muted, fontSize: 12)),
                            ]),
                          ),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Money(p.amount, size: 14, color: C.green),
                            const SizedBox(height: 2),
                            InkWell(
                              onTap: c == null ? null : () => _receipt(context, store, p, c),
                              child: Row(children: [
                                Icon(Icons.picture_as_pdf_rounded, size: 14, color: C.gold),
                                const SizedBox(width: 3),
                                Text('السند', style: TextStyle(color: C.gold, fontSize: 11.5, fontWeight: FontWeight.w800)),
                              ]),
                            ),
                          ]),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  void _receipt(BuildContext context, Store store, Payment p, Client c) {
    final inv = store.doc(p.invoiceId);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PreviewScreen(
          title: 'سند قبض ${p.receiptNumber}',
          fileName: store.receiptFileName(p),
          message: ShareService.receiptMessage(p, c, store.org),
          build: () async => (await DocPdf.create(store.org)).receipt(p, c, inv, payments: store.payments),
          kind: FileKind.receipt,
          year: FileService.yearOf(p.date),
        ),
      ),
    );
  }

  Widget _chip(String v, String label) => Padding(
        padding: const EdgeInsets.only(left: 6),
        child: ChoiceChip(
          label: Text(label, style: const TextStyle(fontSize: 12)),
          selected: _method == v,
          selectedColor: C.gold.withValues(alpha: 0.25),
          onSelected: (_) => setState(() => _method = v),
        ),
      );
}
