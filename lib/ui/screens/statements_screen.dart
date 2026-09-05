/// statements_screen.dart — كشوف الحساب | كيف الضيافة
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

class StatementsScreen extends StatelessWidget {
  const StatementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final clients = [...store.clients]..sort((a, b) => store.summary(b).outstanding.compareTo(store.summary(a).outstanding));

    return Scaffold(
      appBar: AppBar(title: const Text('كشوف الحساب')),
      body: clients.isEmpty
          ? const EmptyState(icon: Icons.account_balance_wallet_outlined, title: 'لا يوجد عملاء', hint: 'أضف عملاء وفواتير ثم أصدر كشوف الحساب من هنا')
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 30),
              itemCount: clients.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                if (i == 0) {
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: C.gold.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: C.gold.withValues(alpha: 0.35))),
                    child: Row(children: [
                      Icon(Icons.info_outline, color: C.gold, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Text('اختر عميلًا لإصدار كشف حساب فاخر بالفترة التي تريدها (هذا الشهر، الشهر الماضي، الكل، أو مخصصة).', style: TextStyle(color: C.text, fontSize: 13))),
                    ]),
                  );
                }
                final c = clients[i - 1];
                final s = store.summary(c);
                return GoldCard(
                  onTap: () => openStatement(context, c),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(children: [
                    Icon(Icons.account_balance_wallet_rounded, color: C.gold),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        Text('${s.invoiceCount} فاتورة • ${s.unpaidCount} غير مسددة', style: TextStyle(color: C.muted, fontSize: 12)),
                      ]),
                    ),
                    Money(s.outstanding, size: 15, color: s.outstanding > 0 ? C.text : C.green),
                    const SizedBox(width: 6),
                    Icon(Icons.chevron_left, color: C.muted),
                  ]),
                );
              },
            ),
    );
  }
}

/// نافذة اختيار فترة الكشف ثم المعاينة
Future<void> openStatement(BuildContext context, Client c) async {
  final store = context.read<Store>();
  var preset = 'all';
  var from = '';
  var to = '';
  final now = DateTime.now();
  String iso(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void applyPreset(String p) {
    preset = p;
    switch (p) {
      case 'month':
        from = iso(DateTime(now.year, now.month, 1));
        to = iso(DateTime(now.year, now.month + 1, 0));
      case 'last':
        from = iso(DateTime(now.year, now.month - 1, 1));
        to = iso(DateTime(now.year, now.month, 0));
      case 'all':
        from = '';
        to = '';
    }
  }

  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('كشف حساب — ${c.name}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final p in [('all', 'كل الفواتير'), ('month', 'هذا الشهر'), ('last', 'الشهر الماضي'), ('custom', 'مخصصة')])
              ChoiceChip(label: Text(p.$2), selected: preset == p.$1, showCheckmark: false, onSelected: (_) => setS(() => applyPreset(p.$1))),
          ]),
          if (preset == 'custom') ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _DateBtn('من', from, (v) => setS(() => from = v))),
              const SizedBox(width: 10),
              Expanded(child: _DateBtn('إلى', to, (v) => setS(() => to = v))),
            ]),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: () => Navigator.pop(ctx, true), icon: const Icon(Icons.picture_as_pdf_rounded), label: const Text('إصدار الكشف')),
        ]),
      ),
    ),
  );
  if (ok != true || !context.mounted) return;

  final st = buildStatement(client: c, invoices: store.docs, payments: store.payments, from: from, to: to, number: store.statementNumber(c));
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PreviewScreen(
        title: 'كشف حساب — ${c.name}',
        fileName: store.statementFileName(c, st.issueDate),
        message: ShareService.statementMessage(st, store.org),
        build: () async => (await DocPdf.create(store.org)).statement(st),
        kind: FileKind.statement,
        year: FileService.yearOf(st.issueDate),
      ),
    ),
  );
}

class _DateBtn extends StatelessWidget {
  final String label, value;
  final ValueChanged<String> set;
  const _DateBtn(this.label, this.value, this.set);
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final v = await pickDate(context, value);
          if (v != null) set(v);
        },
        child: InputDecorator(
          decoration: InputDecoration(labelText: label, prefixIcon: Icon(Icons.event_outlined, color: C.muted, size: 20)),
          child: Text(value.isEmpty ? '—' : fmtDate(value), style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      );
}
