/// share_service.dart — الطباعة والمشاركة (PDF + رسالة) | كيف الضيافة
library;


import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'models.dart';
import 'money.dart';

class ShareService {
  /// نص الرسالة المرافقة للفاتورة/عرض السعر
  static String invoiceMessage(Invoice inv, Org org, List<Payment> payments) {
    final t = inv.totals;
    final b = StringBuffer();
    if (inv.isQuote) {
      b
        ..writeln('السلام عليكم ورحمة الله وبركاته')
        ..writeln('${inv.clientName} الكريم،')
        ..writeln()
        ..writeln('يسعدنا في *${org.name}* تقديم عرض السعر رقم *${inv.number}*')
        ..writeln('التاريخ: ${fmtDate(inv.issueDate)}');
      if (inv.eventDate.isNotEmpty) b.writeln('المناسبة: ${fmtDate(inv.eventDate)}${inv.location.isNotEmpty ? ' — ${inv.location}' : ''}');
      b.writeln('إجمالي العرض: *${fmtSAR(t.total)}*${t.vatRateBp > 0 ? ' (شامل الضريبة)' : ''}');
      if (inv.validUntil.isNotEmpty) b.writeln('العرض ساري حتى: ${fmtDate(inv.validUntil)}');
      b
        ..writeln()
        ..writeln('نتشرّف بخدمتكم، وبانتظار تأكيدكم.')
        ..writeln('${org.phone} | ${org.website}');
    } else {
      final paid = invoicePaid(inv, payments);
      final rem = t.total - paid;
      b
        ..writeln('السلام عليكم ورحمة الله وبركاته')
        ..writeln('${inv.clientName} الكريم،')
        ..writeln()
        ..writeln('مرفق فاتورة رقم *${inv.number}* من *${org.name}*')
        ..writeln('التاريخ: ${fmtDate(inv.issueDate)}');
      if (inv.eventDate.isNotEmpty) b.writeln('المناسبة: ${fmtDate(inv.eventDate)}${inv.location.isNotEmpty ? ' — ${inv.location}' : ''}');
      b.writeln('الإجمالي: *${fmtSAR(t.total)}*');
      if (paid > 0) b.writeln('المدفوع: ${fmtSAR(paid)}');
      if (rem > 0) {
        b
          ..writeln('المتبقي: *${fmtSAR(rem)}*')
          ..writeln()
          ..writeln('للتحويل: ${org.bankName}')
          ..writeln('IBAN: ${org.iban}');
      } else {
        b
          ..writeln()
          ..writeln('الفاتورة مسدَّدة بالكامل — شكرًا لكم.');
      }
      b
        ..writeln()
        ..writeln('شكرًا لثقتكم بنا.')
        ..writeln('${org.phone} | ${org.website}');
    }
    return b.toString().trim();
  }

  static String statementMessage(Statement s, Org org) {
    final b = StringBuffer()
      ..writeln('السلام عليكم ورحمة الله وبركاته')
      ..writeln('${s.client.name} الكريم،')
      ..writeln()
      ..writeln('مرفق كشف حساب رقم *${s.number}* من *${org.name}*')
      ..writeln('تاريخ الإصدار: ${fmtDate(s.issueDate)}')
      ..writeln('عدد الفواتير: ${s.count}');
    if (s.opening != 0) b.writeln('رصيد سابق: ${fmtSAR(s.opening)}');
    b
      ..writeln('فواتير الفترة: ${fmtSAR(s.billed)}')
      ..writeln('المدفوع: ${fmtSAR(s.paid)}');
    if (s.closing > 0) {
      b
        ..writeln('الرصيد المستحق: *${fmtSAR(s.closing)}*')
        ..writeln()
        ..writeln('للتحويل: ${org.bankName}')
        ..writeln('IBAN: ${org.iban}');
    } else if (s.closing < 0) {
      b.writeln('رصيد دائن لصالحكم: *${fmtSAR(-s.closing)}*');
    } else {
      b.writeln('الحساب مسدَّد بالكامل — شكرًا لكم.');
    }
    b
      ..writeln()
      ..writeln('${org.phone} | ${org.website}');
    return b.toString().trim();
  }

  static String receiptMessage(Payment p, Client c, Org org) => [
        'السلام عليكم ورحمة الله وبركاته',
        '${c.name} الكريم،',
        '',
        'نفيدكم باستلام مبلغ *${fmtSAR(p.amount)}* بتاريخ ${fmtDate(p.date)} (${p.method}).',
        'مرفق سند القبض رقم *${p.receiptNumber}*.',
        '',
        'شكرًا لكم — ${org.name}',
        '${org.phone} | ${org.website}',
      ].join('\n');

  /// مشاركة ملف PDF مع رسالة
  static Future<void> sharePdf(Uint8List bytes, String fileName, String message) async {
    if (kIsWeb) {
      await Printing.sharePdf(bytes: bytes, filename: fileName);
      return;
    }
    await Share.shareXFiles(
      [XFile.fromData(bytes, mimeType: 'application/pdf', name: fileName)],
      text: message,
      subject: fileName.replaceAll('.pdf', ''),
    );
  }

  /// مشاركة الرسالة النصية فقط (واتساب وغيره)
  static Future<void> shareText(String message, {String? subject}) =>
      Share.share(message, subject: subject);

  /// طباعة / حفظ PDF عبر نافذة النظام
  static Future<void> print(Uint8List bytes, String name) =>
      Printing.layoutPdf(onLayout: (_) async => bytes, name: name);

  static String safeName(String s) =>
      s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-').replaceAll(' ', '_');
}
