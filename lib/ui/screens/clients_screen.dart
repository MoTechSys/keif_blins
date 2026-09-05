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
            decoration: InputDecoration(hintText: 'بحث بالاسم أو الهاتف…', prefixIcon: Icon(Icons.search, color: C.muted)),
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
                        Avatar(c.name),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(c.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                            const SizedBox(height: 3),
                            Text(
                              [if (c.phone.isNotEmpty) c.phone, '${s.invoiceCount} فاتورة'].join(' • '),
                              style: TextStyle(color: C.muted, fontSize: 12),
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

/* ============================================================
   تفاصيل العميل — مرتّبة ومقسّمة (ملاحظتا 8 و13)
   ============================================================ */
class ClientDetail extends StatelessWidget {
  final String id;
  const ClientDetail({super.key, required this.id});

  /// أقصى عدد يظهر في كل قسم قبل زر «عرض الكل»
  static const int _peek = 4;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final c = store.client(id);
    if (c == null) return const Scaffold(body: Center(child: Text('العميل غير موجود')));
    final s = store.summary(c);
    final invs = store.clientInvoices(c.id);
    final quotes = store.clientQuotes(c.id);
    final pays = store.clientPayments(c.id);
    final credit = s.outstanding < 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(c.name),
        actions: [
          IconButton(tooltip: 'تعديل', icon: const Icon(Icons.edit_outlined), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ClientForm(client: c)))),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'del' &&
                  await confirm(context, 'حذف العميل', 'سيُنقل العميل وجميع فواتيره وعروضه ودفعاته إلى سلة المحذوفات، ويمكن استرجاعها خلال ${Store.trashDays} يومًا.')) {
                await store.deleteClient(c.id);
                if (context.mounted) Navigator.pop(context);
              }
            },
            itemBuilder: (_) => [PopupMenuItem(value: 'del', child: Text('نقل إلى سلة المحذوفات', style: TextStyle(color: C.red)))],
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(14, 4, 14, 30), children: [
        // ── بطاقة الرصيد ──
        GoldCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Avatar(c.name, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(credit ? 'رصيد دائن للعميل' : (s.outstanding == 0 ? 'الحساب مسدَّد' : 'الرصيد المستحق'),
                      style: TextStyle(color: credit ? C.green : C.goldLight, fontWeight: FontWeight.w700, fontSize: 12.5)),
                  const SizedBox(height: 2),
                  Money(s.outstanding.abs(), size: 28, color: credit || s.outstanding == 0 ? C.green : C.text),
                ]),
              ),
              if (s.unpaidCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: C.red.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: C.red.withValues(alpha: 0.4))),
                  child: Text('${s.unpaidCount} غير مسدَّدة', style: TextStyle(color: C.red, fontSize: 11.5, fontWeight: FontWeight.w800)),
                ),
            ]),
            if (credit) ...[
              const SizedBox(height: 8),
              Text('دفع العميل أكثر من المفوتر — يمكن خصم هذا المبلغ من فاتورته القادمة.', style: TextStyle(color: C.muted, fontSize: 11.5)),
            ],
            const Divider(height: 22),
            Row(children: [
              _Kv('رصيد افتتاحي', fmtSARSmart(s.opening)),
              _Kv('مفوتر', fmtSARSmart(s.billed)),
              _Kv('مدفوع', fmtSARSmart(s.paid), color: C.green),
            ]),
            if (c.contact.isNotEmpty || c.phone.isNotEmpty || c.email.isNotEmpty || c.vatNumber.isNotEmpty || c.crNumber.isNotEmpty || c.address.isNotEmpty || c.notes.isNotEmpty) ...[
              const Divider(height: 22),
              _ContactBox(children: [
                if (c.contact.isNotEmpty) _info(Icons.person_outline, c.contact),
                if (c.phone.isNotEmpty) _info(Icons.phone_outlined, c.phone, ltr: true),
                if (c.email.isNotEmpty) _info(Icons.mail_outline, c.email, ltr: true),
                if (c.vatNumber.isNotEmpty) _info(Icons.numbers, 'الرقم الضريبي: ${c.vatNumber}'),
                if (c.crNumber.isNotEmpty) _info(Icons.badge_outlined, 'السجل التجاري: ${c.crNumber}'),
                if (c.address.isNotEmpty) _info(Icons.location_on_outlined, c.address),
                if (c.notes.isNotEmpty) _info(Icons.notes_outlined, c.notes),
              ]),
            ],
          ]),
        ),
        const SizedBox(height: 12),

        // ── الإجراءات (نفس ترتيب دورة العمل) ──
        Row(children: [
          Expanded(child: PlateAction(icon: Ic.invoice, label: 'فاتورة', color: PlateColor.gold, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DocForm(kind: DocKind.invoice, clientId: c.id))))),
          const SizedBox(width: 8),
          Expanded(child: PlateAction(icon: Ic.cash, label: 'دفعة', color: PlateColor.green, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentForm(clientId: c.id))))),
          const SizedBox(width: 8),
          Expanded(child: PlateAction(icon: Ic.statement, label: 'كشف حساب', color: PlateColor.blue, onTap: () => openStatement(context, c))),
          const SizedBox(width: 8),
          Expanded(child: PlateAction(icon: Ic.edit, label: 'عرض سعر', color: PlateColor.violet, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DocForm(kind: DocKind.quotation, clientId: c.id))))),
        ]),

        // ── الأقسام: مختصرة + عرض الكل ──
        _section(context, c, 'الفواتير', invs.length, 0, [for (final i in invs.take(_peek)) _docRow(context, i, store)]),
        _section(context, c, 'عروض الأسعار', quotes.length, 1, [for (final q in quotes.take(_peek)) _docRow(context, q, store)]),
        _section(context, c, 'الدفعات', pays.length, 2, [for (final p in pays.take(_peek)) payRow(context, p, store)]),
        if (invs.isEmpty && quotes.isEmpty && pays.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: EmptyState(icon: Icons.receipt_long_outlined, title: 'لا مستندات بعد', hint: 'ابدأ بفاتورة أو عرض سعر لهذا العميل من الأزرار أعلاه.'),
          ),
      ]),
    );
  }

  Widget _section(BuildContext context, Client c, String title, int total, int tab, List<Widget> rows) {
    if (total == 0) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle(
        '$title ($total)',
        action: total > _peek
            ? TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ClientLedgerScreen(clientId: c.id, initialTab: tab))),
                child: Text('عرض الكل ($total)', style: TextStyle(color: C.gold, fontWeight: FontWeight.w800, fontSize: 13)),
              )
            : null,
      ),
      ...rows,
    ]);
  }

  Widget _info(IconData i, String t, {bool ltr = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Icon(i, size: 17, color: C.gold),
          const SizedBox(width: 8),
          Expanded(child: Text(t, textDirection: ltr ? TextDirection.ltr : null, textAlign: ltr ? TextAlign.right : null, style: TextStyle(color: C.text, fontSize: 13.5))),
        ]),
      );

  Widget _docRow(BuildContext context, Invoice d, Store store) => docRow(context, d, store);
}

/// صف مستند (فاتورة/عرض) — مشترك بين تفاصيل العميل وصفحة «عرض الكل»
Widget docRow(BuildContext context, Invoice d, Store store) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GoldCard(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DocDetail(id: d.id))),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          Plate.icon(d.isQuote ? Ic.edit : Ic.invoice, color: d.isQuote ? PlateColor.violet : PlateColor.gold, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.number, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              Text(
                '${fmtDate(d.issueDate)}${d.location.isNotEmpty ? ' • ${d.location}' : ''}',
                style: TextStyle(color: C.muted, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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

/// صف دفعة — مشترك
Widget payRow(BuildContext context, Payment p, Store store) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GoldCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentForm(clientId: p.clientId, payment: p))),
        child: Row(children: [
          Plate.icon(Ic.cash, color: PlateColor.green, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${p.receiptNumber} • ${p.method}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              Text(
                '${fmtDate(p.date)}${p.invoiceId.isNotEmpty ? ' • فاتورة ${store.doc(p.invoiceId)?.number ?? ''}' : ' • على الحساب'}',
                style: TextStyle(color: C.muted, fontSize: 12),
              ),
            ]),
          ),
          Money(p.amount, size: 14, color: C.green),
        ]),
      ),
    );

/* ============================================================
   عرض الكل — سجل العميل بتبويبات وبحث وتصفية (ملاحظة 8)
   ============================================================ */
class ClientLedgerScreen extends StatefulWidget {
  final String clientId;
  final int initialTab;
  const ClientLedgerScreen({super.key, required this.clientId, this.initialTab = 0});
  @override
  State<ClientLedgerScreen> createState() => _ClientLedgerScreenState();
}

class _ClientLedgerScreenState extends State<ClientLedgerScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this, initialIndex: widget.initialTab);
  String _q = '';
  String _filter = 'all';

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final c = store.client(widget.clientId);
    if (c == null) return const Scaffold(body: Center(child: Text('العميل غير موجود')));
    final invs = store.clientInvoices(c.id);
    final quotes = store.clientQuotes(c.id);
    final pays = store.clientPayments(c.id);

    bool match(Invoice d) =>
        _q.isEmpty || d.number.contains(_q) || d.location.contains(_q) || d.issueDate.contains(_q) || d.items.any((i) => i.desc.contains(_q));
    bool matchP(Payment p) => _q.isEmpty || p.receiptNumber.contains(_q) || p.reference.contains(_q) || p.date.contains(_q) || p.method.contains(_q);

    List<Invoice> fi = invs.where(match).where((d) => _filter == 'all' || computeStatus(d, store.payments).name == _filter).toList();
    List<Invoice> fq = quotes.where(match).where((d) => _filter == 'all' || d.quoteStatus.name == _filter).toList();
    List<Payment> fp = pays.where(matchP).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(c.name),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: C.gold,
          labelColor: C.gold,
          unselectedLabelColor: C.muted,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontFamily: 'Tajawal', fontSize: 13.5),
          onTap: (_) => setState(() => _filter = 'all'),
          tabs: [Tab(text: 'الفواتير (${invs.length})'), Tab(text: 'العروض (${quotes.length})'), Tab(text: 'الدفعات (${pays.length})')],
        ),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: TextField(
            onChanged: (v) => setState(() => _q = v.trim()),
            decoration: InputDecoration(hintText: 'بحث بالرقم أو التاريخ أو الموقع…', prefixIcon: Icon(Icons.search, color: C.muted), isDense: true),
          ),
        ),
        AnimatedBuilder(
          animation: _tabs,
          builder: (_, __) => _tabs.index == 2
              ? const SizedBox(height: 8)
              : SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                    children: [
                      _chip('all', 'الكل'),
                      if (_tabs.index == 0) ...[
                        for (final s in InvoiceStatus.values) _chip(s.name, statusLabel[s]!),
                      ] else ...[
                        for (final s in QuoteStatus.values) _chip(s.name, quoteStatusLabel[s]!),
                      ],
                    ],
                  ),
                ),
        ),
        Expanded(
          child: TabBarView(controller: _tabs, children: [
            _list(fi.map((d) => docRow(context, d, store)).toList(), 'لا فواتير مطابقة'),
            _list(fq.map((d) => docRow(context, d, store)).toList(), 'لا عروض مطابقة'),
            _list(fp.map((p) => payRow(context, p, store)).toList(), 'لا دفعات مطابقة'),
          ]),
        ),
      ]),
    );
  }

  Widget _chip(String v, String label) => Padding(
        padding: const EdgeInsets.only(left: 6),
        child: ChoiceChip(
          label: Text(label, style: const TextStyle(fontSize: 12)),
          selected: _filter == v,
          selectedColor: C.gold.withValues(alpha: 0.25),
          onSelected: (_) => setState(() => _filter = v),
        ),
      );

  Widget _list(List<Widget> rows, String empty) => rows.isEmpty
      ? Center(child: Text(empty, style: TextStyle(color: C.muted)))
      : ListView(padding: const EdgeInsets.fromLTRB(14, 6, 14, 30), children: rows);
}

/// صندوق بيانات التواصل — مطوي افتراضيًا حتى لا تزدحم البطاقة
class _ContactBox extends StatefulWidget {
  final List<Widget> children;
  const _ContactBox({required this.children});
  @override
  State<_ContactBox> createState() => _ContactBoxState();
}

class _ContactBoxState extends State<_ContactBox> {
  bool _open = false;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Icon(Icons.contact_page_outlined, size: 17, color: C.gold),
              const SizedBox(width: 8),
              Text('بيانات التواصل', style: TextStyle(color: C.text2, fontWeight: FontWeight.w700, fontSize: 13)),
              const Spacer(),
              Icon(_open ? Icons.expand_less : Icons.expand_more, color: C.muted, size: 20),
            ]),
          ),
        ),
        if (_open) ...[const SizedBox(height: 8), ...widget.children],
      ]);
}

class _Kv extends StatelessWidget {
  final String k, v;
  final Color color;
  _Kv(this.k, this.v, {Color? color}) : color = color ?? C.text;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k, style: TextStyle(color: C.muted, fontSize: 11.5)),
          const SizedBox(height: 2),
          Text(v, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13.5)),
        ]),
      );
}
