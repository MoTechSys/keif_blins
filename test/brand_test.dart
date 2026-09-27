import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keif_diafa/core/brand.dart';
import 'package:keif_diafa/core/file_service.dart';
import 'package:keif_diafa/core/models.dart';
import 'package:keif_diafa/pdf/documents.dart';

/// النسختان منفصلتان: الاسم، قاعدة البيانات، المجلد، النسخ، الشعار والمؤسسة الافتراضية
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => Brand.debugOverride = null);

  test('keif is the default brand; osool is fully separate', () {
    expect(Brand.current.id, 'keif');
    const k = Brand.keif, o = Brand.osool;
    expect(k.dbName, isNot(o.dbName));
    expect(k.folderName, isNot(o.folderName));
    expect(k.backupPrefix, isNot(o.backupPrefix));
    expect(k.backupAppTag, 'keif-diafa'); // متوافق مع نسخ الإصدارات السابقة
    expect(o.pdfLogo, 'assets/brand/osool/pdf_logo.png');
  });

  test(
    'Org defaults follow the brand; empty official data is not invented',
    () {
      Brand.debugOverride = Brand.osool;
      final o = Org();
      expect(o.name, 'مؤسسة أصول الضيافة');
      expect(o.cr, isEmpty);
      expect(o.iban, isEmpty);
      expect(o.phone, '0568997316');
      expect(o.website, 'asoulaldiafa.com');
      expect(o.invoiceTerms, contains('أصول الضيافة'));
      expect(FileService.appFolder, 'أصول الضيافة');
      Brand.debugOverride = Brand.keif;
      expect(Org().cr, '4030499689');
      expect(FileService.appFolder, 'كيف الضيافة');
    },
  );

  test('osool PDFs render with osool identity (invoice + claim)', () async {
    Brand.debugOverride = Brand.osool;
    final org = Org();
    final pdf = await DocPdf.create(org);
    final inv = Invoice(
      number: 'INV-0001',
      clientName: 'عميل',
      items: [LineItem(desc: 'ضيافة', unitPrice: 100000)],
    );
    final a = await pdf.invoice(inv, []);
    final b = await pdf.claim(
      Claim(
        number: 'CLM-0001',
        recipient: 'جهة',
        items: [ClaimItem(desc: 'بند', amount: 100000)],
      ),
    );
    final dir = Directory('build/test_pdfs')..createSync(recursive: true);
    File('${dir.path}/osool_invoice.pdf').writeAsBytesSync(a);
    File('${dir.path}/osool_claim.pdf').writeAsBytesSync(b);
    expect(a.length, greaterThan(10000));
  });

  test('file kinds include claims folder', () {
    expect(
      FileKind.values.map((k) => k.folder),
      containsAll([
        'الفواتير',
        'عروض الأسعار',
        'خطابات المطالبة',
        'كشوف الحساب',
        'سندات القبض',
        'النسخ الاحتياطية',
      ]),
    );
    expect(FileService.isAutoBackup('keif-auto-2026-09-27.json'), isTrue);
    expect(FileService.isAutoBackup('auto-2026-09-27.json'), isTrue);
    expect(
      FileService.isAutoBackup('keif-backup-2026-09-27_10-00.json'),
      isFalse,
    );
  });
}
