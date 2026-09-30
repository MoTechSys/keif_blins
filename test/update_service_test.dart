// التحديث داخل التطبيق (ADR-0005): قراءة update.json، مقارنة versionCode بالمعمارية،
// التنزيل مع تحقق SHA-256 إلزامي، ورفض الملف التالف
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:keif_diafa/core/brand.dart';
import 'package:keif_diafa/core/update_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final String tmp;
  _FakePathProvider(this.tmp);
  @override
  Future<String?> getTemporaryPath() async => tmp;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  setUpAll(() {
    Brand.debugOverride = Brand.keif;
    tmp = Directory.systemTemp.createTempSync('upd_');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
  });
  tearDownAll(() {
    Brand.debugOverride = null;
    UpdateService.debugInvoke = null;
    UpdateService.client = http.Client();
  });

  final apkBytes = List<int>.generate(50000, (i) => (i * 7) & 0xff);
  final apkHash = sha256.convert(apkBytes).toString();

  Map<String, dynamic> manifest({int arm64 = 4600, int armv7 = 3600}) => {
    'version': '2.6.0',
    'build': 2600,
    'versionCodes': {'arm64': arm64, 'armv7': armv7},
    'apks': {
      'arm64': {
        'url':
            'https://github.com/MoTechSys/diafa-apps/releases/download/v2.6.0/keif-aldiafa-v2.6.0-arm64.apk',
        'sha256': apkHash,
        'size': apkBytes.length,
      },
      'armv7': {
        'url':
            'https://github.com/MoTechSys/diafa-apps/releases/download/v2.6.0/keif-aldiafa-v2.6.0-armv7.apk',
        'sha256': apkHash,
        'size': apkBytes.length,
      },
    },
    'notes': 'ما الجديد',
    'publishedAt': '2026-09-30',
  };

  InstalledInfo inst(String abi, int code) => InstalledInfo(
    versionCode: code,
    versionName: '2.5.0',
    abi: abi,
    canInstall: true,
    sdkInt: 34,
  );

  group('قراءة update.json', () {
    test('ملف صالح', () {
      final u = UpdateInfo.tryParse(manifest());
      expect(u, isNotNull);
      expect(u!.version, '2.6.0');
      expect(u.versionCodes['arm64'], 4600);
      expect(u.apks['armv7']!.url.path, endsWith('-armv7.apk'));
    });
    test('ملف ناقص/تالف ⇐ null (لا تحديث خاطئ)', () {
      expect(UpdateInfo.tryParse(null), isNull);
      expect(UpdateInfo.tryParse('x'), isNull);
      expect(UpdateInfo.tryParse({'version': '2.6.0'}), isNull);
      final bad = manifest();
      (bad['apks'] as Map)['arm64'] = {'url': 'x', 'sha256': 'short'};
      final u = UpdateInfo.tryParse(bad);
      expect(
        u!.apks.containsKey('arm64'),
        isFalse,
        reason: 'بصمة غير صالحة تُرفض',
      );
    });
  });

  group('تحديد المعمارية من الـ APK المثبّت', () {
    test('nativeLibraryDir يغلب معمارية الجهاز', () {
      expect(
        UpdateService.abiKey('/data/app/x/lib/arm64', 'arm64-v8a'),
        'arm64',
      );
      expect(
        UpdateService.abiKey('/data/app/x/lib/arm', 'arm64-v8a'),
        'armv7',
        reason: 'armv7 مثبّت على جهاز arm64 ⇐ نحدّث بـ armv7',
      );
      expect(UpdateService.abiKey('', 'armeabi-v7a'), 'armv7');
      expect(UpdateService.abiKey('', 'arm64-v8a'), 'arm64');
      expect(UpdateService.abiKey('', ''), '');
    });
  });

  group('المقارنة', () {
    test('أحدث ⇐ متاح؛ نفس الرقم أو أعلى ⇐ محدّث', () {
      final info = UpdateInfo.tryParse(manifest());
      expect(
        UpdateService.compare(info, inst('arm64', 4500)).available,
        isTrue,
      );
      expect(
        UpdateService.compare(info, inst('arm64', 4600)).status,
        UpdateStatus.upToDate,
      );
      expect(
        UpdateService.compare(info, inst('arm64', 4700)).status,
        UpdateStatus.upToDate,
      );
      expect(
        UpdateService.compare(info, inst('armv7', 3500)).available,
        isTrue,
      );
    });
    test('معمارية غير منشورة أو مجهولة ⇐ unsupported', () {
      final info = UpdateInfo.tryParse(manifest());
      expect(
        UpdateService.compare(info, inst('x86_64', 1)).status,
        UpdateStatus.unsupported,
      );
      expect(
        UpdateService.compare(info, inst('', 1)).status,
        UpdateStatus.unsupported,
      );
      expect(
        UpdateService.compare(null, inst('arm64', 1)).status,
        UpdateStatus.invalid,
      );
    });
    test('الـ APK المختار يطابق معمارية المثبّت', () {
      final r = UpdateService.compare(
        UpdateInfo.tryParse(manifest()),
        inst('armv7', 1),
      );
      expect(r.apk!.url.path, endsWith('-armv7.apk'));
    });
    test('فاصل الفحص التلقائي 24 ساعة', () {
      final now = DateTime(2026, 9, 30, 12);
      expect(UpdateService.isCheckDue(null, now: now), isTrue);
      expect(
        UpdateService.isCheckDue(
          now.subtract(const Duration(hours: 23)).toIso8601String(),
          now: now,
        ),
        isFalse,
      );
      expect(
        UpdateService.isCheckDue(
          now.subtract(const Duration(hours: 25)).toIso8601String(),
          now: now,
        ),
        isTrue,
      );
    });
  });

  group('الجلب من GitHub (API ثم الخام)', () {
    test('API 200 base64', () async {
      UpdateService.client = MockClient((req) async {
        if (req.url.host == 'api.github.com') {
          expect(req.url.path, contains(Uri.encodeComponent('كيف الضيافة')));
          return http.Response(
            jsonEncode({
              'content': base64Encode(utf8.encode(jsonEncode(manifest()))),
            }),
            200,
          );
        }
        return http.Response('', 500);
      });
      final m = await UpdateService.fetchRemote();
      expect(m!['version'], '2.6.0');
    });
    test('API فاشل ⇐ الخام', () async {
      UpdateService.client = MockClient((req) async {
        if (req.url.host == 'api.github.com') return http.Response('', 403);
        return http.Response.bytes(utf8.encode(jsonEncode(manifest())), 200);
      });
      expect((await UpdateService.fetchRemote())!['build'], 2600);
    });
    test('لا شبكة ⇐ null ⇐ check() = offline بلا استثناء', () async {
      UpdateService.client = MockClient(
        (_) async => throw const SocketException('x'),
      );
      UpdateService.debugInvoke = (m, [a]) async => {
        'versionCode': 4500,
        'versionName': '2.5.0',
        'abi': 'arm64-v8a',
        'nativeLibDir': '/lib/arm64',
        'canInstall': true,
        'sdkInt': 34,
      };
      final r = await UpdateService().check();
      expect(r.status, UpdateStatus.offline);
      expect(r.installed!.abi, 'arm64');
    });
    test('check() كامل: تحديث متاح', () async {
      UpdateService.client = MockClient(
        (req) async =>
            http.Response.bytes(utf8.encode(jsonEncode(manifest())), 200),
      );
      UpdateService.debugInvoke = (m, [a]) async => {
        'versionCode': 4500,
        'versionName': '2.5.0',
        'abi': 'arm64-v8a',
        'nativeLibDir': '/lib/arm64',
        'canInstall': false,
        'sdkInt': 34,
      };
      final s = UpdateService();
      final r = await s.check();
      expect(r.available, isTrue);
      expect(r.apk!.url.path, endsWith('-arm64.apk'));
      expect(s.last, same(r));
    });
  });

  group('التنزيل والتحقق', () {
    test('ملف سليم ⇐ يُحفظ في cache/updates ويطابق البصمة', () async {
      UpdateService.client = MockClient(
        (req) async => http.Response.bytes(apkBytes, 200),
      );
      final s = UpdateService();
      final progress = <double>[];
      s.progress.addListener(() {
        if (s.progress.value != null) progress.add(s.progress.value!);
      });
      final apk = UpdateInfo.tryParse(manifest())!.apks['arm64']!;
      final p = await s.download(apk);
      expect(p, startsWith('${tmp.path}/updates/'));
      expect(p, endsWith('keif-aldiafa-v2.6.0-arm64.apk'));
      expect(await UpdateService.sha256File(File(p)), apkHash);
      expect(progress.last, 1.0);
      expect(s.progress.value, isNull);
      // إعادة التنزيل ⇐ يستخدم الملف السليم الموجود (لا طلب شبكة)
      UpdateService.client = MockClient((_) async => http.Response('', 500));
      expect(await s.download(apk), p);
    });

    test('ملف لا يطابق البصمة ⇐ يُحذف ويُرفض', () async {
      final tampered = [...apkBytes]..[100] ^= 0xff;
      UpdateService.client = MockClient(
        (req) async => http.Response.bytes(tampered, 200),
      );
      final s = UpdateService();
      final apk = UpdateInfo.tryParse(manifest())!.apks['armv7']!;
      await expectLater(
        s.download(apk),
        throwsA(
          isA<UpdateException>().having(
            (e) => e.message,
            'msg',
            contains('لا يطابق'),
          ),
        ),
      );
      expect(
        File('${tmp.path}/updates/keif-aldiafa-v2.6.0-armv7.apk').existsSync(),
        isFalse,
      );
    });

    test('HTTP 404 ⇐ استثناء واضح ولا ملف', () async {
      UpdateService.client = MockClient((req) async => http.Response('', 404));
      final apk = UpdateApk(
        url: Uri.parse('https://x/y/none.apk'),
        sha256: apkHash,
      );
      await expectLater(
        UpdateService().download(apk),
        throwsA(isA<UpdateException>()),
      );
      expect(File('${tmp.path}/updates/none.apk').existsSync(), isFalse);
    });

    test('cleanup يحذف الملفات المنزَّلة', () async {
      File('${tmp.path}/updates/old.apk').writeAsBytesSync([1, 2, 3]);
      await UpdateService.cleanup();
      expect(Directory('${tmp.path}/updates').listSync(), isEmpty);
    });
  });
}
