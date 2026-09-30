// تدقيق حيّ للقفل عن بُعد (وسم audit — يحتاج إنترنت):
//   flutter test test/license_live_audit_test.dart
// 1) يستخدم كود LicenseService الحقيقي وعميل HTTP الحقيقي ضد GitHub الفعلي للعلامتين.
// 2) يتحقق أن الرابط الذي يبنيه التطبيق (Uri.https مع المجلد العربي) يعيد 200 من API ومن RAW.
// 3) يأخذ المحتوى الفعلي للملفين ويشغّل به آلة الحالات كاملة (قفل ← كود ← فتح ← تغيير كود ← حذف).
@Tags(['audit'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:keif_diafa/core/brand.dart';
import 'package:keif_diafa/core/license_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// flutter_test يستبدل HttpClient عالميًا بمزيّف يعيد 400 لكل طلب (منع الشبكة).
/// للتدقيق الحيّ نُلغي التجاوز مؤقتًا ثم نُعيده. (استخدام HttpClient() داخل
/// createHttpClient يعود إلى التجاوز نفسه ⇐ Stack Overflow — لذلك نلغيه بالكامل.)
Future<T> _realNet<T>(Future<T> Function() body) async {
  final prev = HttpOverrides.current;
  HttpOverrides.global = null;
  try {
    return await body();
  } finally {
    HttpOverrides.global = prev;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    Brand.debugOverride = null;
    LicenseService.client = http.Client();
  });

  for (final b in [Brand.keif, Brand.osool]) {
    test(
      'LIVE ${b.id}: الرابطان يعيدان 200 والملف صالح ويفتح التطبيق',
      () => _realNet(() async {
        Brand.debugOverride = b;
        SharedPreferences.setMockInitialValues({});
        LicenseService.client = http.Client();

        // الروابط كما يبنيها الكود
        final api = LicenseService.apiUri;
        final raw = LicenseService.rawUri;
        expect(
          Uri.decodeComponent(api.path),
          contains('/${b.folderName}/license.json'),
        );
        expect(
          Uri.decodeComponent(raw.path),
          contains('/${b.folderName}/license.json'),
        );

        final ra = await http.get(
          api,
          headers: {'Accept': 'application/vnd.github+json'},
        );
        final rr = await http.get(raw);
        expect(ra.statusCode, 200, reason: 'API ${api.toString()}');
        expect(rr.statusCode, 200, reason: 'RAW ${raw.toString()}');

        // محتوى API (base64) == محتوى RAW
        final meta =
            jsonDecode(utf8.decode(ra.bodyBytes)) as Map<String, dynamic>;
        final apiJson = utf8.decode(
          base64Decode(
            (meta['content'] as String).replaceAll(RegExp(r'\s'), ''),
          ),
        );
        final rawJson = utf8.decode(rr.bodyBytes);
        expect(
          jsonDecode(apiJson),
          equals(jsonDecode(rawJson)),
          reason: 'API و RAW يجب أن يتطابقا (لا كاش قديم)',
        );

        final d = jsonDecode(rawJson) as Map<String, dynamic>;
        expect(d['active'], isA<bool>());
        expect((d['code'] as String).trim(), isNotEmpty);
        expect(d['message'], isA<String>());

        // الكود الحقيقي للخدمة ضد GitHub الحقيقي
        final st = await LicenseService.check();
        expect(st.offline, isFalse, reason: 'وصل للشبكة فعلًا');
        expect(
          st.allowed,
          d['active'] == true,
          reason: 'حالة التطبيق تطابق الملف',
        );
        // ignore: avoid_print
        print(
          'LIVE ${b.id}: active=${d['active']} allowed=${st.allowed} api=${api.host} raw=${raw.host}',
        );
      }),
    );

    test('آلة الحالات بمحتوى الملف الفعلي — ${b.id}', () async {
      Brand.debugOverride = b;
      SharedPreferences.setMockInitialValues({});
      // نسحب الملف الفعلي مرة واحدة (شبكة حقيقية) ثم نتحكم فيه محليًا
      final real = await _realNet(
        () async =>
            jsonDecode(
                  utf8.decode(
                    (await http.get(LicenseService.rawUri)).bodyBytes,
                  ),
                )
                as Map<String, dynamic>,
      );
      final realCode = (real['code'] as String).trim();

      Map<String, dynamic> file = Map.of(real);
      var deleted = false;
      LicenseService.client = MockClient((req) async {
        if (deleted) return http.Response('Not Found', 404);
        final body = jsonEncode(file);
        if (req.url.host == 'api.github.com') {
          return http.Response(
            jsonEncode({'content': base64Encode(utf8.encode(body))}),
            200,
          );
        }
        return http.Response.bytes(utf8.encode(body), 200);
      });

      // 1) الحالة الحالية (active=true) ⇐ مفتوح
      var st = await LicenseService.check();
      expect(st.allowed, isTrue);

      // 2) المالك يقفل ⇐ يُقفل ويطلب الكود
      file['active'] = false;
      st = await LicenseService.check();
      expect(st.allowed, isFalse);
      expect(st.codeAccepted, isTrue);
      expect(st.message, real['message']);

      // 3) كود خاطئ يُرفض، الصحيح (بحروف صغيرة ومسافات) يُقبل
      expect(await LicenseService.activate('WRONG-0000'), isFalse);
      expect(
        await LicenseService.activate('  ${realCode.toLowerCase()}  '),
        isTrue,
      );
      st = await LicenseService.check();
      expect(
        st.allowed,
        isTrue,
        reason: 'الكود المحفوظ يفتح ما دام نفس الكود في الملف',
      );

      // 4) المالك يغيّر الكود ⇐ يُقفل من جديد
      file['code'] = '$realCode-NEW';
      st = await LicenseService.check();
      expect(st.allowed, isFalse);
      expect(
        await LicenseService.activate(realCode),
        isFalse,
        reason: 'الكود القديم لم يعد صالحًا',
      );
      expect(await LicenseService.activate('$realCode-NEW'), isTrue);

      // 5) active=true من جديد ⇐ يفتح فورًا ويمسح القفل
      file['active'] = true;
      st = await LicenseService.check();
      expect(st.allowed, isTrue);

      // 6) حذف الملف بعد أن رآه ⇐ قفل نهائي بلا كود
      deleted = true;
      st = await LicenseService.check();
      expect(st.allowed, isFalse);
      expect(st.codeAccepted, isFalse);
      expect(await LicenseService.activate('$realCode-NEW'), isFalse);

      // 7) عودة الملف ⇐ يفتح
      deleted = false;
      st = await LicenseService.check();
      expect(st.allowed, isTrue);
    });
  }

  test('العلامتان لا تتشاركان الحالة (قفل كيف لا يقفل أصول)', () async {
    SharedPreferences.setMockInitialValues({});
    LicenseService.client = MockClient((req) async {
      final isKeif =
          req.url.path.contains(Uri.encodeComponent('كيف الضيافة')) ||
          req.url.path.contains('كيف الضيافة');
      final body = jsonEncode({'active': !isKeif, 'code': 'X', 'message': 'm'});
      if (req.url.host == 'api.github.com') {
        return http.Response(
          jsonEncode({'content': base64Encode(utf8.encode(body))}),
          200,
        );
      }
      return http.Response.bytes(utf8.encode(body), 200);
    });
    Brand.debugOverride = Brand.keif;
    expect((await LicenseService.check()).allowed, isFalse);
    Brand.debugOverride = Brand.osool;
    expect((await LicenseService.check()).allowed, isTrue);
    Brand.debugOverride = Brand.keif;
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('lic_keif_blocked'), isTrue);
    expect(prefs.getBool('lic_osool_blocked'), isFalse);
  });
}
