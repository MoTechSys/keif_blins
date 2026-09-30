# تسليم جلسة — 2.5.0 منشور · **2.6.0 في الكود (لم يُبنَ بعد)** (2026-09-30)

> اقرأ `ECOSYSTEM.md` ثم `docs/AGENT_GUIDE.md` أولًا. هذا الملف يصف **أين توقفنا بالضبط** وما المتبقي.

## الحالة الآن (2026-09-30)

| | الحالة |
|---|---|
| الكود | `main` @ `a802e2c` — `flutter analyze` = 0 · `flutter test` = **164 ناجحًا** (أُعيد التحقق قبل البناء) |
| الإصدار في الكود | `pubspec.yaml` = `2.5.0+2500` · `SettingsHub.version` = `2.5.0` |
| APK 2.5.0 | **مبنيّ ومتحقق** — SHA-1 `c874a9f4…f9aa` · versionCode 3500/4500 · الحزمتان صحيحتان (apksigner + aapt2 على الأربعة) |
| المنشور للعميل | **2.5.0** — [diafa-apps/releases/v2.5.0](https://github.com/MoTechSys/diafa-apps/releases/tag/v2.5.0)، نُزّلت الملفات من GitHub وطابقت SHA-256 (القيم في CHANGELOG.md). README/CHANGELOG في diafa-apps محدّثان @ `ddc2d0f` |
| التدقيق | `docs/AUDIT_2.5.0.md` (2026-09-30): حجم/سرعة/ذاكرة/واجهات/أزرار + خطة إصلاح من 8 بنود **لم تُنفَّذ** (بانتظار قرار المالك) |
| 2.6.0 (الكود) | `pubspec` = `2.6.0+2600` · مجلدات PDF بالعميل + نسخة عند الخروج + هجري أم القرى — CHANGELOG §2.6.0 · `flutter test` = 124 |
| المتبقي | **بناء ونشر 2.6.0** بنفس خطوات 2.5.0 أدناه (غيّر الرقم فقط: versionCode 3600/4600، الملفات `*-v2.6.0-*`). خطة إصلاحات AUDIT §7 لا تزال بانتظار قرار المالك |
| المفتاح | `diafa-signing-keys/android/` (SHA-1 `C8:74:A9:F4:22:40:0E:E3:4F:D2:1D:D5:78:77:82:E5:3C:C3:F9:AA`) — **يُسحب من هناك، لا يُنشأ جديد أبدًا** |

## ما أُنجز في 2.5.0 (كله في CHANGELOG.md بالتفصيل)
1. **الوحدات المرنة**: `Org.units` + تبويب «الوحدات» في إعدادات الفواتير (إضافة/تعديل/حذف/ترتيب/استعادة) + شريحة «+ وحدة» داخل نموذج البند + PDF يعرض «الكمية (موقع)» عند توحّد الوحدة.
2. إصلاح زر «حفظ فقط» في تسجيل الدفعة (كان ينكسر حرفًا حرفًا) وتاريخ المناسبة على سطر واحد.
3. انتقالات موحّدة (انزلاق+تلاشٍ) لكل الشاشات، تلاشي التبويبات، اهتزاز لمسي.
4. أداة تدقيق بصري `test/screenshot_audit_test.dart` ⇐ `build/audit/<brand>/*.png`.
5. معاينات: `docs/renders/v250_ui_fixes.jpg`، `docs/renders/invoice_units_header.jpg`.

## خطوات البناء والنشر التي نُفّذت لـ 2.5.0 (مرجع لأي إصدار قادم — غيّر الرقم فقط)

```bash
# 0) استنساخ الكود والمفتاح
git clone https://github.com/MoTechSys/keif_blins /home/user/flutter_app && cd /home/user/flutter_app
git clone https://github.com/MoTechSys/diafa-signing-keys /tmp/keys
cp /tmp/keys/android/release-key.jks /tmp/keys/android/key.properties android/
flutter pub get && flutter analyze && flutter test        # 0 issues · 164 passed

# 1) البناء (كل أمر ~5-8 دقائق؛ شغّله في الخلفية أو بمهلة 600 ث)
flutter build apk --release --flavor keif  --dart-define=BRAND=keif  --split-per-abi --target-platform android-arm,android-arm64
flutter build apk --release --flavor osool --dart-define=BRAND=osool --split-per-abi --target-platform android-arm,android-arm64

# 2) التحقق — يجب: SHA-1 c874a9f4… · versionCode 3500 (armv7) / 4500 (arm64)
BT=/home/user/android-sdk/build-tools/35.0.0
for f in build/app/outputs/flutter-apk/*.apk; do $BT/apksigner verify --print-certs $f | grep SHA-1; $BT/aapt2 dump badging $f | head -1; done

# 3) إعادة التسمية
#   app-keif-arm64-v8a-release.apk    -> keif-aldiafa-v2.5.0-arm64.apk
#   app-keif-armeabi-v7a-release.apk  -> keif-aldiafa-v2.5.0-armv7.apk
#   app-osool-arm64-v8a-release.apk   -> asoul-aldiafa-v2.5.0-arm64.apk
#   app-osool-armeabi-v7a-release.apk -> asoul-aldiafa-v2.5.0-armv7.apk

# 4) النشر في diafa-apps كإصدار v2.5.0 عبر GitHub REST API (التوكن من setup_github_environment)
#    body: جدول «أي ملف أُنزّل» + SHA-256 لكل ملف + ملخص CHANGELOG
# 5) نزّل الملفات من GitHub وقارن SHA-256 بالأصل
# 6) حدّث diafa-apps: README (روابط التحميل المباشر v2.5.0) + CHANGELOG في المجلدين
```

روابط التحميل المباشر بعد النشر (ثابتة الصيغة):
`https://github.com/MoTechSys/diafa-apps/releases/download/v2.5.0/<اسم الملف>`

## ملاحظات مهمة للوكيل الجديد
- **العميل على 2.2.0** (مفتاح قديم مفقود نهائيًا — لا تبحث عنه): انتقاله مرة واحدة = نسخة احتياطية ← حذف ← تثبيت 2.5.0 ← استرجاع. ثم كل تحديث لاحق يُثبَّت فوق السابق.
- **Google Drive**: الكود جاهز؛ المتبقي على المالك في Google Cloud (مشروع `keif-diafa-api`): Drive API + عميلا OAuth Android للحزمتين بـ SHA-1 أعلاه + نشر شاشة الموافقة. بدونها زر «ربط حساب Google» يفشل.
- بيئة الـ sandbox قد تستبدل `lib/main.dart`/`pubspec.yaml`/`web/index.html` بقالب افتراضي عند الفتح — تحقق بـ `git status` أولًا و`git checkout -- .` إن لزم.
- المعاينة على الويب: `flutter build web --release --dart-define=BRAND=keif` ثم خادم على 5060 (انظر AGENT_GUIDE).
