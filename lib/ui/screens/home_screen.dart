/// home_screen.dart — الرئيسية (تصميم كيف الضيافة الأصلي: بطاقة الرصيد + إجراءات 3D) | كيف الضيافة
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../core/money.dart';
import '../../core/store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'client_form.dart';
import 'clients_screen.dart';
import 'doc_detail.dart';
import 'doc_form.dart';
import 'payment_form.dart';

class HomeScreen extends StatelessWidget {
  final ValueChanged<int> onNavigate;
  final VoidCallback onMenu;
  const HomeScreen({super.key, required this.onNavigate, required this.onMenu});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final k = store.kpis;
    final recent = store.invoices.take(3).toList();

    // المستحقات حسب العميل (أكبر 4 أرصدة)
    final dues = <(Client, ClientSummary)>[];
    for (final c in store.clients) {
      final s = store.summary(c);
      if (s.outstanding > 0) dues.add((c, s));
    }
    dues.sort((a, b) => b.$2.outstanding.compareTo(a.$2.outstanding));

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 28),
      children: [
        _TopBar(orgName: store.org.name, onMenu: onMenu),
        const SizedBox(height: 14),

        // بطاقة الرصيد (hero)
        _HeroCard(k: k, clients: store.clients.length),

        // الأزرار الرئيسية — ترتيب دورة العمل: عميل → فاتورة → دفعة → كشف حساب
        const SectionTitle('دورة العمل'),
        Row(children: [
          Expanded(
            child: PlateAction(
              icon: Ic.clients,
              label: 'إنشاء عميل',
              hint: 'الخطوة 1',
              color: PlateColor.violet,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientForm())),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: PlateAction(icon: Ic.invoice, label: 'فاتورة جديدة', hint: 'الخطوة 2', color: PlateColor.gold, onTap: () => _newDoc(context, DocKind.invoice))),
          const SizedBox(width: 8),
          Expanded(child: PlateAction(icon: Ic.cash, label: 'تسجيل دفعة', hint: 'الخطوة 3', color: PlateColor.green, onTap: () => _newPayment(context))),
          const SizedBox(width: 8),
          Expanded(child: PlateAction(icon: Ic.statement, label: 'كشف حساب', hint: 'الخطوة 4', color: PlateColor.blue, onTap: () => onNavigate(3))),
        ]),

        // مستحقات قائمة
        if (dues.isNotEmpty) ...[
          SectionTitle('مستحقات قائمة', action: TextButton(onPressed: () => onNavigate(1), child: const Text('الكل'))),
          for (final d in dues.take(4)) _DueRow(d.$1, d.$2),
        ],

        // أحدث الفواتير
        const SectionTitle('أحدث الفواتير'),
        if (recent.isEmpty)
          EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'لا توجد فواتير بعد',
            hint: 'ابدأ بإضافة عميل ثم أنشئ أول فاتورة',
            action: FilledButton.icon(onPressed: () => _newDoc(context, DocKind.invoice), icon: const Icon(Icons.add), label: const Text('فاتورة جديدة')),
          )
        else ...[
          for (final i in recent) InvoiceRow(i),
          if (store.invoices.length > recent.length)
            OutlinedButton.icon(
              onPressed: () => onNavigate(2),
              icon: const Icon(Icons.receipt_long_outlined, size: 18),
              label: Text('عرض كل الفواتير (${store.invoices.length})'),
            ),
        ],
      ],
    );
  }

  void _newDoc(BuildContext context, DocKind kind) {
    final store = context.read<Store>();
    if (store.clients.isEmpty) {
      toast(context, 'أضف عميلًا أولًا — يكفي الاسم', error: true);
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

/* ---------------- الشريط العلوي ---------------- */
class _TopBar extends StatelessWidget {
  final String orgName;
  final VoidCallback onMenu;
  const _TopBar({required this.orgName, required this.onMenu});
  @override
  Widget build(BuildContext context) => Row(children: [
        IconButton(
          onPressed: onMenu,
          tooltip: 'القائمة',
          style: IconButton.styleFrom(backgroundColor: C.surface2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: C.line2))),
          icon: Icon(Icons.menu_rounded, color: C.text2),
        ),
        const SizedBox(width: 10),
        const SizedBox(width: 46, height: 46, child: Image(image: AssetImage('assets/img/logo.png'), fit: BoxFit.contain)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(orgName, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: C.text), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('نظام الفواتير وكشوف الحساب', style: TextStyle(color: C.text3, fontSize: 11.5, fontWeight: FontWeight.w600)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.line)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const KIcon(Ic.calendar, size: 16),
            const SizedBox(width: 6),
            Text(fmtDate(todayISO()), style: TextStyle(color: C.goldInk, fontWeight: FontWeight.w800, fontSize: 12)),
          ]),
        ),
      ]);
}

/* ---------------- بطاقة الرصيد ---------------- */
class _HeroCard extends StatelessWidget {
  final ({int outstanding, int billed, int collected, int thisMonth, int overdue}) k;
  final int clients;
  const _HeroCard({required this.k, required this.clients});

  @override
  Widget build(BuildContext context) {
    // نسبة التحصيل من إجمالي المفوتر
    final rate = k.billed > 0 ? (k.collected / k.billed).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(colors: [C.surface2, C.surface], begin: Alignment.topRight, end: Alignment.bottomLeft),
        border: Border.all(color: C.line),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: C.isDark ? 0.35 : 0.08), blurRadius: 24, offset: const Offset(0, 10)),
          BoxShadow(color: C.gold.withValues(alpha: 0.10), blurRadius: 30, offset: const Offset(0, 6)),
        ],
      ),
      child: Stack(children: [
        // زخرفة: وهج ذهبي خفيف في الزاوية
        Positioned(
          right: -30,
          top: -30,
          child: IgnorePointer(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [C.gold.withValues(alpha: C.isDark ? 0.16 : 0.10), Colors.transparent]),
              ),
            ),
          ),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('الرصيد المستحق على العملاء', style: TextStyle(color: C.text2, fontWeight: FontWeight.w600, fontSize: 12.5)),
          const SizedBox(height: 6),
          _GoldMoney(k.outstanding),
          const SizedBox(height: 2),
          Text(
            k.overdue == 0 ? 'لا توجد فواتير غير مسددة' : '${k.overdue} فاتورة بانتظار السداد • $clients عميل',
            style: TextStyle(color: C.text3, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Row(children: [
            _HeroCell('إجمالي مفوتر', k.billed),
            const SizedBox(width: 8),
            _HeroCell('إجمالي محصّل', k.collected, color: C.ok),
            const SizedBox(width: 8),
            _HeroCell('هذا الشهر', k.thisMonth, color: C.goldInk),
          ]),
          const SizedBox(height: 12),
          // شريط نسبة التحصيل
          Row(children: [
            Text('نسبة التحصيل', style: TextStyle(color: C.text3, fontSize: 11.5, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('${(rate * 100).round()}%', style: TextStyle(color: C.goldInk, fontSize: 12, fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 7,
              child: Stack(children: [
                Container(color: C.isDark ? Colors.black.withValues(alpha: 0.25) : C.bg2),
                FractionallySizedBox(
                  widthFactor: rate == 0 ? 0.001 : rate,
                  child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [C.goldDeep, C.gold2]))),
                ),
              ]),
            ),
          ),
        ]),
      ]),
    );
  }
}

/// رقم كبير بتدرّج ذهبي (hero__val)
class _GoldMoney extends StatelessWidget {
  final int v;
  const _GoldMoney(this.v);
  @override
  Widget build(BuildContext context) {
    final txt = Text.rich(
      TextSpan(children: [
        TextSpan(text: fmt(v), style: moneyStyle(36, color: Colors.white)),
        TextSpan(text: '  ر.س', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
      ]),
      textDirection: TextDirection.rtl,
    );
    return ShaderMask(
      shaderCallback: (r) => LinearGradient(colors: [C.gold2, C.gold]).createShader(r),
      blendMode: BlendMode.srcIn,
      child: txt,
    );
  }
}

class _HeroCell extends StatelessWidget {
  final String label;
  final int value;
  final Color? color;
  const _HeroCell(this.label, this.value, {this.color});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 9),
          decoration: BoxDecoration(
            color: C.isDark ? Colors.black.withValues(alpha: 0.18) : C.bg2.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: C.line2),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: C.text3, fontSize: 10.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Money(value, size: 14.5, color: color ?? C.text)),
          ]),
        ),
      );
}

/* ---------------- صف مستحق ---------------- */
class _DueRow extends StatelessWidget {
  final Client c;
  final ClientSummary s;
  const _DueRow(this.c, this.s);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GoldCard(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ClientDetail(id: c.id))),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            Avatar(c.name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.name, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: C.text), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('${s.unpaidCount} فاتورة غير مسددة', style: TextStyle(color: C.text3, fontSize: 11.5)),
              ]),
            ),
            Money(s.outstanding, size: 15, color: C.warn),
          ]),
        ),
      );
}

/* ---------------- صف فاتورة (مشترك) ---------------- */
class InvoiceRow extends StatelessWidget {
  final Invoice inv;
  const InvoiceRow(this.inv, {super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.read<Store>();
    final st = inv.isQuote ? null : computeStatus(inv, store.payments);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GoldCard(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DocDetail(id: inv.id))),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [C.surface3, C.surface2], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: C.line),
            ),
            child: Center(child: KIcon(inv.isQuote ? Ic.edit : Ic.invoice, size: 24)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(inv.clientName, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: C.text), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('${inv.number} • ${fmtDate(inv.issueDate)}', style: TextStyle(color: C.text3, fontSize: 11.5)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Money(inv.totals.total, size: 15),
            const SizedBox(height: 4),
            if (st != null) StatusChip.invoice(st) else StatusChip.quote(inv.quoteStatus),
          ]),
        ]),
      ),
    );
  }
}
