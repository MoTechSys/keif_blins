/// claims_screen.dart — خطابات المطالبة المالية: القائمة + النموذج المرن + المعاينة | نظام الفواتير
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/file_service.dart';
import '../../core/models.dart';
import '../../core/money.dart';
import '../../core/store.dart';
import '../../pdf/documents.dart';
import '../preview_screen.dart';
import '../theme.dart';
import '../widgets.dart';

/* ============================================================
   القائمة
   ============================================================ */
class ClaimsScreen extends StatefulWidget {
  /// تصفية على عميل (من صفحة العميل)
  final String? clientId;
  const ClaimsScreen({super.key, this.clientId});
  @override
  State<ClaimsScreen> createState() => _ClaimsScreenState();
}

class _ClaimsScreenState extends State<ClaimsScreen> {
  String _q = '';
  String _status = 'all';

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final base = widget.clientId == null
        ? store.claimsSorted
        : store.clientClaims(widget.clientId!);
    final list = base.where((c) {
      if (_status != 'all' && c.status != _status) return false;
      if (_q.isEmpty) return true;
      return c.number.contains(_q) ||
          c.recipient.contains(_q) ||
          c.subject.contains(_q) ||
          c.items.any(
            (i) => i.desc.contains(_q) || i.invoiceNumber.contains(_q),
          );
    }).toList();
    final total = list.fold<int>(0, (s, c) => s + c.total);

    return Scaffold(
      appBar: AppBar(title: Text('خطابات المطالبة (${base.length})')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => newClaim(context, clientId: widget.clientId),
        backgroundColor: C.gold,
        foregroundColor: C.bg,
        icon: const Icon(Icons.add),
        label: const Text(
          'خطاب مطالبة جديد',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: TextField(
              onChanged: (v) => setState(() => _q = v.trim()),
              decoration: InputDecoration(
                hintText: 'بحث بالرقم أو الجهة أو البيان…',
                prefixIcon: Icon(Icons.search, color: C.muted),
                isDense: true,
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
              children: [
                _chip('all', 'الكل'),
                for (final s in ClaimStatus.values)
                  _chip(s.name, claimStatusLabel[s]!),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 2, 18, 6),
            child: Row(
              children: [
                Text(
                  '${list.length} خطاب',
                  style: TextStyle(color: C.muted, fontSize: 12.5),
                ),
                const Spacer(),
                Text(
                  'المجموع: ',
                  style: TextStyle(color: C.muted, fontSize: 12.5),
                ),
                Flexible(child: Money(total, size: 14)),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const EmptyState(
                    icon: Icons.mark_email_unread_outlined,
                    title: 'لا خطابات مطالبة',
                    hint:
                        'أنشئ خطاب مطالبة لجهة (فندق، شركة، جهة حكومية) بمستحقاتك — يدويًا أو من فواتير العميل.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 90),
                    itemCount: list.length,
                    itemBuilder: (_, i) => claimRow(context, list[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String v, String label) => Padding(
    padding: const EdgeInsets.only(left: 6),
    child: ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: _status == v,
      selectedColor: C.gold.withValues(alpha: 0.25),
      onSelected: (_) => setState(() => _status = v),
    ),
  );
}

/// لون حالة المطالبة
Color claimColor(ClaimStatus s) => switch (s) {
  ClaimStatus.draft => C.muted,
  ClaimStatus.sent => C.amber,
  ClaimStatus.paid => C.green,
};

/// صف خطاب — مشترك مع صفحة العميل
Widget claimRow(BuildContext context, Claim c) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: GoldCard(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ClaimForm(claim: c)),
    ),
    child: Row(
      children: [
        Plate.material(
          Icons.mark_email_read_outlined,
          color: PlateColor.blue,
          size: 36,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.recipient.isEmpty ? 'بدون جهة' : c.recipient,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${c.number} • ${fmtDate(c.date)} • ${c.items.length} بند',
                style: TextStyle(color: C.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Money(c.total, size: 14),
            const SizedBox(height: 3),
            StatusChip(
              claimStatusLabel[c.claimStatus]!,
              claimColor(c.claimStatus),
            ),
          ],
        ),
      ],
    ),
  ),
);

/// بدء خطاب جديد: يسأل «من فواتير عميل» أو «خطاب فارغ»
Future<void> newClaim(BuildContext context, {String? clientId}) async {
  final store = context.read<Store>();
  final client = clientId == null ? null : store.client(clientId);
  if (client != null) {
    final unpaid = store
        .clientInvoices(client.id)
        .where(
          (i) => i.countsInLedger && invoiceRemaining(i, store.payments) > 0,
        )
        .toList();
    if (unpaid.isNotEmpty) {
      final pick = await pickInvoicesForClaim(context, client, unpaid);
      if (pick == null || !context.mounted) return;
      final draft = pick.isEmpty
          ? Claim(clientId: client.id, recipient: client.name)
          : store.claimFromInvoices(client, pick);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ClaimForm(claim: draft, isNew: true)),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClaimForm(
          claim: Claim(clientId: client.id, recipient: client.name),
          isNew: true,
        ),
      ),
    );
    return;
  }
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const ClaimForm(isNew: true)),
  );
}

/// اختيار فواتير العميل غير المسدّدة لإدراجها كبنود. يعيد [] لـ«خطاب فارغ»، و null للإلغاء
Future<List<Invoice>?> pickInvoicesForClaim(
  BuildContext context,
  Client c,
  List<Invoice> invs,
) {
  final store = context.read<Store>();
  final sel = {for (final i in invs) i.id};
  return showModalBottomSheet<List<Invoice>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: C.bg2,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        final sum = invs
            .where((i) => sel.contains(i.id))
            .fold<int>(0, (s, i) => s + invoiceRemaining(i, store.payments));
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'المطالبة بمستحقات ${c.name}',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: C.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'اختر الفواتير غير المسدّدة التي تريد إدراجها كبنود (بمتبقيها). يمكنك تعديل البنود بعد ذلك.',
                  style: TextStyle(color: C.text3, fontSize: 12),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(ctx).height * 0.5,
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final i in invs)
                        CheckboxListTile(
                          value: sel.contains(i.id),
                          onChanged: (v) => set(
                            () => v == true ? sel.add(i.id) : sel.remove(i.id),
                          ),
                          title: Text(
                            '${i.number} • ${fmtDate(i.issueDate)}',
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                            ),
                          ),
                          subtitle: Text(
                            'متبقي ${fmtSAR(invoiceRemaining(i, store.payments))}${i.location.isNotEmpty ? ' • ${i.location}' : ''}',
                            style: TextStyle(color: C.text3, fontSize: 12),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                        ),
                    ],
                  ),
                ),
                const Divider(),
                Row(
                  children: [
                    Text('الإجمالي: ', style: TextStyle(color: C.text3)),
                    Money(sum, size: 15),
                  ],
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: sel.isEmpty
                      ? null
                      : () => Navigator.pop(
                          ctx,
                          invs.where((i) => sel.contains(i.id)).toList(),
                        ),
                  icon: const Icon(Icons.playlist_add_check_rounded),
                  label: Text('إنشاء الخطاب من ${sel.length} فاتورة'),
                ),
                const SizedBox(height: 6),
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, const <Invoice>[]),
                  child: const Text('خطاب فارغ (بنود يدوية)'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/* ============================================================
   النموذج المرن
   ============================================================ */
class ClaimForm extends StatefulWidget {
  final Claim? claim;
  final bool isNew;
  const ClaimForm({super.key, this.claim, this.isNew = false});
  @override
  State<ClaimForm> createState() => _ClaimFormState();
}

class _ClaimFormState extends State<ClaimForm> {
  final _f = GlobalKey<FormState>();
  late Claim c;
  late final Map<String, TextEditingController> t;
  final Map<String, (TextEditingController, TextEditingController)> _items = {};
  bool _texts = false;
  bool _dirty = false;

  bool get _isEdit => !widget.isNew && widget.claim != null;

  @override
  void initState() {
    super.initState();
    c = widget.claim?.copy() ?? Claim();
    t = {
      'recipient': TextEditingController(text: c.recipient),
      'addressLine': TextEditingController(text: c.addressLine),
      'honorific': TextEditingController(text: c.honorific),
      'subject': TextEditingController(text: c.subject),
      'eventName': TextEditingController(text: c.eventName),
      'greeting': TextEditingController(text: c.greeting),
      'body': TextEditingController(text: c.body),
      'closing': TextEditingController(text: c.closing),
      'signName': TextEditingController(text: c.signName),
      'signTitle': TextEditingController(text: c.signTitle),
      'notes': TextEditingController(text: c.notes),
    };
    for (final i in c.items) {
      _bindItem(i);
    }
    if (c.items.isEmpty) _addItem(silent: true);
  }

  void _bindItem(ClaimItem i) => _items[i.id] = (
    TextEditingController(text: i.desc),
    TextEditingController(
      text: i.amount == 0 ? '' : fmt(i.amount, trimZeros: true),
    ),
  );

  void _addItem({bool silent = false}) {
    final i = ClaimItem();
    c.items.add(i);
    _bindItem(i);
    if (!silent) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    for (final x in t.values) {
      x.dispose();
    }
    for (final p in _items.values) {
      p.$1.dispose();
      p.$2.dispose();
    }
    super.dispose();
  }

  /// نقل النصوص من الحقول إلى النموذج
  Claim _collect() {
    String v(String k) => t[k]!.text;
    c
      ..recipient = v('recipient').trim()
      ..addressLine = v('addressLine').trim()
      ..honorific = v('honorific').trim()
      ..subject = v('subject').trim()
      ..eventName = v('eventName').trim()
      ..greeting = v('greeting').trim()
      ..body = v('body').trim()
      ..closing = v('closing').trim()
      ..signName = v('signName').trim()
      ..signTitle = v('signTitle').trim()
      ..notes = v('notes').trim();
    for (final i in c.items) {
      final p = _items[i.id]!;
      i.desc = p.$1.text.trim();
      i.amount = toHalalasPositive(p.$2.text);
    }
    c.items.removeWhere((i) => i.desc.isEmpty && i.amount == 0);
    return c;
  }

  Future<bool> _save({bool quiet = false}) async {
    if (!_f.currentState!.validate()) return false;
    final store = context.read<Store>();
    final x = _collect();
    if (x.items.isEmpty) {
      toast(context, 'أضف بندًا واحدًا على الأقل', error: true);
      if (c.items.isEmpty) _addItem();
      return false;
    }
    await store.saveClaim(x);
    _dirty = false;
    if (mounted) {
      setState(() {});
      if (!quiet) toast(context, 'تم حفظ الخطاب ${x.number}');
    }
    return true;
  }

  Future<void> _preview() async {
    if (!await _save(quiet: true) || !mounted) return;
    final store = context.read<Store>();
    final x = c;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PreviewScreen(
          title: 'خطاب مطالبة ${x.number}',
          fileName: store.claimFileName(x),
          message: claimMessage(x, store.org),
          build: () async => (await DocPdf.create(store.org)).claim(x),
          kind: FileKind.claim,
          client: x.recipient,
        ),
      ),
    );
  }

  Future<void> _importInvoices() async {
    final store = context.read<Store>();
    final client = store.client(c.clientId);
    if (client == null) {
      toast(context, 'اختر عميلًا مسجّلًا أولًا لاستيراد فواتيره', error: true);
      return;
    }
    final unpaid = store
        .clientInvoices(client.id)
        .where(
          (i) =>
              i.countsInLedger &&
              invoiceRemaining(i, store.payments) > 0 &&
              !c.items.any((x) => x.invoiceId == i.id),
        )
        .toList();
    if (unpaid.isEmpty) {
      toast(context, 'لا فواتير غير مسدّدة إضافية لهذا العميل');
      return;
    }
    final pick = await pickInvoicesForClaim(context, client, unpaid);
    if (pick == null || pick.isEmpty || !mounted) return;
    final extra = store.claimFromInvoices(client, pick).items;
    setState(() {
      // إزالة البند الفارغ الافتراضي إن وُجد
      c.items.removeWhere(
        (i) =>
            (_items[i.id]?.$1.text.trim().isEmpty ?? true) &&
            (_items[i.id]?.$2.text.trim().isEmpty ?? true),
      );
      for (final i in extra) {
        c.items.add(i);
        _bindItem(i);
      }
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final total = c.items.fold<int>(
      0,
      (s, i) => s + toHalalasPositive(_items[i.id]?.$2.text),
    );
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (did, _) async {
        if (did) return;
        final leave = await confirm(
          context,
          'تجاهل التعديلات؟',
          'لديك تعديلات غير محفوظة على هذا الخطاب.',
          ok: 'تجاهل',
        );
        if (leave && context.mounted) {
          _dirty = false;
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          // رقم نمط التاريخ طويل (CLM-20260930-101500) — نصغّره بدل التجاوز
          title: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(_isEdit ? 'خطاب ${c.number}' : 'خطاب مطالبة جديد'),
          ),
          actions: [
            if (_isEdit)
              IconButton(
                tooltip: 'حذف',
                icon: Icon(Icons.delete_outline, color: C.red),
                onPressed: () async {
                  if (await confirm(
                    context,
                    'حذف الخطاب',
                    'سيُنقل الخطاب ${c.number} إلى سلة المحذوفات، ويمكن استرجاعه خلال ${Store.trashDays} يومًا.',
                  )) {
                    await store.deleteClaim(c.id);
                    _dirty = false;
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _save(),
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: const Text('حفظ'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _preview,
                    icon: const Icon(Icons.picture_as_pdf_rounded),
                    label: const Text('حفظ ومعاينة PDF'),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: Form(
          key: _f,
          onChanged: () => _dirty = true,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
            children: [
              // ── الجهة ──
              const SectionTitle('الجهة'),
              DropdownButtonFormField<String>(
                initialValue: store.clients.any((x) => x.id == c.clientId)
                    ? c.clientId
                    : '',
                decoration: InputDecoration(
                  labelText: 'العميل (اختياري)',
                  prefixIcon: Icon(
                    Icons.business_outlined,
                    color: C.muted,
                    size: 20,
                  ),
                ),
                dropdownColor: C.bg2,
                isExpanded: true,
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('جهة غير مسجّلة (اكتب الاسم)'),
                  ),
                  for (final x in store.clients)
                    DropdownMenuItem(
                      value: x.id,
                      child: Text(x.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() {
                  c.clientId = v ?? '';
                  final cl = store.client(c.clientId);
                  if (cl != null) t['recipient']!.text = cl.name;
                  _dirty = true;
                }),
              ),
              const SizedBox(height: 12),
              Field(
                'اسم الجهة *',
                controller: t['recipient'],
                icon: Icons.account_balance_outlined,
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'اكتب اسم الجهة' : null,
                onChanged: (_) => setState(() {}),
              ),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        final v = await pickDate(context, c.date);
                        if (v != null) setState(() => c..date = v);
                        _dirty = true;
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'تاريخ الخطاب',
                          prefixIcon: Icon(
                            Icons.event_outlined,
                            color: C.muted,
                            size: 20,
                          ),
                        ),
                        child: Text(
                          fmtDateH(
                            c.date,
                            hijri: context.read<Store>().org.hijriEnabled,
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: c.status,
                      decoration: const InputDecoration(labelText: 'الحالة'),
                      dropdownColor: C.bg2,
                      items: [
                        for (final s in ClaimStatus.values)
                          DropdownMenuItem(
                            value: s.name,
                            child: Text(claimStatusLabel[s]!),
                          ),
                      ],
                      onChanged: (v) => setState(() {
                        c.status = v ?? c.status;
                        _dirty = true;
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Field(
                'الموضوع',
                controller: t['subject'],
                icon: Icons.subject_rounded,
              ),
              Field(
                'اسم المناسبة / الأعمال',
                controller: t['eventName'],
                icon: Icons.celebration_outlined,
                hint: 'مثال: حفل اليوم الوطني — يظهر داخل نص الخطاب',
              ),

              // ── البنود ──
              SectionTitle(
                'البنود (${c.items.length})',
                action: c.clientId.isEmpty
                    ? null
                    : TextButton.icon(
                        onPressed: _importInvoices,
                        icon: Icon(
                          Icons.receipt_long_rounded,
                          size: 18,
                          color: C.gold,
                        ),
                        label: Text(
                          'من الفواتير',
                          style: TextStyle(
                            color: C.gold,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
              ),
              for (var k = 0; k < c.items.length; k++) _itemCard(k),
              OutlinedButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add_rounded),
                label: const Text('إضافة بند'),
              ),
              const SizedBox(height: 12),
              GoldCard(
                child: Row(
                  children: [
                    Text(
                      'إجمالي المستحق',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: C.text,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Money(total, size: 18)),
                  ],
                ),
              ),

              // ── عناصر الخطاب (مفاتيح) ──
              const SectionTitle('عناصر الخطاب'),
              GoldCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _switch(
                      'المبلغ كتابةً (التفقيط)',
                      'أسفل إجمالي المستحق',
                      c.showTafqit,
                      (v) => c.showTafqit = v,
                    ),
                    const Divider(height: 1),
                    _switch(
                      'عمود «المرجع» (رقم الفاتورة)',
                      c.hasRefs
                          ? 'يظهر للبنود المرتبطة بفواتير'
                          : 'لا بنود مرتبطة بفواتير حاليًا',
                      c.showRefColumn,
                      (v) => c.showRefColumn = v,
                    ),
                    const Divider(height: 1),
                    _switch(
                      'بيانات البنك في التذييل',
                      store.org.showBank
                          ? 'رقم الحساب و IBAN'
                          : 'مُعطّل من إعدادات الفواتير',
                      c.showBank,
                      (v) => c.showBank = v,
                    ),
                    const Divider(height: 1),
                    _switch(
                      'ختم المؤسسة',
                      store.org.showStamp
                          ? 'بجوار التوقيع'
                          : 'مُعطّل من إعدادات الفواتير',
                      c.showStamp,
                      (v) => c.showStamp = v,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Field(
                'ملاحظات أسفل الجدول (اختياري)',
                controller: t['notes'],
                minLines: 2,
                maxLines: null,
                icon: Icons.notes_outlined,
              ),

              // ── النصوص (مرنة) ──
              Expander(
                title: 'نص الخطاب والتوقيع',
                hint:
                    'المخاطبة، التحية، الفقرات، الخاتمة، الموقِّع — كلها قابلة للتعديل',
                icon: Icons.edit_note_rounded,
                open: _texts,
                onToggle: () => setState(() => _texts = !_texts),
                child: Column(
                  children: [
                    Field(
                      'سطر المخاطبة (فارغ = تلقائي)',
                      controller: t['addressLine'],
                      hint:
                          'السادة / ${t['recipient']!.text.isEmpty ? '…' : t['recipient']!.text} ${t['honorific']!.text}',
                    ),
                    Field(
                      'اللقب بعد اسم الجهة',
                      controller: t['honorific'],
                      hint: 'المحترمين / المحترم / حفظه الله',
                    ),
                    Field('التحية', controller: t['greeting']),
                    Field(
                      'نص الخطاب',
                      controller: t['body'],
                      minLines: 6,
                      maxLines: null,
                      hint: 'سطر فارغ = فقرة جديدة',
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        'متغيرات تُستبدل تلقائيًا: {org} اسم المؤسسة • {event} اسم المناسبة • {recipient} اسم الجهة',
                        style: TextStyle(color: C.text3, fontSize: 11.5),
                      ),
                    ),
                    Field(
                      'الخاتمة',
                      controller: t['closing'],
                      minLines: 2,
                      maxLines: null,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Field(
                            'اسم الموقِّع',
                            controller: t['signName'],
                            hint: store.org.name,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Field('الصفة', controller: t['signTitle']),
                        ),
                      ],
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: () => setState(() {
                          t['subject']!.text = ClaimDefaults.subject;
                          t['greeting']!.text = ClaimDefaults.greeting;
                          t['body']!.text = ClaimDefaults.body;
                          t['closing']!.text = ClaimDefaults.closing;
                          t['signTitle']!.text = ClaimDefaults.signTitle;
                          t['honorific']!.text = ClaimDefaults.honorific;
                          t['addressLine']!.text = '';
                          _dirty = true;
                        }),
                        icon: Icon(
                          Icons.restart_alt_rounded,
                          size: 18,
                          color: C.text3,
                        ),
                        label: Text(
                          'استعادة النص الافتراضي',
                          style: TextStyle(color: C.text3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _itemCard(int k) {
    final i = c.items[k];
    final p = _items[i.id]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GoldCard(
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 0),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: C.gold.withValues(alpha: 0.18),
                  child: Text(
                    '${k + 1}',
                    style: TextStyle(
                      color: C.goldInk,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Flexible: رقم فاتورة بنمط التاريخ (INV-20260930-101500) طويل — يُقصّ بدل التجاوز
                if (i.invoiceNumber.isNotEmpty)
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: C.blue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        i.invoiceNumber,
                        textDirection: TextDirection.ltr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: C.blue,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                const Spacer(),
                IconButton(
                  tooltip: 'حذف البند',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close_rounded, color: C.text3, size: 20),
                  onPressed: () => setState(() {
                    c.items.removeAt(k);
                    _dirty = true;
                  }),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Field(
                'بيان الخدمة',
                controller: p.$1,
                minLines: 2,
                maxLines: null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Field(
                'المبلغ (ر.س)',
                controller: p.$2,
                type: const TextInputType.numberWithOptions(decimal: true),
                icon: Icons.payments_outlined,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _switch(String title, String sub, bool v, void Function(bool) set) =>
      SwitchListTile(
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13.5,
            color: C.text,
          ),
        ),
        subtitle: Text(sub, style: TextStyle(color: C.text3, fontSize: 11.5)),
        value: v,
        onChanged: (x) => setState(() {
          set(x);
          _dirty = true;
        }),
      );
}

/// رسالة واتساب المرافقة للخطاب
String claimMessage(Claim c, Org org) => [
  'السلام عليكم ورحمة الله وبركاته',
  if (c.recipient.isNotEmpty)
    '${c.salutation.isNotEmpty ? c.salutation : c.recipient}،',
  '',
  'مرفق خطاب مطالبة رقم *${c.number}* من *${org.name}*',
  if (c.subject.isNotEmpty) 'الموضوع: ${c.subject}',
  'إجمالي المستحق: *${fmtSAR(c.total)}*',
  if (org.showBank && org.iban.isNotEmpty) ...[
    '',
    'للتحويل: ${org.bankName}',
    'IBAN: ${org.iban}',
  ],
  '',
  'شاكرين تعاونكم — ${org.name}',
  if (org.phone.isNotEmpty) org.phone,
].join('\n');
