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
    final recent = store.invoices.take(5).toList();

    // المستحقات حسب العميل (أكبر 4 أرصدة)
    final dues = <(Client, ClientSummary)>[];
    for (final c in store.clients) {
      final s = store.summary(c);
      if (s.outstanding > 0) dues.add((c, s));
    }
    dues.sort((a, b) => b.$2.outstanding.compareTo(a.$2.outstanding));

    final isNew = store.clients.isEmpty || store.invoices.isEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 28),
      children: [
        _TopBar(orgName: store.org.name, onMenu: onMenu),
        const SizedBox(height: 14),

        if (isNew) ...[
          _GettingStarted(
            hasClient: store.clients.isNotEmpty,
            hasInvoice: store.invoices.isNotEmpty,
            onAddClient: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientForm())),
            onAddInvoice: () => _newDoc(context, DocKind.invoice),
            onSettings: onMenu,
          ),
          const SizedBox(height: 12),
        ],

        // بطاقة الرصيد (hero)
        _HeroCard(k: k, clients: store.clients.length),

        // إجراء سريع — 4 ألواح ملونة كما في التصميم الأصلي
        const SectionTitle('إجراء سريع'),
        Row(children: [
          Expanded(child: PlateAction(icon: Ic.invoice, label: 'فاتورة جديدة', color: PlateColor.gold, onTap: () => _newDoc(context, DocKind.invoice))),
          const SizedBox(width: 8),
          Expanded(child: PlateAction(icon: Ic.statement, label: 'كشف حساب', color: PlateColor.blue, onTap: () => onNavigate(3))),
          const SizedBox(width: 8),
          Expanded(child: PlateAction(icon: Ic.cash, label: 'تسجيل دفعة', color: PlateColor.green, onTap: () => _newPayment(context))),
          const SizedBox(width: 8),
          Expanded(
            child: PlateAction(
              icon: Ic.clients,
              label: 'عميل جديد',
              color: PlateColor.violet,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientForm())),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _MiniAction(icon: Ic.edit, label: 'عرض سعر', onTap: () => _newDoc(context, DocKind.quotation))),
          const SizedBox(width: 8),
          Expanded(child: _MiniAction(icon: Ic.chart, label: 'التقارير', onTap: onMenu)),
        ]),

        // مستحقات قائمة
        if (dues.isNotEmpty) ...[
          SectionTitle('مستحقات قائمة', action: TextButton(onPressed: () => onNavigate(1), child: const Text('الكل'))),
          for (final d in dues.take(4)) _DueRow(d.$1, d.$2),
        ],

        // أحدث الفواتير
        SectionTitle('أحدث الفواتير', action: TextButton(onPressed: () => onNavigate(2), child: const Text('الكل'))),
        if (recent.isEmpty)
          EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'لا توجد فواتير بعد',
            hint: 'ابدأ بإضافة عميل ثم أنشئ أول فاتورة',
            action: FilledButton.icon(onPressed: () => _newDoc(context, DocKind.invoice), icon: const Icon(Icons.add), label: const Text('فاتورة جديدة')),
          )
        else
          for (final i in recent) InvoiceRow(i),
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

/* ---------------- إجراء صغير ---------------- */
class _MiniAction extends StatelessWidget {
  final String icon, label;
  final VoidCallback onTap;
  const _MiniAction({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GoldCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          KIcon(icon, size: 26),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: C.text))),
          Icon(Icons.chevron_left_rounded, color: C.text3, size: 20),
        ]),
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

/* ---------------- بطاقة البداية (3 خطوات) ---------------- */
class _GettingStarted extends StatelessWidget {
  final bool hasClient, hasInvoice;
  final VoidCallback onAddClient, onAddInvoice, onSettings;
  const _GettingStarted({required this.hasClient, required this.hasInvoice, required this.onAddClient, required this.onAddInvoice, required this.onSettings});

  @override
  Widget build(BuildContext context) {
    return GoldCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const KIcon(Ic.dallah, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('أهلًا بك في كيف الضيافة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: C.text)),
              Text('ابدأ في 3 خطوات — تختفي البطاقة بعد أول فاتورة', style: TextStyle(color: C.text3, fontSize: 11.5)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        _Step(1, 'راجع بيانات مؤسستك', 'الاسم والهاتف والحساب البنكي تظهر في كل مستند', done: false, onTap: onSettings, optional: true),
        _Step(2, 'أضف أول عميل', 'يكفي الاسم فقط', done: hasClient, onTap: onAddClient),
        _Step(3, 'أنشئ فاتورة وشاركها', 'اختر العميل، أضف البنود، ثم شاركها على واتساب', done: hasInvoice, onTap: hasClient ? onAddInvoice : null),
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
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Row(children: [
          done
              ? const KIcon(Ic.check, size: 28)
              : Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(shape: BoxShape.circle, gradient: enabled ? C.goldGradient : null, color: enabled ? null : C.surface3),
                  child: Text('$n', style: TextStyle(color: enabled ? C.onGold : C.text3, fontWeight: FontWeight.w900)),
                ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: enabled || done ? C.text : C.text3, decoration: done ? TextDecoration.lineThrough : null)),
                if (optional) ...[const SizedBox(width: 6), Text('(اختياري)', style: TextStyle(color: C.text3, fontSize: 11))],
              ]),
              Text(hint, style: TextStyle(color: C.text3, fontSize: 11.5)),
            ]),
          ),
          if (enabled && !done) Icon(Icons.chevron_left_rounded, color: C.goldInk),
        ]),
      ),
    );
  }
}
