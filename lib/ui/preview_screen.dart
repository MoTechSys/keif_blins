/// preview_screen.dart — معاينة PDF + طباعة + مشاركة | كيف الضيافة
library;


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../core/share_service.dart';
import 'theme.dart';
import 'widgets.dart';

class PreviewScreen extends StatefulWidget {
  final String title;
  final String fileName;
  final String message;
  final Future<Uint8List> Function() build;
  const PreviewScreen({super.key, required this.title, required this.fileName, required this.message, required this.build});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  Uint8List? _bytes;
  Object? _err;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _gen();
  }

  Future<void> _gen() async {
    try {
      final b = await widget.build();
      if (mounted) setState(() => _bytes = b);
    } catch (e) {
      if (mounted) setState(() => _err = e);
    }
  }

  Future<void> _run(Future<void> Function() f) async {
    if (_bytes == null || _busy) return;
    setState(() => _busy = true);
    try {
      await f();
    } catch (e) {
      if (mounted) toast(context, 'تعذّر تنفيذ العملية: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'نسخ الرسالة',
            icon: const Icon(Icons.copy_rounded),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: widget.message));
              if (context.mounted) toast(context, 'تم نسخ نص الرسالة');
            },
          ),
        ],
      ),
      body: _err != null
          ? EmptyState(icon: Icons.error_outline, title: 'تعذّر إنشاء المستند', hint: '$_err')
          : _bytes == null
              ? const Center(child: CircularProgressIndicator())
              : Container(
                  color: const Color(0xFF0A1128),
                  child: PdfPreview(
                    build: (_) async => _bytes!,
                    useActions: false,
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    canDebug: false,
                    allowPrinting: false,
                    allowSharing: false,
                    pdfPreviewPageDecoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 18, offset: const Offset(0, 8))],
                    ),
                    previewPageMargin: const EdgeInsets.fromLTRB(10, 12, 10, 12),
                    scrollViewDecoration: const BoxDecoration(color: Color(0xFF0A1128)),
                    loadingWidget: const Center(child: CircularProgressIndicator()),
                  ),
                ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          decoration: const BoxDecoration(color: C.bg2, border: Border(top: BorderSide(color: C.line))),
          child: Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _bytes == null || _busy ? null : () => _run(() => ShareService.sharePdf(_bytes!, widget.fileName, widget.message)),
                icon: const Icon(Icons.share_rounded),
                label: const Text('مشاركة PDF + رسالة'),
              ),
            ),
            const SizedBox(width: 8),
            _ActionBtn(
              icon: Icons.chat_rounded,
              tooltip: 'إرسال الرسالة فقط',
              onTap: _bytes == null || _busy ? null : () => _run(() => ShareService.shareText(widget.message, subject: widget.title)),
            ),
            const SizedBox(width: 8),
            _ActionBtn(
              icon: Icons.print_rounded,
              tooltip: 'طباعة / حفظ',
              onTap: _bytes == null || _busy ? null : () => _run(() => ShareService.print(_bytes!, widget.fileName)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  const _ActionBtn({required this.icon, required this.tooltip, this.onTap});
  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: C.card,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: C.gold)),
              child: Icon(icon, color: onTap == null ? C.muted : C.gold),
            ),
          ),
        ),
      );
}
