// تدقيق حيّ (وسم audit): UpdateService الحقيقي ضد GitHub الفعلي للعلامتين —
// يقرأ update.json المنشور، ويتحقق أن محاكاة تطبيق 2.5.0 ترى التحديث، وأن التنزيل الفعلي
// يمر من تحقق SHA-256 (أي أن الملف المنشور والبصمة المنشورة متطابقان).
//   flutter test test/update_live_audit_test.dart
@Tags(['audit'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:keif_diafa/core/brand.dart';
import 'package:keif_diafa/core/update_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _P extends PathProviderPlatform with MockPlatformInterfaceMixin {
  final String t;
  _P(this.t);
  @override
  Future<String?> getTemporaryPath() async => t;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  setUpAll(() {
    HttpOverrides.global = null; // flutter_test يحجب الشبكة افتراضيًا
    UpdateService.client = http.Client();
    tmp = Directory.systemTemp.createTempSync('upd_live_');
    PathProviderPlatform.instance = _P(tmp.path);
  });
  tearDownAll(() => Brand.debugOverride = null);

  for (final b in Brand.all) {
    for (final abi in ['arm64', 'armv7']) {
      test(
        '${b.id}/$abi: update.json منشور، 2.5.0 يرى 2.6.0، التنزيل يطابق SHA-256',
        () async {
          Brand.debugOverride = b;
          final remote = await UpdateService.fetchRemote();
          expect(
            remote,
            isNotNull,
            reason: 'update.json غير موجود/غير قابل للقراءة',
          );
          final info = UpdateInfo.tryParse(remote);
          expect(info, isNotNull);
          expect(info!.version, '2.6.0');
          // تطبيق 2.5.0 مثبّت بهذه المعمارية
          final old = InstalledInfo(
            versionCode: abi == 'arm64' ? 4500 : 3500,
            versionName: '2.5.0',
            abi: abi,
            canInstall: true,
            sdkInt: 34,
          );
          final r = UpdateService.compare(info, old);
          expect(r.available, isTrue, reason: r.message);
          // 2.6.0 مثبّت ⇐ محدّث
          expect(
            UpdateService.compare(
              info,
              InstalledInfo(
                versionCode: abi == 'arm64' ? 4600 : 3600,
                versionName: '2.6.0',
                abi: abi,
                canInstall: true,
                sdkInt: 34,
              ),
            ).status,
            UpdateStatus.upToDate,
          );
          // التنزيل الفعلي + التحقق (يرمي إن لم تطابق البصمة)
          final path = await UpdateService().download(
            r.apk!,
            fileName: '${b.id}-$abi.apk',
          );
          expect(File(path).lengthSync(), r.apk!.size);
          expect(await UpdateService.sha256File(File(path)), r.apk!.sha256);
        },
        timeout: const Timeout(Duration(minutes: 3)),
      );
    }
  }
}
