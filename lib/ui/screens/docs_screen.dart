/// docs_screen.dart — الفواتير وعروض الأسعار | كيف الضيافة
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../core/store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'client_form.dart';
import 'doc_detail.dart';
import 'doc_form.dart';

class DocsScreen extends StatefulWidget {
  const DocsScreen({super.key});
  @override
  State<DocsScreen> createState() => _DocsScreenState();
}

class _DocsScreenState extends State<DocsScreen> with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 2, vsync: this);
  String _filter = 'all';
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('الفواتير والعروض'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: C.gold,
          labelColor: C.gold,
          unselectedLabelColor: C.muted,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontFamily: 'Tajawal', fontSize: 14),
          onTap: (_) => setState(() => _filter = 'all'),
          tabs: [Tab(text: 'الفواتير (${store.invoices.length})'), Tab(text: 'عروض الأسعار (${store.quotes.length})')],
        ),
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabs,
        builder: (_, __) => FloatingActionButton.extended(
          onPressed: () {
            if (store.clients.isEmpty) {
              toast(context, 'أضف عميلًا أولًا', error: true);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientForm()));
              return;
            }
            Navigator.push(context, MaterialPageRoute(builder: (_) => DocForm(kind: _tabs.index == 0 ? DocKind.invoice : DocKind.quotation)));
          },
          backgroundColor: C.gold,
          foregroundColor: C.bg,
          icon: const Icon(Icons.add),
          label: Text(_tabs.index == 0 ? 'فاتورة جديدة' : 'عرض سعر جديد', style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          child: TextField(
            onChanged: (v) => setState(() => _q = v.trim()),
            decoration: InputDecoration(hintText: 'بحث بالرقم أو العميل…', prefixIcon: Icon(Icons.search, color: C.muted)),
          ),
        ),
        SizedBox(
          height: 52,
          child: AnimatedBuilder(
            animation: _tabs,
            builder: (_, __) {
              final isInv = _tabs.index == 0;
              final chips = isInv
                  ? [('all', 'الكل'), ('unpaid', 'غير مدفوعة'), ('partial', 'جزئية'), ('paid', 'مدفوعة'), ('draft', 'مسودات')]
                  : [('all', 'الكل'), ('draft', 'مسودة'), ('sent', 'مُرسل'), ('accepted', 'مقبول'), ('converted', 'محوّل')];
              return ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                children: [
                  for (final c in chips)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ChoiceChip(label: Text(c.$2), selected: _filter == c.$1, onSelected: (_) => setState(() => _filter = c.$1), showCheckmark: false),
                    ),
                ],
              );
            },
          ),
        ),
        Expanded(
          child: TabBarView(controller: _tabs, children: [
            _list(store, store.invoices, true),
            _list(store, store.quotes, false),
          ]),
        ),
      ]),
    );
  }

  Widget _list(Store store, List<Invoice> all, bool isInv) {
    final list = all.where((d) {
      if (_q.isNotEmpty && !d.number.contains(_q) && !d.clientName.contains(_q)) return false;
      if (_filter == 'all') return true;
      if (isInv) {
        final st = computeStatus(d, store.payments);
        return switch (_filter) {
          'unpaid' => st == InvoiceStatus.issued,
          'partial' => st == InvoiceStatus.partial,
          'paid' => st == InvoiceStatus.paid,
          'draft' => st == InvoiceStatus.draft,
          _ => true,
        };
      }
      return d.status == _filter;
    }).toList();

    if (list.isEmpty) {
      return EmptyState(
        icon: isInv ? Icons.receipt_long_outlined : Icons.request_quote_outlined,
        title: isInv ? 'لا توجد فواتير' : 'لا توجد عروض أسعار',
        hint: isInv ? 'اضغط "فاتورة جديدة" لإصدار أول فاتورة' : 'أنشئ عرض سعر وحوّله لفاتورة عند القبول',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 90),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final d = list[i];
        return GoldCard(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DocDetail(id: d.id))),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: C.gold.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: C.gold.withValues(alpha: 0.4))),
              child: Icon(isInv ? Icons.receipt_long_rounded : Icons.request_quote_rounded, color: C.gold, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d.clientName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                const SizedBox(height: 3),
                Text('${d.number} • ${fmtDate(d.issueDate)}${d.location.isNotEmpty ? ' • ${d.location}' : ''}', style: TextStyle(color: C.muted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Money(d.totals.total, size: 15),
              const SizedBox(height: 4),
              isInv ? StatusChip.invoice(computeStatus(d, store.payments)) : StatusChip.quote(d.quoteStatus),
            ]),
          ]),
        );
      },
    );
  }
}
