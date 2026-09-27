# خريطة المنظومة — اقرأ هذا أولًا (لأي وكيل ذكاء اصطناعي أو مطوّر)

منظومة تطبيقات أندرويد لمؤسستَي ضيافة في جدة، مبنية من **كود واحد**، موزّعة على **3 مستودعات** لكلٍّ منها دور لا يتداخل مع الآخر. هذا الملف موجود بنفس النص في المستودعات الثلاثة.

## المستودعات الثلاثة

| المستودع | الرؤية | الدور | ماذا فيه |
|---|---|---|---|
| [`MoTechSys/keif_blins`](https://github.com/MoTechSys/keif_blins) | عام | **الكود المصدري** | مشروع Flutter كامل يبني التطبيقين، الاختبارات، التوثيق الفني، سجل التغييرات |
| [`MoTechSys/diafa-apps`](https://github.com/MoTechSys/diafa-apps) | **عام (إلزامي)** | **التوزيع + القفل عن بُعد** | ملفات `license.json` (مجلد لكل تطبيق) + صفحة الإصدارات (ملفات APK) |
| [`MoTechSys/diafa-signing-keys`](https://github.com/MoTechSys/diafa-signing-keys) | **خاص (إلزامي)** | **مفتاح التوقيع** | `release-key.jks` + `key.properties` — بدونه لا يمكن إصدار تحديث |

```
keif_blins (الكود)  ──بناء──►  APK  ──نشر──►  diafa-apps/releases
      ▲                          │
      │ نسخ المفتاح قبل البناء     └─ التطبيق المثبّت يقرأ ──►  diafa-apps/<المجلد>/license.json
diafa-signing-keys (خاص)
```

## التطبيقان

| | كيف الضيافة | أصول الضيافة |
|---|---|---|
| اسم الحزمة (**ثابت للأبد**) | `com.hospitalitybilling.keif_diafa` | `com.hospitalitybilling.osool_diafa` |
| Flavor عند البناء | `keif` | `osool` |
| مجلد التحكم في diafa-apps | `كيف الضيافة/` | `أصول الضيافة/` |
| كود التفعيل | القيمة الحية دائمًا في `كيف الضيافة/license.json` | القيمة الحية دائمًا في `أصول الضيافة/license.json` |
| ملف APK | `keif-aldiafa-vX.Y.Z-{arm64,armv7}.apk` | `asoul-aldiafa-vX.Y.Z-{arm64,armv7}.apk` |
| الهوية | keifaldiafa.com · س.ت 4030499689 | asoulaldiafa.com · بلا سجل تجاري (يُخفى تلقائيًا) |

- التطبيقان منفصلان تمامًا على الجوال: قاعدة بيانات، مجلد، نسخ احتياطية، ترخيص — لا تختلط.
- **أندرويد فقط** (لا iOS/ويب كمنتج). المعماريات: `arm64-v8a` و`armeabi-v7a` فقط (~12.6 م.ب).

## التوقيع والتحديث (أخطر نقطة)

- SHA-1 المفتاح الحالي: `C8:74:A9:F4:22:40:0E:E3:4F:D2:1D:D5:78:77:82:E5:3C:C3:F9:AA` (alias `release`، صالح حتى 2054).
- **كل إصدار من 2.4.0 فصاعدًا** يجب أن يُوقَّع بهذا المفتاح + نفس اسم الحزمة + `versionCode` أعلى ⇐ يُثبَّت فوق السابق دون حذف والبيانات تبقى.
- الإصدارات ≤ 2.2.0 (في keif_blins/releases) موقّعة بمفتاح قديم مفقود (SHA-1 `B4:6A:5E:20:…:DA:A1`) ⇐ الانتقال منها يتطلب مرة واحدة: تصدير نسخة احتياطية ← حذف ← تثبيت 2.4.0 ← استرجاع (2.4.0 يقرأ نسخ 2.2.0).
- رقم البناء: `version: X.Y.Z+N` في pubspec.yaml؛ Flutter مع `--split-per-abi` يعطي versionCode = `1000×ABI + N` (armv7 = 1000+N، arm64 = 2000+N). مثال 2.4.0+2400 ⇐ 3400 / 4400. **زِد N دائمًا** (2401، 2402…).

## القفل عن بُعد

`diafa-apps/<المجلد>/license.json`:
```json
{ "active": true, "code": "XXXX", "message": "نص يظهر للمستخدم عند القفل" }
```
| الحالة | النتيجة |
|---|---|
| `active: true` | يفتح فورًا (ويمسح أي قفل سابق) |
| `active: false` | يُقفل ويطلب الكود؛ الكود الصحيح يُحفظ ويفتح ما دام نفس الكود في الملف |
| تغيير `code` | يُقفل من فعّل بالكود القديم |
| حذف الملف (404) | قفل نهائي بلا كود — **فقط** إن سبق للتطبيق قراءة الملف مرة |
| بلا إنترنت / ملف تالف / حد الطلبات | آخر حالة معروفة (لا قفل خاطئ) |

- **الكود المرجعي هو ما في الملف** — المالك يغيّره متى شاء من واجهة GitHub؛ لا تنسخه إلى أي توثيق.
- يُفحص عند التشغيل وعند الرجوع للتطبيق (فاصل أدنى 10 دقائق). البيانات لا تُمس أبدًا.
- المصدر الأساسي GitHub Contents API (بلا كاش CDN)، والاحتياطي raw.githubusercontent.
- الكود: `keif_blins/lib/core/license_service.dart` · الشاشة: `lib/ui/screens/license_screen.dart` · الاختبارات: `test/license_test.dart`.
- ⚠️ **لا تغيّر** اسم المستودع diafa-apps ولا أسماء المجلدات العربية ولا تجعله خاصًا — التطبيقات المثبّتة تقرأ هذا المسار حرفيًا. تغييره = إصدار جديد إلزامي.

## إصدار تحديث جديد (الخطوات بالترتيب)

```bash
# 1) الكود
git clone https://github.com/MoTechSys/keif_blins && cd keif_blins
# 2) المفتاح (خاص)
git clone https://github.com/MoTechSys/diafa-signing-keys /tmp/keys
cp /tmp/keys/android/release-key.jks /tmp/keys/android/key.properties android/
# 3) ارفع الإصدار في pubspec.yaml (X.Y.Z+N أعلى) و SettingsHub.version في settings_screen.dart
flutter pub get && flutter analyze && flutter test      # 0 issues · كل الاختبارات ناجحة
# 4) البناء
flutter build apk --release --flavor keif  --dart-define=BRAND=keif  --split-per-abi --target-platform android-arm,android-arm64
flutter build apk --release --flavor osool --dart-define=BRAND=osool --split-per-abi --target-platform android-arm,android-arm64
# 5) التحقق — يجب أن يطابق SHA-1 أعلاه واسم الحزمة
apksigner verify --print-certs build/app/outputs/flutter-apk/*.apk
aapt2 dump badging <apk> | head -1
```
6. أعد التسمية إلى `keif-aldiafa-vX.Y.Z-arm64.apk` … وانشرها كإصدار `vX.Y.Z` في **diafa-apps** (REST API) مع جدول «أي ملف أُنزّل» وSHA-256.
7. نزّل الملفات من GitHub وقارن SHA-256 بالأصل.
8. حدّث `CHANGELOG.md` في keif_blins وفي مجلدي diafa-apps، وادفع.

## مستخدم المشروع

- يكتب بالعربية (لهجة) ويريد الرد **بالعربية فقط**، قصيرًا ومباشرًا وموثّقًا بالتحقق الفعلي.
- لا تقل «تم» عن شيء لم تتحقق منه بنفسك (صورة، اختبار، تنزيل فعلي).
- دليل طريقة العمل التفصيلي: `keif_blins/docs/AGENT_GUIDE.md`.

## أسرار — لا تُكتب في أي مستودع عام أبدًا
- `key.properties` / `*.jks` ⇐ في diafa-signing-keys فقط (مُتجاهلة في keif_blins عبر `android/.gitignore`).
- توكنات GitHub وبيانات Google ⇐ لا تُحفظ في أي ملف؛ تُطلب من المالك عند الحاجة.
- Google Drive: مشروع Google Cloud `keif-diafa-api` (المالك keifaldiafa@gmail.com). المطلوب لتفعيله: Drive API + عميلا OAuth من نوع Android (الحزمتان + SHA-1 أعلاه) + نشر شاشة الموافقة. التطبيق لا يحتاج أي سر؛ كل مستخدم يخزّن في Drive الخاص به (appDataFolder).
