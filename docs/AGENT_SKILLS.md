# مهارات الوكيل — دروس مستخلصة من العمل على هذا المشروع (تصلح لأي تطبيق Flutter قادم)

> هذا الملف **تراكمي**: كل وكيل يضيف ما اكتشفه بنفس الصيغة (المشكلة ← السبب الحقيقي ← الحل ← كيف تتحقق). لا تكتب درسًا لم تختبره.
> يكمّل `AGENT_GUIDE.md` (طريقة العمل مع المالك) و`ECOSYSTEM.md` (المستودعات). مرتّب بالمجال.

---

## أ. منهج التحقق — القاعدة قبل كل شيء

### أ1. «HTTP 200» ليس دليلًا على أن التطبيق يعمل
- **الخطأ الذي وقع:** قلتُ «المعاينة تعمل» لأن `curl` أعاد 200 وحجم `main.dart.js` صحيح. المستخدم رأى شاشة سوداء.
- **القاعدة:** التحقق من واجهة = **لقطة شاشة فعلية** + **قراءة console** + **تحليل بكسلات** (نسبة لون الخلفية مقابل الأسود الخالص). أي شيء أقل من ذلك = تخمين.
- **الأداة الجاهزة:** Chrome headless + CDP عبر `websocket-client` (مثبّت). القالب في §هـ2.

### أ2. أعد إنتاج بيئة المستخدم بالضبط، لا بيئتك
- الرابط المباشر في المتصفح عمل؛ لوحة المعاينة (iframe مقيّد) لم تعمل. الفرق كان `sandbox="allow-scripts"` بلا `allow-same-origin`.
- **القاعدة:** إن كان المستخدم يرى الشيء داخل إطار/وِدجت/WebView، اختبره داخل إطار بنفس القيود. اكتب صفحة HTML صغيرة تضمّن الرابط في `<iframe sandbox="allow-scripts">` وصوّرها.

### أ3. أدوات القياس لها نقاط عمياء — اعرفها ووثّقها
- عدّاد أهداف اللمس قاس `RenderBox.size` = 30 dp للشرائح، لكن Material يضيف منطقة لمس شفافة 48 dp (`materialTapTargetSize: padded`). النتيجة «122 هدفًا صغيرًا» كانت مضخّمة؛ الحقيقي المؤثر واحد.
- **القاعدة:** بعد أي قياس آلي، افحص **عيّنة يدويًا** واسأل «هل الأداة تقيس ما أظنه؟». اكتب نقطة العمى في التقرير.

### أ4. رقم بلا وحدة/ظروف = لا شيء
اكتب دائمًا: القيمة + الأداة + الظروف (إبطاء CPU؟ كاش؟ حجم البيانات؟). «الإقلاع 6.4 ث» وحدها مضلّلة؛ «6.4 ث تحت 4× إبطاء CPU و4 Mbps، 72% منها CanvasKit» قابلة للفعل.

---

## ب. البنية التحتية للـ sandbox

### ب1. `flutter build web` يجمّد الـ sandbox (8 ج.ب)
- **الأعراض:** كل الأوامر تنتهي بمهلة، حتى `ls`. السبب dart2js يستهلك الذاكرة كلها.
- **الحل المجرّب:** `DART_VM_OPTIONS="--old_gen_heap_size=4096" flutter build web --release` — نجح في 70 ث والذاكرة < 400 م.ب.
- **لا تشغّل** بناء ويب وبناء APK معًا. **لا تشغّل** خادم المعاينة أثناء البناء الأول.
- إن تجمّد: `ResetSandbox` يحفظ الملفات لكنه يقتل كل العمليات — أعد تشغيل الخادم يدويًا بعده.

### ب2. الخادم الخلفي يموت مع انتهاء أمر Bash
- `nohup cmd &` وحدها لا تكفي في هذه البيئة أحيانًا. الصيغة الموثوقة:
  ```bash
  (setsid nohup python3 server.py > log 2>&1 < /dev/null &)
  ```
- **بعد كل `rm -rf build/web` وإعادة بناء، أعد تشغيل الخادم** — العملية القديمة تمسك بالمجلد المحذوف وتخدم 404.
- تحقق دائمًا بـ `lsof -i :5060` + `curl -sI localhost:5060/`.

### ب3. المنفذ 5060 محجوب في Chrome المحلي (SIP)
`google-chrome http://localhost:5060` يعطي `ERR_UNSAFE_PORT`. أضف `--explicitly-allowed-ports=5060` أو اختبر عبر الرابط العام.

### ب4. لا أستطيع إرسال ملف/صورة من الـ sandbox للمستخدم
أداة `Read` تعرض الصورة **لي** فقط. الروابط التي تظهر في نتيجة `Read` ليست عامة. **لا تضع رابط صورة في الرد** إلا إن كان مرفوعًا لمكان عام (GitHub مثلًا). صف ما رأيته بالكلمات والأرقام.

### ب5. `gh` غير مثبّت؛ استخدم REST API بـ curl
التوكن بعد `setup_github_environment` في `~/.git-credentials`:
```bash
TOKEN=$(grep -oE 'https://[^:]+:[^@]+@github.com' ~/.git-credentials | head -1 | sed -E 's#https://[^:]+:([^@]+)@.*#\1#')
# إنشاء إصدار
curl -s -X POST -H "Authorization: token $TOKEN" -H "Content-Type: application/json" --data-binary @body.json https://api.github.com/repos/OWNER/REPO/releases
# رفع ملف
curl -s -X POST -H "Authorization: token $TOKEN" -H "Content-Type: application/vnd.android.package-archive" --data-binary @file.apk "https://uploads.github.com/repos/OWNER/REPO/releases/ID/assets?name=file.apk"
```
اكتب body عبر Python `json.dumps(..., ensure_ascii=False)` — العربية داخل heredoc + JSON يدويًا تنكسر بسهولة.
**لا تطبع التوكن أبدًا** (لا `echo $TOKEN`؛ `${#TOKEN}` للطول فقط).

---

## ج. Flutter Web داخل iframe مقيّد (لوحات المعاينة)

المشكلة العامة: `sandbox="allow-scripts"` بدون `allow-same-origin` ⇐ الأصل مبهم ⇐ **كل** واجهات التخزين ترمي `SecurityError`: `navigator.serviceWorker`، `indexedDB`، `localStorage`. ثلاث طبقات تنهار بالترتيب:

| الطبقة | العَرَض | الإصلاح المجرّب |
|---|---|---|
| محمّل Flutter (`flutter_bootstrap.js`) | شاشة سوداء تمامًا، لا استثناء Dart | في `web/index.html` قبل السكربت: `try{void navigator.serviceWorker}catch(e){delete Navigator.prototype.serviceWorker}` — المحمّل يفحص `'serviceWorker' in navigator` فيتخطى. (**`Object.defineProperty` بـ undefined لا يكفي** لأن `in` يبقى true.) |
| Hive/IndexedDB | «تعذّر فتح قاعدة البيانات» | `try { Hive.openBox(n) } catch { if (!kIsWeb) rethrow; Hive.openBox(n, bytes: Uint8List(0)) }` — صندوق في الذاكرة |
| shared_preferences/localStorage | استثناء غير معالج في خدمات الخلفية | لفّ `SharedPreferences.getInstance()` بـ try/catch وأعد حالة افتراضية آمنة |

**بديل:** `_flutter.loader.load({serviceWorkerSettings: null})` يدويًا **لا يعمل** مع `flutter_bootstrap.js` المولَّد (يشتكي `buildConfig` غير مضبوط). الحل أعلاه أبسط.
**قاعدة تصميم:** أي خدمة تُستدعى من `main()` قبل `runApp` يجب أن تتحمل فشل التخزين بصمت — خطأ في init واحد لا يجوز أن يمنع الرسم.

---

## د. Flutter/Dart — أداء وحجم

### د1. تشريح APK في 10 ثوانٍ (بلا أدوات خارجية)
```python
import zipfile, collections
z=zipfile.ZipFile('app.apk'); c=collections.Counter()
for i in z.infolist(): c[i.filename.split('/')[0]]+=i.compress_size
```
ما تتوقعه لتطبيق Flutter بسيط: `libflutter.so` ≈ 5 م.ب مضغوط (ثابت)، `libapp.so` 3–5، dex < 1 مع R8. **كل ما فوق ذلك أصول** — ابدأ منها.

### د2. الصور: افحص الوضع (mode) لا الحجم فقط
`PIL: Image.open(p).mode` — `RGBA` لشعار مسطّح = هدر ×10. `im.quantize(256)` ثم `save(optimize=True)` يعطي `P` mode. تحقق من التطابق بايت-بايت بين ملفات يُفترض أنها مختلفة (`logo` vs `logo_light` كانا نفس الملف).
`Image.asset` لشعار كبير يُعرض صغيرًا ⇐ أضف `cacheWidth:` (عرض العرض × 3).

### د3. flavors لا تفصل أصول Flutter تلقائيًا
`productFlavors` في Gradle تفصل موارد أندرويد فقط. `pubspec.yaml` واحد ⇐ كل flavor يشحن كل الأصول. إن كان لكل علامة صور ثقيلة، افصلها بسكربت ما قبل البناء أو اقبل التكلفة ووثّقها.

### د4. «الحفظ يعيد كتابة الجدول» نمط شائع وخطر صامت
`DELETE + INSERT ALL` في معاملة بسيط وآمن، لكنه O(n). قِسه دائمًا عند 100/1,000/3,000 سجل قبل أن تقول «سريع». العتبة: > 300 ms للحفظ الواحد = يشعر به المستخدم. الحل المعتاد `INSERT OR REPLACE` للسجل الواحد.

### د5. قياس قابلية التوسع في اختبار عادي (بلا جهاز)
`sqflite_common_ffi` + `Stopwatch` داخل `flutter test` يعطي أرقامًا واقعية للـ I/O (القالب: `test/scale_bench_audit_test.dart`). ضع `TestWidgetsFlutterBinding.ensureInitialized()` إن كان الكود يلمس `rootBundle` أو `path_provider`.
**تنبيه:** n=3,000 مع O(n²) استغرق 7 دقائق — ابدأ بـ 100 و1,000 ثم قرر.

### د6. أهداف اللمس: قِس منطقة الالتقاط لا الصندوق
`RenderBox.size` يكذب مع Material (يضيف 48 dp شفافة). البديل الدقيق: `tester.getSemantics(finder).rect` أو تعطيل `materialTapTargetSize` مؤقتًا في الاختبار لترى الحجم الفعلي. **الأهداف الحقيقية الصغيرة** عادة: `InkWell`/`GestureDetector` حول `Row`/`Text` بلا حشوة (وجدنا 50×16).

### د7. صيد `RenderFlex overflowed` آليًا
في اختبار الوِدجت: بدّل `FlutterError.onError` مؤقتًا واجمع الرسائل التي تحوي `overflowed`. شغّل على 320 dp عرضًا مع أطول بيانات واقعية (وصف 4 أسطر، اسم شركة 30 حرفًا). 0 على 320 dp = آمن على كل شيء.

### د8. مقاسات اختبار الجوال (dp) التي تغطي السوق
`320×640` (الحد الأدنى — أجهزة 2016–2019 لا تزال شائعة)، `360×800` (الأكثر انتشارًا)، `412×915` (الرائدة). اضبط `tester.view.physicalSize = size * 2` و`devicePixelRatio = 2`.

### د9. خطوط حقيقية في اختبارات اللقطات
افتراضيًا `flutter test` يرسم بخط Ahem (مربعات) ⇐ اللقطة لا تعني شيئًا للعربية. حمّل `FontLoader('Tajawal')` من `assets/fonts` و`MaterialIcons` من `/opt/flutter/bin/cache/artifacts/material_fonts/` في `setUpAll`. (موجود في `screenshot_audit_test.dart`.)

### د10. `flutter test` يحجب الشبكة — كل طلب HTTP يعيد 400
`TestWidgetsFlutterBinding` يضبط `HttpOverrides.global` بعميل مزيّف. لاختبار حيّ ضد خدمة حقيقية: `HttpOverrides.global = null` داخل try/finally ثم أعِد السابق. **لا** تستخدم `HttpOverrides.runZoned(createHttpClient: (_) => HttpClient())` — `HttpClient()` يعود إلى التجاوز نفسه ⇐ Stack Overflow. ضع الاختبارات الحيّة تحت وسم `audit` كي لا تفشل بلا إنترنت.

### د11. CanvasKit هو 70% من إقلاع الويب
6.9 م.ب wasm. للويب كمنتج: `--web-renderer html` (أصغر، أضعف خطوطًا) أو استضافة تدعم brotli (2.8 ← ~2.0 م.ب). لأندرويد لا ينطبق.

---

### د13. التقويم الهجري بلا حزمة: استخرج جدول أم القرى من hijri-converter
`pip install hijri-converter` ثم `ummalqura.MONTH_STARTS` (RJD) و`HIJRI_OFFSET`. فهرس الشهر = `(year-1)*12 + month-1 - HIJRI_OFFSET` (**ليس** `year*12`؛ الخطأ يزحف سنة كاملة — تحقق أن 1420/1/1 = 1999-04-17). حوّل RJD إلى JDN بـ `+2400000`، وضمّن الجدول كـ `const List<int>` مع بحث ثنائي. اختبر بمتجهات من المكتبة نفسها + roundtrip كل يوم.

### د14. نص مختلط (أرقام + حرف عربي) في PDF RTL
`textDirection: ltr` صحيح للأرقام الخالصة فقط. أي حرف عربي داخلها («هـ»، «ر.س») ⇐ اترك الاتجاه الافتراضي (RTL) وإلا تتبادل الأجزاء حول القوسين. **صيّر وانظر** — لا يظهر هذا في الاختبارات النصية.

### د15. حجب الشبكة في flutter_test
راجع د10. الدرس العام: إن أعاد كل شيء 400 فورًا فالسبب البيئة لا الخدمة.

## هـ. قوالب جاهزة

### هـ1. خادم معاينة يعمل داخل iframe
```python
# preview_server.py — بلا X-Frame-Options ولا CSP (السماح بالتضمين)، بلا كاش
import http.server, socketserver
class H(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin','*'); self.send_header('Cache-Control','no-store'); super().end_headers()
    def log_message(self,*a): pass
socketserver.TCPServer.allow_reuse_address=True
with socketserver.TCPServer(('0.0.0.0',5060),H) as s: s.serve_forever()
```
شغّله من `build/web` بـ `(setsid nohup python3 /home/user/preview_server.py >/dev/null 2>&1 </dev/null &)`.
**ملاحظة:** `Content-Security-Policy: frame-ancestors *` **يمنع** التضمين من صفحات `file://` (النجمة لا تشمل مخططات غير شبكية) — احذفه.

### هـ2. لقطة + console عبر CDP (بديل Playwright غير المثبّت)
```python
import json, subprocess, time, base64, urllib.request, websocket
p=subprocess.Popen(["google-chrome","--headless=new","--no-sandbox","--disable-gpu","--enable-unsafe-swiftshader",
   "--remote-debugging-port=9333","--window-size=390,844","about:blank"],stdout=-3,stderr=-3); time.sleep(2)
tabs=[t for t in json.load(urllib.request.urlopen("http://127.0.0.1:9333/json")) if t["type"]=="page"]  # تجاهل extensions
ws=websocket.create_connection(tabs[0]["webSocketDebuggerUrl"],suppress_origin=True); i=0
def send(m,pr={},to=60):
    global i;i+=1;ws.settimeout(to);ws.send(json.dumps({"id":i,"method":m,"params":pr}))
    while True:
        r=json.loads(ws.recv())
        if r.get("id")==i:return r
        # هنا تجمع Runtime.exceptionThrown / Log.entryAdded / Runtime.consoleAPICalled
send("Page.enable");send("Runtime.enable");send("Log.enable");send("Page.navigate",{"url":URL})
time.sleep(25)  # زمن حقيقي، لا virtual-time-budget (الأخير لا ينتظر wasm)
img=send("Page.captureScreenshot",{"format":"png"})["result"]["data"]; open("/tmp/s.png","wb").write(base64.b64decode(img))
```
- `--virtual-time-budget` مع `--screenshot` **لا يكفي** لتطبيقات Flutter (تنتهي قبل تحميل CanvasKit) — استخدم CDP وانتظر زمنًا حقيقيًا.
- `--enable-unsafe-swiftshader` ضروري وإلا WebGL يفشل ولا يُرسم شيء.
- أول تبويب في `/json` قد يكون extension (`chrome-extension://…/thunk.js`) — فلتر بـ `type=="page"`.
- لقياس الأداء: `Emulation.setCPUThrottlingRate {rate:4}` + `Network.emulateNetworkConditions` + `Performance.getMetrics` (JSHeapUsedSize, Nodes, LayoutCount).

### هـ3. تحليل لقطة بلا عين بشرية
```python
from PIL import Image
im=Image.open(p).convert("RGB").crop((0,0,W,H)); c=im.getcolors(1<<20); c.sort(reverse=True)
# c[0] = اللون الغالب. (0,0,0) بنسبة > 80% = شاشة سوداء. لون خلفية الثيم = مرسوم.
```
ثم `Read` للصورة للفحص الدلالي (نصوص، تداخل، قصّ). الاثنان معًا: الأرقام تمنع الخداع، العين تلتقط المعنى.

### هـ4. شريط مقارنة لقطات (عدة شاشات في صورة واحدة)
الصق 4 لقطات جنبًا إلى جنب بـ PIL بفاصل 10 px ثم `thumbnail((1900,1400))` ⇐ صورة واحدة تكفي لفحص 4 شاشات دفعة واحدة وتوفر استدعاءات `Read`.

---

### د12. تدقيق «هل الكود المنشور هو ما راجعته؟»
`unzip -p app.apk lib/arm64-v8a/libapp.so | strings -n 8 | grep <ثابت مميز>` — الثوابت النصية (أسماء نطاقات، مسارات) تبقى في AOT. إن لم تظهر فالـ APK من كود مختلف.

## و. النشر والتوقيع (مختصر — التفصيل في ECOSYSTEM)

- المفتاح **يُسحب** من المستودع الخاص؛ لا يُنشأ. تحقق بـ `keytool -list -v` أن SHA-1 يطابق **قبل** البناء، وبـ `apksigner verify --print-certs` **بعده**، وعلى **الملفات المنزَّلة من GitHub** بعد النشر (3 مرات — كل مرة تصطاد خطأً مختلفًا).
- `--split-per-abi` ⇐ versionCode = 1000×ABI + N. اقرأه بـ `aapt2 dump badging | head -1`.
- أول بناء flavor ≈ 8 دقائق (Gradle بارد)، الثاني ≈ 2 دقيقة. استخدم مهلة 600 ث.
- SHA-256 قبل الرفع وبعد التنزيل عبر `sha256sum -c` — الطريقة الوحيدة لإثبات أن ما على GitHub هو ما بنيته.

---

## ز. التوثيق للمالك

- المالك يقرأ **الجداول** لا الفقرات. كل رد تسليم: جدول «الفحص ← النتيجة» ثم الروابط ثم ملاحظة واحدة صريحة عمّا لم يُتحقق منه.
- اعترف بالخطأ في أول سطر إن وقع («لم أحلل بكسل-بكسل — تحققت من HTTP 200 فقط»). المالك يتسامح مع الخطأ لا مع التغطية.
- أي تغيير كودي **بعد** نشر إصدار: قل صراحة «الـ APK المنشور لا يتضمنه» و«الإصدار القادم N+1».
- لا تنفّذ إصلاحات اكتشفتها في تدقيق دون طلب — وثّقها بجدول أولويات واترك المالك يقرر.
- **لا تُكرّر عبارة غامضة من تسليم سابق كأنها طلب مؤكد.** («الهيكلية» وردت في HANDOFF بلا تفاصيل؛ كررتُها للمالك مرارًا فلم يفهم ما أقصد.) إن وجدت إشارة معلّقة غير واضحة: اسأل عنها مرة واحدة بصيغة «التسليم السابق يذكر X بلا تفاصيل — هل ما زال مطلوبًا؟» أو احذفها.
