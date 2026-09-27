/// brand.dart — هوية النسخة (كيف الضيافة / أصول الضيافة) | نظام الفواتير
///
/// نفس الكود يُبنى نسختين منفصلتين تمامًا (تطبيقان مستقلّان على الهاتف):
///   flutter build apk --flavor keif  --dart-define=BRAND=keif
///   flutter build apk --flavor osool --dart-define=BRAND=osool
///
/// كل نسخة لها: معرّف حزمة مستقل، اسم وأيقونة، قاعدة بيانات مستقلة، مجلد هاتف مستقل،
/// مجلد Google Drive مستقل، شعار وختم وبيانات مؤسسة افتراضية مستقلة. لا تختلط البيانات أبدًا.
library;

import 'package:flutter/services.dart' show appFlavor;

class Brand {
  /// المعرّف الداخلي (keif / osool)
  final String id;

  /// اسم التطبيق (يظهر في الواجهة وعلى الهاتف)
  final String appName;

  /// اسم المجلد الرئيسي في ذاكرة الهاتف الداخلية
  final String folderName;

  /// بادئة ملفات النسخ الاحتياطي و«app» داخل ملف النسخة
  final String backupPrefix;

  /// اسم قاعدة البيانات وصناديق Hive (مستقل لكل نسخة)
  final String dbName;

  /// بيانات المؤسسة الافتراضية (قابلة للتعديل من الإعدادات)
  final String orgName,
      orgNameEn,
      cr,
      website,
      email,
      phone,
      bankName,
      bankAccount,
      iban,
      city;

  /// شعارات الواجهة و PDF
  final String logo, logoLight, stamp, pdfLogo, pdfStamp;

  const Brand._({
    required this.id,
    required this.appName,
    required this.folderName,
    required this.backupPrefix,
    required this.dbName,
    required this.orgName,
    required this.orgNameEn,
    required this.cr,
    required this.website,
    required this.email,
    required this.phone,
    required this.bankName,
    required this.bankAccount,
    required this.iban,
    required this.city,
  }) : logo = 'assets/brand/$id/logo.png',
       logoLight = 'assets/brand/$id/logo_light.png',
       stamp = 'assets/brand/$id/stamp.png',
       pdfLogo = 'assets/brand/$id/pdf_logo.png',
       pdfStamp = 'assets/brand/$id/pdf_stamp.png';

  static const keif = Brand._(
    id: 'keif',
    appName: 'كيف الضيافة',
    folderName: 'كيف الضيافة',
    backupPrefix: 'keif',
    dbName: 'keif_diafa',
    orgName: 'مؤسسة كيف الضيافة',
    orgNameEn: 'KEIF ALDIAFA EST.',
    cr: '4030499689',
    website: 'keifaldiafa.com',
    email: 'info@keifaldiafa.com',
    phone: '0508252134',
    bankName: 'البنك الأهلي السعودي',
    bankAccount: '01400017244409',
    iban: 'SA7310000001400017244409',
    city: 'جدة',
  );

  /// أصول الضيافة — البيانات من الموقع الرسمي asoulaldiafa.com (الشعار، البريد، الجوال).
  /// السجل التجاري والبنك غير منشورة في الموقع: تُدخل من «بيانات المؤسسة» ولا نخترعها.
  static const osool = Brand._(
    id: 'osool',
    appName: 'أصول الضيافة',
    folderName: 'أصول الضيافة',
    backupPrefix: 'osool',
    dbName: 'osool_diafa',
    orgName: 'مؤسسة أصول الضيافة',
    orgNameEn: 'ASOUL ALDIAFA EST.',
    cr: '',
    website: 'asoulaldiafa.com',
    email: 'asoulaldiafa@gmail.com',
    phone: '0568997316',
    bankName: '',
    bankAccount: '',
    iban: '',
    city: 'جدة',
  );

  static const all = [keif, osool];

  static Brand? _override;

  /// الهوية الحالية: --dart-define=BRAND ثم --flavor ثم كيف الضيافة
  static Brand get current {
    if (_override != null) return _override!;
    const env = String.fromEnvironment('BRAND');
    final key = env.isNotEmpty ? env : (appFlavor ?? 'keif');
    return all.firstWhere((b) => b.id == key, orElse: () => keif);
  }

  /// للاختبارات فقط
  static set debugOverride(Brand? b) => _override = b;

  /// اسم «app» داخل ملف النسخة الاحتياطية — للتحقق من أن النسخة تخص هذا التطبيق
  String get backupAppTag => '$backupPrefix-diafa';
}
