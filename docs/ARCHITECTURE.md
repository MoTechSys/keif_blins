# كيف يعمل التطبيق — البنية والتدفقات (اقرأه بعد START_HERE)

> الهدف: أن يفهم وكيل جديد **كل** آلية في التطبيق خلال 20 دقيقة دون فتح الكود، ثم يعرف أي ملف يفتح لأي تغيير.
> كل عنوان يذكر الملف المسؤول. القرارات الثابتة برقم ADR في `docs/adr/README.md`.

## 0. الصورة الكبيرة

```
                 ┌──────────── الواجهة (lib/ui) ────────────┐
                 │ Shell ─ HomeScreen / Clients / Docs / …   │
                 │   ↑ Provider (context.watch/select)       │
                 └──────────────┬────────────────────────────┘
                                │
   ┌────────────┐   ┌───────────▼──────────┐   ┌──────────────────┐
   │ Lock/License│   │  Store (ChangeNotifier)│   │ UpdateService     │
   │ (prefs/GitHub)│  │  القوائم في الذاكرة   │   │ (GitHub update.json)│
   └────────────┘   │  + Org + kv           │   └──────────────────┘
                    └───────────┬───────────┘
                                │ replaceTables / putKv (معاملة واحدة)
                    ┌───────────▼───────────┐
                    │ AppDb: SQLite (أندرويد)│  ← Hive على الويب فقط
                    └───────────┬───────────┘
                                │ exportData → JSON + SHA-256
              ┌─────────────────▼────────────────────┐
              │ FileService: /storage/emulated/0/<التطبيق>/ │
              │   الفواتير/<العميل>/…pdf · النسخ الاحتياطية/…json│
              └──────────────────────────────────────┘
```

- **كود واحد، تطبيقان**: `Brand.current` (من `--dart-define=BRAND` أو flavor) يحدد الاسم، الحزمة، المجلد، قاعدة البيانات، الشعار — `lib/core/brand.dart`. **لا تختلط بيانات التطبيقين أبدًا** (اختبار `brand_test`).
- **لا خادم**: كل شيء على الجهاز. GitHub يُستخدم فقط لقراءة ملفين عامّين: `license.json` (القفل) و`update.json` (التحديث).

## 1. الإقلاع (main.dart → shell.dart)

1. `main()` ينشئ `Store`, `LockService`, `LicenseService`, `UpdateService` ويستدعي `init()` لكلٍّ **بلا انتظار** (الواجهة تعرض تحميلًا). `FileService.base()` ينشئ المجلد. `UpdateService.cleanup()` يحذف APK قديم في الكاش.
2. `Shell.build` يقرر الشاشة بهذا الترتيب الصارم:
   - `!license.allowed` → **LicenseScreen** (قفل عن بُعد — يسبق كل شيء)
   - `!signedIn` → **SignInScreen** (Google أو «بدون تسجيل»)
   - `!storageAsked` (أندرويد) → **StorageSetupScreen** (طلب صلاحية الجذر مرة واحدة)
   - `locked` → **LockScreen** (PIN)
   - وإلا → التبويبات الأربعة (الرئيسية/العملاء/الفواتير/الكشوف) + Drawer.
3. بعد أول إطار للرئيسية: `_offerRestoreOnce()` → إن كانت القاعدة فارغة ووُجدت نسخ سليمة تُعرض **ورقة الاستعادة** تلقائيًا (ADR-0006) → ثم `autoCheckForUpdate()` (مرة كل 24 ساعة).
4. دورة الحياة (`didChangeAppLifecycleState`): `paused/hidden` → قفل PIN بعد المهلة + `flushBackupOnExit()` (إن فُعِّلت) · `resumed` → إعادة فحص الترخيص (≥10 دقائق).

## 2. البيانات (store.dart · db.dart · models.dart)

- **النموذج**: `Client`, `Invoice` (فاتورة أو عرض سعر حسب `kind`), `Payment` (سند قبض), `Claim` (خطاب مطالبة), `Org` (إعدادات المؤسسة والمستندات). كلها `toMap/fromMap` بلا مكتبات توليد.
- **Store** يحمل القوائم النشطة + سلة المحذوفات (`deletedAt`، تُحذف نهائيًا بعد 30 يومًا). كل `save*` يعيد كتابة **الجدول كاملًا في معاملة واحدة** (`replaceTables`) ثم `notifyListeners()` ثم يعلّم `backupDirty`. (تحسين `upsertRow` مؤجَّل — ROADMAP §3.)
- **SQLite** (`SqliteDb`): WAL، جدول لكل نوع + جدول `kv`. `integrityCheck()` عند الفتح. ترحيل لمرة واحدة من Hive القديم (≤2.2) إلى SQLite دون حذف الأصل.
- **kv**: إعدادات صغيرة (`autoBackup`, `storageAsked`, …). **قاعدة صارمة**: كل مفتاح في `Store.kvKeys` وإلا لا يُقرأ عند التشغيل — اختبار `store_test` يمسح `lib/` ويتحقق (درس د16).
- **Org.fromMap**: غياب مفتاح = القيمة الافتراضية، **إلا** `numberingMode`: خريطة غير فارغة بلا المفتاح ⇒ `seq` (مؤسسة قديمة)، خريطة فارغة ⇒ `datetime` (تثبيت جديد) — ADR-0003.

## 3. الترقيم (store.dart §الترقيم) — ADR-0003

- `Org.numberingMode`: `datetime` (الافتراضي) أو `seq`.
- `datetime`: `Store.datetimeNumber(prefix, taken)` ⇒ `<بادئة>YYYYMMDD-HHMMSS`، وعند التكرار في نفس الثانية `-1`, `-2`… يشمل الفواتير (`INV-`)، العروض (`QT-`)، المطالبات (`CLM-`)، **سندات القبض** (`REC-`).
- `seq`: أعلى رقم موجود + 1 مع `invPad` و`invStart` و(اختياريًا) السنة. أرقام نمط التاريخ **تُستثنى** من الحساب حتى لا يقفز التسلسل.
- كشف الحساب: `SOA-<سنةشهر>-<رمز ثابت من معرّف العميل>`.

## 4. الملفات على الهاتف (file_service.dart) — ADR-0001/0002

- الهدف: `/storage/emulated/0/<اسم التطبيق>/` وفيه: `الفواتير/`, `عروض الأسعار/`, `خطابات المطالبة/`, `كشوف الحساب/`, `سندات القبض/` — كلٌّ فيه **مجلد لكل عميل** (`clientFolder`: الاسم مُعقَّم، أو «بدون عميل») — و`النسخ الاحتياطية/` (بلا عملاء).
- **الصلاحية**: أندرويد 11+ يحتاج `MANAGE_EXTERNAL_STORAGE` للجذر. بدونها يسقط `_resolveBase()` إلى `Documents/<التطبيق>` = **وضع محدود** (ثم مجلد التطبيق الخارجي، ثم الداخلي) مع اختبار كتابة فعلي لكل مرشّح.
- **StorageGuard** (`ui/storage_guard.dart`): قبل النسخ/الاستعادة/نقل المجلد: إن لا صلاحية ⇒ حوار يشرح + «فتح الإعدادات» (يفتح شاشة النظام) + عند `resumed` يعيد الفحص ويُكمل؛ أو «متابعة بدون». `LimitedStorageBanner` شريط أصفر في شاشات الملفات/النسخ.
- **الترحيل**: عند تغيّر المسار (منح الصلاحية لاحقًا) تُنسخ الملفات القديمة دون حذف. ومرة واحدة (`kv pdfFoldersByClient`) تُنقل ملفات ≤2.5.0 من مجلدات السنة إلى مجلدات العملاء باستنتاج العميل من اسم الملف (`Store.clientFromFileName`).
- أسماء الملفات موحّدة: `فاتورة INV-… - <العميل>.pdf`, `كشف حساب - <العميل> - <تاريخ>.pdf`… (store.dart `fileNameFor*`).

## 5. النسخ الاحتياطي والاستعادة (backup_service.dart · restore_sheet.dart) — ADR-0004/0006

- **الملف**: JSON = غلاف (`app`, `brand`, `schema`, `counts`, `sha256`) + `data` (كل الجداول + org). البصمة على ترميز قانوني (مفاتيح مرتّبة).
- **الكتابة** (`writeLocal`): ملف مؤقت → flush → rename (ذرّية) → **إعادة قراءة وتحقق** → إن فشل يُحذف ويُعاد مرة. لا «نجاح» مزيّف.
- **متى**: يومية كل **24 ساعة** عند الفتح (`isDailyDue`, ملف `<بادئة>-auto-<اليوم>.json` يُستبدل في نفس اليوم؛ آخر 30) · يدوية `<بادئة>-backup-<وقت>.json` (لا تُحذف تلقائيًا) · «عند الخروج» **اختيارية مطفأة** (`backupOnExit`) · Google Drive يوميًا إن رُبط (الكود جاهز؛ يحتاج إعداد OAuth من المالك).
- **الاستعادة**: `verify()` أولًا (صيغة + بصمة + **نفس العلامة** — نسخة كيف لا تُسترجع في أصول) → تأكيد بعدد السجلات → `importJson` **يدمج** (upsert بالمعرّف) ولا يحذف. ورقة `showRestoreSheet` تعرض كل النسخ (الأحدث أولًا) + «ملف من مكان آخر». تلقائيًا بعد إعادة التثبيت مرة واحدة (`kv restoreOffered`).

## 6. القفل عن بُعد (license_service.dart)

- يقرأ `diafa-apps/<المجلد العربي>/license.json` عبر GitHub API (بلا كاش) ثم الخام كاحتياط. `active:false` ⇒ قفل ويطلب `code`؛ حذف الملف ⇒ قفل نهائي (فقط إن سبق رؤيته)؛ لا إنترنت ⇒ آخر حالة. مفاتيح prefs منفصلة لكل علامة `lic_<brand>_*`. البيانات لا تُمس أبدًا.
- اختبار حيّ ضد GitHub الفعلي: `test/license_live_audit_test.dart` (وسم audit).

## 7. التحديث داخل التطبيق (update_service.dart · update_screen.dart · MainActivity.kt) — ADR-0005

```
update.json ──API/raw──► UpdateInfo ──compare(installed)──► available?
   installed = قناة app.update.info: versionCode + nativeLibraryDir (…/lib/arm64|arm) ⇒ abi
   available ⇔ versionCodes[abi] > versionCode
download(apk) → cache/updates/<اسم>.apk (تقدّم) → sha256 == المنشور؟ لا ⇒ حذف + رفض
canInstall? لا ⇒ openInstallSettings (شاشة «تثبيت تطبيقات غير معروفة») → resumed → متابعة
install(path) → FileProvider "<applicationId>.update.fileprovider" → ACTION_VIEW مثبّت النظام
```
- **المعمارية من الـAPK المثبّت لا الجهاز** (درس د19). الفحص التلقائي كل 24 ساعة (`kv lastUpdateCheck`)؛ «لاحقًا» يحفظ `updateSkippedCode`. الزر اليدوي: الإعدادات → تحديث التطبيق.
- **الجانب الأصلي**: `MainActivity.kt` قناة `app.update` (`info`, `canInstall`, `openInstallSettings`, `install`) + Manifest: `REQUEST_INSTALL_PACKAGES` + `<provider>` مع `res/xml/update_paths.xml` (`cache-path updates/`).
- **النشر**: بعد رفع APKs، `python3 tools/make_update_json.py X.Y.Z N <apks> <diafa-apps>` ثم push. اختبار حيّ: `test/update_live_audit_test.dart`.
- ملف مفقود/تالف ⇒ «لا يمكن الوصول إلى خادم التحديث» أو `invalid` — **لا تحديث خاطئ أبدًا**.

## 8. المستندات PDF (lib/pdf)

- `DocPdf` (documents.dart): `invoice`, `statement`, `statementDetailed`, `receipt`, `claim`. الثيم الرسمي في `official_theme.dart` (`metaRow(label, value, ltr)`). خط Tajawal مضمّن.
- مكتبة `pdf` **معدّلة محليًا** (`third_party/pdf`, انظر `KEIF_PATCH.md`) لإصلاح مسافات RTL — لا تحدّثها من pub.
- **قاعدة bidi**: قيمة مختلطة (أرقام + حرف عربي مثل `2026/8/4 (1448/2/21هـ)`) يجب أن تكون RTL لا `ltr` وإلا تنعكس الأقواس (درس د14).
- **الهجري** (`hijri.dart`, ADR-0009): جدول أم القرى مضمّن 1420–1501هـ (بلا حزمة)، `fmtDateH(iso, hijri: org.hijriEnabled)` يعطي «ميلادي (هجري)». مطفأ افتراضيًا.
- التحقق البصري إلزامي لأي تغيير في PDF: `AGENT_GUIDE.md §3` (pymupdf → jpg → فحص بالعين/أداة الصور) ومعاينات مرجعية في `docs/renders/`.

## 9. الواجهة (lib/ui)

- ثيم واحد `theme.dart` (`C.*` ألوان، `AppTheme` night/day…)، ويدجات مشتركة `widgets.dart` (`GoldCard`, `Field`, `toast`, `confirm`, `runBusy`, `pickDate`), أيقونات `KIcon`/`Ic`.
- الإعدادات: `settings_screen.dart` (كبير — تقسيمه في ROADMAP) يضم `SettingsHub` → OrgForm / DocSettingsScreen (وحدات، حسابات، عناصر، ختم، **ترقيم**) / Appearance / Security / Trash / **UpdateScreen** / About، و`BackupScreen`.
- `SettingsHub.version` **يجب** أن يساوي `pubspec.yaml` (يظهر في الدرج وحول التطبيق).
- الدرج (`drawer.dart`): الوجهات + `DeveloperFooter` (تطوير م. معين العباسي ← واتساب) — ADR-0007.
- الأرقام الطويلة (نمط التاريخ) تحتاج `Flexible`/`FittedBox` — درس د17؛ اختبارات الدخان تكشف التجاوز.

## 10. الاختبارات (test/) — 153 + تدقيقات

| ملف | يغطي |
|---|---|
| `store_test` | SQLite حقيقي (ffi)، ترحيل Hive، استيراد متسامح، **حارس kvKeys** |
| `numbering_test` | الافتراضي، التوافق القديم، التكرار بنفس الثانية، التبديل بين النمطين |
| `file_layout_test` | مجلدات العميل، الترحيل، نسخة الخروج، 24 ساعة، عرض الاستعادة التلقائي |
| `update_service_test` | update.json، ABI، المقارنة، التنزيل + SHA-256 + رفض التالف (MockClient) |
| `hijri_test` | 53 تاريخًا رسميًا + دورة 28,700 يوم |
| `pdf_test`, `pdf_stress_test` | توليد كل المستندات إلى `build/test_pdfs/` |
| `ui_smoke_test` | كل شاشة × العلامتين — يلتقط `RenderFlex overflowed` |
| `license_test`, `security_test`, `brand_test`, `models_test`, `money_test`, `units_flow_test` | المنطق |
| **وسم `audit`** (لا يدخل في الافتراضي): `ux_metrics_audit` (لقطات 3 مقاسات + أهداف لمس)، `scale_bench_audit`، `license_live_audit`، `update_live_audit` (ضد GitHub الفعلي — تحتاج `HttpOverrides.global = null`) |

## 11. البناء والإصدار (مختصر — التفصيل في HANDOFF.md)

flavor × ABI = 4 ملفات. versionCode = `1000×ABI + N` (armv7 = 1000+N، arm64 = 2000+N). التوقيع من `diafa-signing-keys` (خاص) — SHA-1 `C8:74:A9:F4:…` ثابت وإلا يرفض أندرويد التثبيت فوق القديم. النشر: Release في `diafa-apps` + تحقق SHA-256 بعد التنزيل + **`update.json`** + CHANGELOG في المجلدين.

## 12. أين أغيّر ماذا؟

| أريد… | افتح |
|---|---|
| حقلًا جديدًا في الفاتورة | `models.dart` (Invoice + toMap/fromMap) → `doc_form.dart` → `documents.dart` → اختبار في `pdf_test` + معاينة |
| إعدادًا جديدًا | `Org` في `models.dart` → تبويب في `settings_screen.dart` → إن كان kv: `Store.kvKeys` |
| نوع مستند جديد | `FileKind` + `folder` في `file_service.dart` → `DocPdf` → شاشة → `fileNameFor*` في store |
| سلوك النسخ | `backup_service.dart` + `Store._scheduleAutoBackup/flushBackupOnExit` |
| صيغة update.json | `UpdateInfo.tryParse` + `tools/make_update_json.py` + README في diafa-apps (ثلاثتها معًا) |
| نصًا في الواجهة | ابحث عنه بـ grep؛ ثم `flutter test test/ui_smoke_test.dart` |
