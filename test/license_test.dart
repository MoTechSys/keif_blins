// القفل عن بُعد: كل حالات ملف التحكم + فصل العلامتين
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:keif_diafa/core/brand.dart';
import 'package:keif_diafa/core/license_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => Brand.debugOverride = null);

  final hits = <Uri>[];
  http.Client fake({
    bool? active,
    String code = 'KEIF-7310',
    bool deleted = false,
    bool apiLimited = false,
    String? raw,
  }) => MockClient((req) async {
    hits.add(req.url);
    if (deleted) return http.Response('Not Found', 404);
    final json =
        raw ?? jsonEncode({'active': active, 'code': code, 'message': 'موقوف'});
    if (req.url.host == 'api.github.com') {
      if (apiLimited) return http.Response('rate limited', 403);
      return http.Response(
        jsonEncode({'content': base64Encode(utf8.encode(json))}),
        200,
      );
    }
    return http.Response.bytes(utf8.encode(json), 200);
  });

  test('active=true يفتح فورًا حتى لو كان مقفولًا سابقًا', () async {
    SharedPreferences.setMockInitialValues({'lic_keif_blocked': true});
    LicenseService.client = fake(active: true);
    expect((await LicenseService.check()).allowed, isTrue);
  });

  test('active=false يقفل؛ كود خاطئ يُرفض، الصحيح يُقبل ويُحفظ', () async {
    SharedPreferences.setMockInitialValues({});
    LicenseService.client = fake(active: false);
    var st = await LicenseService.check();
    expect(st.allowed, isFalse);
    expect(st.message, 'موقوف');
    expect(await LicenseService.activate('WRONG'), isFalse);
    expect(await LicenseService.activate('keif-7310'), isTrue);
    expect((await LicenseService.check()).allowed, isTrue); // يتذكر الكود
    LicenseService.client = fake(active: false, code: 'NEW-1');
    expect((await LicenseService.check()).allowed, isFalse); // تغيير الكود يقفل
    LicenseService.client = fake(active: true, code: 'NEW-1');
    expect((await LicenseService.check()).allowed, isTrue);
  });

  test('حذف الملف (404) => قفل نهائي ولا يُقبل أي كود', () async {
    SharedPreferences.setMockInitialValues({
      'lic_keif_activated_code': 'KEIF-7310',
      'lic_keif_seen': true,
    });
    LicenseService.client = fake(deleted: true);
    final st = await LicenseService.check();
    expect(st.allowed, isFalse);
    expect(st.codeAccepted, isFalse);
    expect(await LicenseService.activate('KEIF-7310'), isFalse);
  });

  test('ملف لم يُرفع بعد (404 ولم يُرَ قط) لا يقفل', () async {
    SharedPreferences.setMockInitialValues({});
    LicenseService.client = fake(deleted: true);
    expect((await LicenseService.check()).allowed, isTrue);
  });

  test('بلا إنترنت => آخر حالة معروفة', () async {
    LicenseService.client = MockClient((_) async => throw Exception('no net'));
    SharedPreferences.setMockInitialValues({});
    var st = await LicenseService.check();
    expect(st.allowed, isTrue); // أول تشغيل بلا إنترنت مسموح
    expect(st.offline, isTrue);
    SharedPreferences.setMockInitialValues({'lic_keif_blocked': true});
    st = await LicenseService.check();
    expect(st.allowed, isFalse); // يبقى مقفولًا بلا إنترنت
  });

  test('حد طلبات API => يرجع للملف الخام', () async {
    SharedPreferences.setMockInitialValues({});
    hits.clear();
    LicenseService.client = fake(active: false, apiLimited: true);
    expect((await LicenseService.check()).allowed, isFalse);
    expect(hits.any((u) => u.host == 'raw.githubusercontent.com'), isTrue);
  });

  test('ملف تالف لا يقفل خطأً (يُعامل كانقطاع)', () async {
    SharedPreferences.setMockInitialValues({});
    LicenseService.client = fake(raw: '{broken');
    final st = await LicenseService.check();
    expect(st.allowed, isTrue);
    expect(st.offline, isTrue);
  });

  test('كل تطبيق يقرأ ملفه ويحفظ حالته منفصلة', () async {
    SharedPreferences.setMockInitialValues({});
    hits.clear();
    Brand.debugOverride = Brand.osool;
    LicenseService.client = fake(active: false, code: 'ASOUL-5689');
    expect((await LicenseService.check()).allowed, isFalse);
    expect(
      Uri.decodeFull(hits.first.path),
      endsWith('/أصول الضيافة/license.json'),
    );
    // كيف الضيافة لا يتأثر بقفل أصول الضيافة
    Brand.debugOverride = Brand.keif;
    hits.clear();
    LicenseService.client = fake(active: true);
    expect((await LicenseService.check()).allowed, isTrue);
    expect(
      Uri.decodeFull(hits.first.path),
      endsWith('/كيف الضيافة/license.json'),
    );
    final p = await SharedPreferences.getInstance();
    expect(p.getBool('lic_osool_blocked'), isTrue);
    expect(p.getBool('lic_keif_blocked'), isFalse);
  });

  test('الخدمة: init يعرض الكاش ثم يحدّث، unlock يفتح', () async {
    SharedPreferences.setMockInitialValues({});
    LicenseService.client = fake(active: false);
    final l = LicenseService();
    await l.init();
    expect(l.allowed, isFalse);
    expect(await l.unlock('KEIF-7310'), isTrue);
    expect(l.allowed, isTrue);
  });
}
