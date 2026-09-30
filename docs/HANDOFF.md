# تسليم الجلسة — **2.6.0 منشور** (2026-09-30، بناء 3600/4600) · المؤجَّل في `docs/ROADMAP.md`

## الحالة الآن
- **منشور**: https://github.com/MoTechSys/diafa-apps/releases/tag/v2.6.0 — 4 ملفات، SHA-256 مُتحقَّق بعد التنزيل من GitHub، SHA-1 التوقيع `c874a9f4…`.
- **`update.json`** منشور في مجلدَي diafa-apps؛ `test/update_live_audit_test.dart` (وسم audit) يثبت أن كود التطبيق الفعلي يقرأه ويرى التحديث من 2.5.0 وينزّل الملفات وتطابق بصماتها — 4/4.
- analyze 0 · 153 اختبارًا (`--exclude-tags audit`) · tag `v2.6.0` في keif_blins.
- **المتبقي**: كله في `docs/ROADMAP.md` (2.7.0: Onboarding، تدقيق UX، AUDIT §7) + اختبار يدوي على جهاز حقيقي (قائمة في ROADMAP).

## خطوات الإصدار (نُفّذت لـ 2.6.0 — مرجع 2.7.0: غيّر الرقم فقط)
```bash
# 0) المفاتيح (خاص) — لا تُرفع أبدًا
git clone https://github.com/MoTechSys/diafa-signing-keys /tmp/keys && cp /tmp/keys/android/release-key.jks /tmp/keys/android/key.properties android/
# 1) البناء (~4-5 دقائق لكل نكهة؛ في الخلفية)
flutter build apk --release --flavor keif  --dart-define=BRAND=keif  --split-per-abi --target-platform android-arm,android-arm64
flutter build apk --release --flavor osool --dart-define=BRAND=osool --split-per-abi --target-platform android-arm,android-arm64
# 2) التحقق: SHA-1 + versionCode + الحزمة + الصلاحيات + مزوّد update.fileprovider
BT=/home/user/android-sdk/build-tools/35.0.0; for f in build/app/outputs/flutter-apk/*.apk; do $BT/apksigner verify --print-certs $f | grep SHA-1; $BT/aapt2 dump badging $f | head -1; done
# 3) إعادة التسمية إلى keif-aldiafa-vX-{arm64,armv7}.apk / asoul-aldiafa-vX-… ثم sha256sum > SHA256SUMS
# 4) release عبر REST (التوكن من ~/.git-credentials بعد setup_github_environment) + رفع الأصول إلى uploads.github.com
# 5) نزّل الملفات من GitHub و sha256sum -c SHA256SUMS
# 6) python3 tools/make_update_json.py X.Y.Z N /path/to/apks /home/user/diafa-apps   ← ينشئ update.json للمجلدين (عدّل notes داخله)
# 7) diafa-apps: README (روابط) + CHANGELOG في المجلدين + push ؛ ثم flutter test test/update_live_audit_test.dart (بعد تعديل أرقام الإصدار فيه)
# 8) keif_blins: HANDOFF + ECOSYSTEM + README + git tag vX.Y.Z + push --tags
```

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
