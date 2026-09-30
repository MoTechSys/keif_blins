# تسليم الجلسة — 2.5.0 منشور · **2.6.0 في الكود (مكتمل الميزات إلا Onboarding) — لم يُبنَ بعد** (2026-09-30)

## الحالة الآن
- `main` @ آخر commit (انظر `git log -1`) — analyze 0 · **153 اختبارًا ناجحًا** (`--exclude-tags audit`).
- 2.6.0 يحوي: مجلدات بالعميل، هجري، ترقيم تاريخ/وقت افتراضي (شامل السندات)، نسخة خروج اختيارية + يومية 24 ساعة، StorageGuard، ورقة استعادة + عرض تلقائي بعد إعادة التثبيت، UpdateService كامل (Dart + Kotlin + Manifest + FileProvider)، تذييل المطوّر.
- **إصلاح خفي مهم**: `pdfFoldersByClient` كان يُكتب ولا يُقرأ (غير مسجّل في `_kvKeys`) ⇒ أُصلح وأُضيف اختبار يحرس كل المفاتيح.

## المتبقي بالترتيب (لا تبدأ غيره)
1. **Onboarding** (ADR-0008): 4 صفحات بسيطة (المجلد والصلاحية · الفواتير والترقيم · النسخ والاستعادة · التحديث) + «تخطي»؛ تُعرض بعد `storageAsked` وقبل الرئيسية؛ مفتاح `onboardingDone` محجوز في `Store.kvKeys`. أضِف شاشة `onboarding` إلى `ux_metrics_audit_test`.
2. `flutter test test/ux_metrics_audit_test.dart` بعد Onboarding + لقطات في `docs/renders/v260_*.jpg` (settings-update, restore-sheet, drawer-footer).
3. تحديث `CHANGELOG.md` (قسم 2.6.0 يحتاج إضافة: ترقيم، نسخ، StorageGuard، استعادة، تحديث، تذييل، إصلاح kvKeys).
4. البناء والنشر 2.6.0 (الخطوات أدناه) — **بعد إذن المالك**. versionCode 3600/4600.
5. **بعد النشر**: أنشئ `update.json` في `diafa-apps/كيف الضيافة/` و`أصول الضيافة/` (الصيغة في رأس `lib/core/update_service.dart`؛ الـ sha256 من `sha256sum` للملفات المنشورة، والروابط من صفحة الإصدار). بدون هذا الملف يعرض التطبيق «لا يمكن الوصول إلى خادم التحديث» — وهذا مقصود لا خطأ.
6. تحديث `README.md`/`ECOSYSTEM.md` بالإصدار وخطوة update.json.

## ملاحظة اختبار يدوي على جهاز (لا يمكن في الـ sandbox)
- التثبيت من داخل التطبيق يحتاج جهازًا حقيقيًا: تأكد من ظهور شاشة «تثبيت التطبيقات غير المعروفة» ثم المتابعة التلقائية عند الرجوع.
- منح «الوصول إلى كل الملفات» من حوار StorageGuard ثم الرجوع ⇒ يجب أن يُكمل العملية بلا ضغط إضافي.

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
