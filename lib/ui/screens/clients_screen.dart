/// clients_screen.dart — العملاء + تفاصيل العميل | كيف الضيافة
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
import 'doc_form.dart';
import 'payment_form.dart';
import 'statements_screen.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});
  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final list = store.clients.where((c) => _q.isEmpty || c.name.contains(_q) || c.phone.contains(_q) || c.contact.contains(_q)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      appBar: AppBar(title: Text('العملاء (${store.clients.length})')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientForm())),
        backgroundColor: C.gold,
        foregroundColor: C.bg,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('عميل جديد', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
          child: TextField(
            onChanged: (v) => setState(() => _q = v.trim()),
            decoration: const InputDecoration(hintText: 'بحث بالاسم أو الهاتف…', prefixIcon: Icon(Icons.search, color: C.muted)),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const EmptyState(icon: Icons.people_outline, title: 'لا يوجد عملاء', hint: 'أضف أول عميل للبدء في إصدار الفواتير')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 90),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final c = list[i];
                    final s = store.summary(c);
                    return GoldCard(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ClientDetail(id: c.id))),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(children: [
                        _Avatar(c.name),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(c.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                            const SizedBox(height: 3),
                            Text(
                              [if (c.phone.isNotEmpty) c.phone, '${s.invoiceCount} فاتورة'].join(' • '),
                              style: const TextStyle(color: C.muted, fontSize: 12),
                            ),
                          ]),
                        ),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(s.outstanding > 0 ? 'مستحق' : 'مسدَّد', style: TextStyle(color: s.outstanding > 0 ? C.red : C.green, fontSize: 11, fontWeight: FontWeight.w700)),
                          Money(s.outstanding, size: 15, color: s.outstanding > 0 ? C.text : C.green),
                        ]),
                      ]),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar(this.name);
  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [C.goldDark, C.gold, C.goldLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Text(name.isEmpty ? '؟' : name.trim()[0], style: const TextStyle(color: C.bg, fontWeight: FontWeight.w900, fontSize: 18)),
      );
}

/* ============================================================
   تفاصيل العميل
   ============================================================ */
class ClientDetail extends StatelessWidget {
  final String id;
  const ClientDetail({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final c = store.client(id);
    if (c == null) return const Scaffold(body: Center(child: Text('العميل غير موجود')));
    final s = store.summary(c);
    final invs = store.clientInvoices(c.id);
    final quotes = store.quotes.where((q) => q.clientId == c.id).toList();
    final pays = store.clientPayments(c.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(c.name),
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ClientForm(client: c)))),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'del' && await confirm(context, 'حذف العميل', 'سيتم حذف العميل وجميع فواتيره ودفعاته نهائيًا.')) {
                await store.deleteClient(c.id);
                if (context.mounted) Navigator.pop(context);
              }
            },
            itemBuilder: (_) => const [PopupMenuItem(value: 'del', child: Text('حذف العميل', style: TextStyle(color: C.red)))],
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(14, 4, 14, 30), children: [
        GoldCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('الرصيد المستحق', style: TextStyle(color: C.goldLight, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Money(s.outstanding, size: 30, color: s.outstanding > 0 ? C.text : C.green),
            const Divider(height: 22),
            Row(children: [
              _Kv('رصيد افتتاحي', fmtSARSmart(s.opening)),
              _Kv('مفوتر', fmtSARSmart(s.billed)),
              _Kv('مدفوع', fmtSARSmart(s.paid), color: C.green),
            ]),
            if (c.contact.isNotEmpty || c.phone.isNotEmpty || c.vatNumber.isNotEmpty || c.address.isNotEmpty) const Divider(height: 22),
            if (c.contact.isNotEmpty) _info(Icons.person_outline, c.contact),
            if (c.phone.isNotEmpty) _info(Icons.phone_outlined, c.phone),
            if (c.email.isNotEmpty) _info(Icons.mail_outline, c.email),
            if (c.vatNumber.isNotEmpty) _info(Icons.numbers, 'الرقم الضريبي: ${c.vatNumber}'),
            if (c.address.isNotEmpty) _info(Icons.location_on_outlined, c.address),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: FilledButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DocForm(kind: DocKind.invoice, clientId: c.id))), icon: const Icon(Icons.receipt_long_rounded, size: 18), label: const Text('فاتورة'))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DocForm(kind: DocKind.quotation, clientId: c.id))), icon: const Icon(Icons.request_quote_rounded, size: 18), label: const Text('عرض سعر'))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentForm(clientId: c.id))), icon: const Icon(Icons.payments_rounded, size: 18), label: const Text('دفعة'))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(onPressed: () => openStatement(context, c), icon: const Icon(Icons.account_balance_wallet_rounded, size: 18), label: const Text('كشف حساب'))),
        ]),

        if (invs.isNotEmpty) SectionTitle('الفواتير (${invs.length})'),
        for (final i in invs) _docRow(context, i, store),
        if (quotes.isNotEmpty) SectionTitle('عروض الأسعار (${quotes.length})'),
        for (final q in quotes) _docRow(context, q, store),
        if (pays.isNotEmpty) SectionTitle('الدفعات (${pays.length})'),
        for (final p in pays)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GoldCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentForm(clientId: c.id, payment: p))),
              child: Row(children: [
                const Icon(Icons.payments_outlined, color: C.green, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${p.receiptNumber} • ${p.method}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    Text(
                      '${fmtDate(p.date)}${p.invoiceId.isNotEmpty ? ' • فاتورة ${store.doc(p.invoiceId)?.number ?? ''}' : ' • على الحساب'}',
                      style: const TextStyle(color: C.muted, fontSize: 12),
                    ),
                  ]),
                ),
                Money(p.amount, size: 14, color: C.green),
              ]),
            ),
          ),
      ]),
    );
  }

  Widget _info(IconData i, String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [Icon(i, size: 17, color: C.gold), const SizedBox(width: 8), Expanded(child: Text(t, style: const TextStyle(color: C.text, fontSize: 13.5)))]),
      );

  Widget _docRow(BuildContext context, Invoice d, Store store) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GoldCard(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DocDetail(id: d.id))),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Icon(d.isQuote ? Icons.request_quote_outlined : Icons.receipt_long_outlined, color: C.gold, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d.number, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                Text(
                  '${fmtDate(d.issueDate)}${d.location.isNotEmpty ? ' • ${d.location}' : ''}',
                  style: const TextStyle(color: C.muted, fontSize: 12),
                ),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Money(d.totals.total, size: 14),
              const SizedBox(height: 3),
              d.isQuote ? StatusChip.quote(d.quoteStatus) : StatusChip.invoice(computeStatus(d, store.payments)),
            ]),
          ]),
        ),
      );
}

class _Kv extends StatelessWidget {
  final String k, v;
  final Color color;
  const _Kv(this.k, this.v, {this.color = C.text});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k, style: const TextStyle(color: C.muted, fontSize: 11.5)),
          const SizedBox(height: 2),
          Text(v, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13.5)),
        ]),
      );
}
