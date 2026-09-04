/// home_screen.dart — الرئيسية | كيف الضيافة
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
import 'payment_form.dart';

class HomeScreen extends StatelessWidget {
  final ValueChanged<int> onNavigate;
  const HomeScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final k = store.kpis;
    final recent = store.invoices.take(5).toList();
    final overdue = store.invoices.where((i) => i.countsInLedger && computeStatus(i, store.payments) != InvoiceStatus.paid).take(4).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
      children: [
        // الترويسة
        Row(children: [
          // الشعار مباشرة على الخلفية بدون صندوق أبيض
          const SizedBox(
            width: 52,
            height: 52,
            child: Image(image: AssetImage('assets/img/logo.png'), fit: BoxFit.contain),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(store.org.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const Text('نظام الفواتير وكشوف الحساب', style: TextStyle(color: C.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: C.gold.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: C.gold.withValues(alpha: 0.5))),
            child: Text(fmtDate(todayISO()), style: const TextStyle(color: C.goldLight, fontWeight: FontWeight.w800, fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 16),

        // دليل البداية السريع — يظهر فقط للمستخدم الجديد ويختفي تلقائيًا
        if (store.clients.isEmpty || store.invoices.isEmpty) ...[
          _GettingStarted(
            hasClient: store.clients.isNotEmpty,
            hasInvoice: store.invoices.isNotEmpty,
            onAddClient: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientForm())),
            onAddInvoice: () => _newDoc(context, DocKind.invoice),
            onSettings: () => onNavigate(4),
          ),
          const SizedBox(height: 12),
        ],

        // بطاقة الرصيد
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(colors: [Color(0xFF1B2D5C), Color(0xFF13224A)], begin: Alignment.topRight, end: Alignment.bottomLeft),
            border: Border.all(color: C.gold.withValues(alpha: 0.6)),
            boxShadow: [BoxShadow(color: C.gold.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: Stack(children: [
            Positioned(right: -30, top: -30, child: Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: C.gold.withValues(alpha: 0.15), width: 14)))),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.account_balance_wallet_rounded, color: C.gold, size: 20),
                SizedBox(width: 8),
                Text('الرصيد المستحق على العملاء', style: TextStyle(color: C.goldLight, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 10),
              Money(k.outstanding, size: 34, color: k.outstanding > 0 ? C.text : C.green),
              const SizedBox(height: 10),
              Row(children: [
                _Dot(C.red, '${k.overdue} فاتورة غير مسددة'),
                const SizedBox(width: 14),
                _Dot(C.green, '${store.clients.length} عميل'),
              ]),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          KpiTile('إجمالي مفوتر', k.billed),
          const SizedBox(width: 10),
          KpiTile('إجمالي محصل', k.collected, color: C.green),
          const SizedBox(width: 10),
          KpiTile('هذا الشهر', k.thisMonth, color: C.goldLight),
        ]),

        const SectionTitle('إجراءات سريعة'),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.82,
          children: [
            QuickAction(icon: Icons.receipt_long_rounded, label: 'فاتورة جديدة', onTap: () => _newDoc(context, DocKind.invoice)),
            QuickAction(icon: Icons.request_quote_rounded, label: 'عرض سعر', onTap: () => _newDoc(context, DocKind.quotation)),
            QuickAction(icon: Icons.account_balance_wallet_rounded, label: 'كشف حساب', onTap: () => onNavigate(3)),
            QuickAction(icon: Icons.payments_rounded, label: 'تسجيل دفعة', onTap: () => _newPayment(context)),
          ],
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientForm())),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
              label: const Text('عميل جديد'),
            ),
          ),
        ]),

        if (overdue.isNotEmpty) ...[
          SectionTitle('فواتير بانتظار السداد', action: TextButton(onPressed: () => onNavigate(2), child: const Text('الكل'))),
          for (final i in overdue) _InvRow(i),
        ],

        SectionTitle('أحدث الفواتير', action: TextButton(onPressed: () => onNavigate(2), child: const Text('الكل'))),
        if (recent.isEmpty)
          EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'لا توجد فواتير بعد',
            hint: 'ابدأ بإضافة عميل ثم أنشئ أول فاتورة',
            action: FilledButton.icon(onPressed: () => _newDoc(context, DocKind.invoice), icon: const Icon(Icons.add), label: const Text('فاتورة جديدة')),
          )
        else
          for (final i in recent) _InvRow(i),
      ],
    );
  }

  void _newDoc(BuildContext context, DocKind kind) {
    final store = context.read<Store>();
    if (store.clients.isEmpty) {
      toast(context, 'أضف عميلًا أولًا', error: true);
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientForm()));
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => DocForm(kind: kind)));
  }

  void _newPayment(BuildContext context) {
    final store = context.read<Store>();
    if (store.clients.isEmpty) {
      toast(context, 'أضف عميلًا أولًا', error: true);
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentForm()));
  }
}

/// بطاقة خطوات البداية (3 خطوات واضحة لغير المتخصصين)
class _GettingStarted extends StatelessWidget {
  final bool hasClient, hasInvoice;
  final VoidCallback onAddClient, onAddInvoice, onSettings;
  const _GettingStarted({required this.hasClient, required this.hasInvoice, required this.onAddClient, required this.onAddInvoice, required this.onSettings});

  @override
  Widget build(BuildContext context) {
    return GoldCard(
      color: C.card2,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.auto_awesome_rounded, color: C.gold, size: 20),
          SizedBox(width: 8),
          Text('أهلًا بك — ابدأ في 3 خطوات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 4),
        const Text('هذه البطاقة تختفي تلقائيًا بعد إنشاء أول فاتورة.', style: TextStyle(color: C.muted, fontSize: 12)),
        const SizedBox(height: 12),
        _Step(1, 'راجع بيانات مؤسستك', 'الاسم، الهاتف، الحساب البنكي — تظهر في كل فاتورة', done: false, onTap: onSettings, optional: true),
        _Step(2, 'أضف أول عميل', 'يكفي الاسم فقط، والباقي اختياري', done: hasClient, onTap: onAddClient),
        _Step(3, 'أنشئ فاتورة وشاركها', 'اختر العميل، أضف البنود، ثم اضغط "مشاركة" لإرسالها على واتساب', done: hasInvoice, onTap: hasClient ? onAddInvoice : null),
      ]),
    );
  }
}

class _Step extends StatelessWidget {
  final int n;
  final String title, hint;
  final bool done, optional;
  final VoidCallback? onTap;
  const _Step(this.n, this.title, this.hint, {required this.done, this.onTap, this.optional = false});
  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
        child: Row(children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? C.green : (enabled ? C.gold : C.line),
            ),
            child: done
                ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                : Text('$n', style: TextStyle(color: enabled ? C.bg : C.muted, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: enabled || done ? C.text : C.muted, decoration: done ? TextDecoration.lineThrough : null)),
                if (optional) ...[
                  const SizedBox(width: 6),
                  const Text('(اختياري)', style: TextStyle(color: C.muted, fontSize: 11)),
                ],
              ]),
              Text(hint, style: const TextStyle(color: C.muted, fontSize: 12)),
            ]),
          ),
          if (enabled && !done) const Icon(Icons.chevron_left_rounded, color: C.gold),
        ]),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color c;
  final String t;
  const _Dot(this.c, this.t);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(t, style: const TextStyle(color: C.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
      ]);
}

class _InvRow extends StatelessWidget {
  final Invoice inv;
  const _InvRow(this.inv);
  @override
  Widget build(BuildContext context) {
    final store = context.read<Store>();
    final st = computeStatus(inv, store.payments);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GoldCard(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DocDetail(id: inv.id))),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(inv.clientName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
              const SizedBox(height: 3),
              Text('${inv.number} • ${fmtDate(inv.issueDate)}', style: const TextStyle(color: C.muted, fontSize: 12)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Money(inv.totals.total, size: 15),
            const SizedBox(height: 4),
            StatusChip.invoice(st),
          ]),
        ]),
      ),
    );
  }
}
