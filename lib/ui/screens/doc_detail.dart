/// doc_detail.dart — تفاصيل الفاتورة / عرض السعر | كيف الضيافة
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../core/money.dart';
import '../../core/share_service.dart';
import '../../core/store.dart';
import '../../pdf/documents.dart';
import '../preview_screen.dart';
import '../theme.dart';
import '../widgets.dart';
import 'doc_form.dart';
import 'payment_form.dart';

class DocDetail extends StatelessWidget {
  final String id;
  const DocDetail({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final d = store.doc(id);
    if (d == null) return const Scaffold(body: Center(child: Text('المستند غير موجود')));
    final isQ = d.isQuote;
    final t = d.totals;
    final paid = isQ ? 0 : invoicePaid(d, store.payments);
    final rem = t.total - paid;
    final pays = store.payments.where((p) => p.invoiceId == d.id).toList()..sort((a, b) => b.date.compareTo(a.date));
    final client = store.client(d.clientId);

    return Scaffold(
      appBar: AppBar(
        title: Text(d.number),
        actions: [
          IconButton(tooltip: 'تعديل', icon: const Icon(Icons.edit_outlined), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DocForm(kind: d.kind, doc: d)))),
          PopupMenuButton<String>(
            onSelected: (v) async {
              switch (v) {
                case 'dup':
                  final c = d.copy()
                    ..id = uid('i_')
                    ..number = ''
                    ..issueDate = todayISO()
                    ..deposit = 0
                    ..convertedTo = ''
                    ..status = isQ ? QuoteStatus.draft.name : InvoiceStatus.issued.name;
                  c.items = d.items.map((e) => e.copy()..id = uid('li_')).toList();
                  await store.saveDoc(c);
                  if (context.mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DocDetail(id: c.id)));
                case 'del':
                  if (await confirm(context, 'حذف ${isQ ? 'عرض السعر' : 'الفاتورة'}', 'سيُحذف المستند ${d.number} نهائيًا${isQ ? '' : ' مع الدفعات المرتبطة به'}.')) {
                    await store.deleteDoc(d.id);
                    if (context.mounted) Navigator.pop(context);
                  }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'dup', child: Text('نسخ كمستند جديد')),
              PopupMenuItem(value: 'del', child: Text('حذف', style: TextStyle(color: C.red))),
            ],
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(14, 4, 14, 30), children: [
        // رأس
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(colors: [Color(0xFF1B2D5C), Color(0xFF13224A)]),
            border: Border.all(color: C.gold.withValues(alpha: 0.6)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(d.clientName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
              isQ ? StatusChip.quote(d.quoteStatus) : StatusChip.invoice(computeStatus(d, store.payments)),
            ]),
            const SizedBox(height: 4),
            Text(
              [
                fmtDate(d.issueDate),
                if (d.eventDate.isNotEmpty) 'المناسبة ${fmtDate(d.eventDate)}${d.eventDateTo.isNotEmpty && d.eventDateTo != d.eventDate ? ' → ${fmtDate(d.eventDateTo)}' : ''}',
                if (d.location.isNotEmpty) d.location,
                if (isQ && d.validUntil.isNotEmpty) 'ساري حتى ${fmtDate(d.validUntil)}',
              ].join(' • '),
              style: const TextStyle(color: C.muted, fontSize: 12.5),
            ),
            const Divider(height: 22),
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(isQ ? 'إجمالي العرض' : 'الإجمالي', style: const TextStyle(color: C.goldLight, fontSize: 12, fontWeight: FontWeight.w700)),
                  Money(t.total, size: 26),
                ]),
              ),
              if (!isQ)
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(rem > 0 ? 'المتبقي' : 'مسدَّدة', style: TextStyle(color: rem > 0 ? C.red : C.green, fontSize: 12, fontWeight: FontWeight.w700)),
                    Money(rem, size: 22, color: rem > 0 ? C.red : C.green),
                  ]),
                ),
            ]),
          ]),
        ),
        const SizedBox(height: 12),

        // أزرار المستند
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _preview(context, d, store),
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: const Text('معاينة وطباعة ومشاركة'),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => runBusy(context, 'جارٍ تجهيز الملف…', () async {
                final pdf = await DocPdf.create(store.org);
                final bytes = await pdf.invoice(d, store.payments, client: client);
                await ShareService.sharePdf(bytes, '${ShareService.safeName(d.number)}.pdf', ShareService.invoiceMessage(d, store.org, store.payments));
              }),
              icon: const Icon(Icons.share_rounded, size: 18),
              label: const Text('مشاركة سريعة'),
            ),
          ),
          const SizedBox(width: 8),
          if (isQ && d.quoteStatus != QuoteStatus.converted)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  if (!await confirm(context, 'تحويل إلى فاتورة', 'سيتم إنشاء فاتورة جديدة بنفس البنود، ويُعلَّم العرض كمحوّل.', ok: 'تحويل', danger: false)) return;
                  final inv = await store.convertQuote(d);
                  if (context.mounted) {
                    toast(context, 'تم إنشاء الفاتورة ${inv.number}');
                    Navigator.push(context, MaterialPageRoute(builder: (_) => DocDetail(id: inv.id)));
                  }
                },
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: const Text('تحويل لفاتورة'),
              ),
            )
          else if (!isQ && d.countsInLedger && rem > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentForm(clientId: d.clientId, invoiceId: d.id, suggested: rem))),
                icon: const Icon(Icons.payments_rounded, size: 18),
                label: const Text('تسجيل دفعة'),
              ),
            )
          else if (isQ)
            Expanded(child: OutlinedButton.icon(onPressed: null, icon: const Icon(Icons.check, size: 18), label: Text('حُوّل إلى ${d.convertedTo}'))),
        ]),

        // البنود
        const SectionTitle('البنود'),
        GoldCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (var i = 0; i < d.items.length; i++) ...[
              if (i > 0) const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [C.goldDark, C.gold, C.goldLight])),
                    child: Text('${i + 1}', style: const TextStyle(color: C.bg, fontWeight: FontWeight.w900, fontSize: 12)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(d.items[i].desc.split('\n').first, style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(
                        '${fmt(d.items[i].unitPrice, trimZeros: true)} × ${fmtQty(d.items[i].qty)} ${d.items[i].unitLabel}${d.items[i].external > 0 ? ' + مشتريات ${fmt(d.items[i].external, trimZeros: true)}' : ''}',
                        style: const TextStyle(color: C.muted, fontSize: 12),
                      ),
                    ]),
                  ),
                  Money(d.items[i].total, size: 14),
                ]),
              ),
            ],
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(children: [
                _sum('المجموع', fmt(t.subtotal)),
                if (t.discount > 0) _sum('الخصم', '− ${fmt(t.discount)}', color: C.red),
                _sum(t.vatRateBp > 0 ? 'الضريبة (${t.vatRateBp ~/ 100}%)' : 'الضريبة', t.vatRateBp > 0 ? fmt(t.vat) : 'معفاة'),
                _sum(isQ ? 'إجمالي العرض' : 'الإجمالي المستحق', fmtSAR(t.total), strong: true),
                if (!isQ && d.deposit > 0) _sum('العربون', fmt(d.deposit), color: C.green),
                if (!isQ && pays.isNotEmpty) _sum('دفعات مسجّلة', fmt(paid - d.deposit), color: C.green),
              ]),
            ),
          ]),
        ),

        if (pays.isNotEmpty) ...[
          const SectionTitle('الدفعات المرتبطة'),
          for (final p in pays)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GoldCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentForm(clientId: d.clientId, payment: p))),
                child: Row(children: [
                  const Icon(Icons.payments_outlined, color: C.green, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text('${p.receiptNumber} • ${p.method} • ${fmtDate(p.date)}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700))),
                  Money(p.amount, size: 14, color: C.green),
                ]),
              ),
            ),
        ],
        if (d.notes.isNotEmpty) ...[const SectionTitle('ملاحظات'), Text(d.notes, style: const TextStyle(color: C.muted))],
      ]),
    );
  }

  Widget _sum(String l, String v, {bool strong = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Text(l, style: TextStyle(color: color ?? (strong ? C.goldLight : C.muted), fontWeight: strong ? FontWeight.w800 : FontWeight.w600, fontSize: strong ? 15 : 13)),
          const Spacer(),
          Text(v, style: TextStyle(color: color ?? C.text, fontWeight: FontWeight.w800, fontSize: strong ? 16 : 13.5)),
        ]),
      );

  void _preview(BuildContext context, Invoice d, Store store) {
    final label = d.isQuote ? 'عرض سعر ${d.number}' : 'فاتورة ${d.number}';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PreviewScreen(
          title: label,
          fileName: '${ShareService.safeName(d.number)}.pdf',
          message: ShareService.invoiceMessage(d, store.org, store.payments),
          build: () async => (await DocPdf.create(store.org)).invoice(d, store.payments, client: store.client(d.clientId)),
        ),
      ),
    );
  }
}
