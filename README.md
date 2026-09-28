# كيف الضيافة / أصول الضيافة — الكود المصدري

> 🗺️ **هذا واحد من 3 مستودعات.** اقرأ [`ECOSYSTEM.md`](ECOSYSTEM.md) أولًا:
> - **keif_blins** (هنا) — الكود المصدري
> - [diafa-apps](https://github.com/MoTechSys/diafa-apps) — ملفات APK + القفل عن بُعد (`license.json`)
> - [diafa-signing-keys](https://github.com/MoTechSys/diafa-signing-keys) (خاص) — مفتاح التوقيع

كود Flutter واحد يبني **تطبيقَي أندرويد منفصلين** (flavors): **كيف الضيافة** و**أصول الضيافة** (ضيافة مناسبات، جدة): فواتير، عروض أسعار، سندات قبض، كشوف حساب، خطابات مطالبة — PDF رسمي، تخزين محلي (SQLite) بلا خادم، نسخ احتياطي يومي مُتحقَّق + Google Drive، قفل عن بُعد.

| | |
|---|---|
| الإصدار الحالي | **2.4.0+2400** — [التحميل من diafa-apps](https://github.com/MoTechSys/diafa-apps/releases/latest) (إصدارات ≤2.2.0 هنا قديمة وبمفتاح مختلف) |
| الحزمتان | `com.hospitalitybilling.keif_diafa` (flavor `keif`) · `com.hospitalitybilling.osool_diafa` (flavor `osool`) — اسم مشروع Dart `keif_diafa` |
| المنصة | **أندرويد فقط** (arm64 + armv7). الويب للمعاينة فقط |
| البيئة (مثبّتة، لا تُحدَّث) | Flutter **3.35.4** · Dart **3.9.2** · Android SDK 35 · JDK 17 |
| اللغة مع المستخدم | **العربية دائمًا** (المستخدم: «ياغالي») |

> **لوكيل جديد:** اقرأ `ECOSYSTEM.md` ثم هذا الملف ثم `docs/AGENT_GUIDE.md` (طريقة العمل ومعايير الدقة) ثم `CHANGELOG.md` (كل قرار وسببه). لا تبدأ أي تعديل قبل ذلك.

> 📌 **آخر تسليم:** [`docs/HANDOFF_2.5.0.md`](docs/HANDOFF_2.5.0.md) — الكود 2.5.0 مكتمل ومختبر؛ المتبقي البناء والنشر.

## تشغيل سريع

```bash
cd /home/user/flutter_app
flutter pub get
flutter analyze                      # يجب: No issues found
flutter test                         # يجب: All tests passed (102)
# البناء يحتاج مفتاح التوقيع من diafa-signing-keys (انظر ECOSYSTEM.md)
flutter build apk --release --flavor keif  --dart-define=BRAND=keif  --split-per-abi --target-platform android-arm,android-arm64
flutter build apk --release --flavor osool --dart-define=BRAND=osool --split-per-abi --target-platform android-arm,android-arm64
```

اختبارات PDF تكتب ملفاتها في `build/test_pdfs/*.pdf` — هذه هي الطريقة المعتمدة لفحص أي تغيير في المستندات (انظر دليل الوكيل).

## بنية المشروع (~18.7k سطر Dart)

```
lib/
  main.dart                RTL + عربية + الثيم + المزوّدات (Store, LockService, LicenseService) → Shell
  core/
    brand.dart             هوية التطبيقين (keif/osool): الاسم، قاعدة البيانات، المجلد، الشعار، بيانات المؤسسة
    money.dart             المال بالهللات (int)، الضريبة بالـ basis points، تفقيط عربي
    models.dart            Client / LineItem / Invoice(invoice|quotation) / Payment / Claim / Org / Statement
    db.dart + db_factory*  AppDb: SqliteDb (WAL, synchronous=FULL, معاملات) على أندرويد · HiveDb للويب + ترحيل Hive القديم
    store.dart             الحالة كاملة: ترقيم، سلة محذوفات 30 يومًا، مطالبات، معاملات ذرّية
    backup_service.dart    نسخ JSON بغلاف SHA-256 + تحقق بالقراءة الراجعة + نسخة يومية تلقائية (30)
    drive_service.dart     Google Drive (appDataFolder لكل مستخدم) — يحتاج إعداد OAuth (ECOSYSTEM.md)
    file_service.dart      /storage/emulated/0/<اسم التطبيق>/{فواتير,عروض,مطالبات,كشوف,سندات,نسخ}
    license_service.dart   القفل عن بُعد من diafa-apps/<المجلد>/license.json
    lock_service.dart      قفل PIN (SHA-256 + salt)
    share_service.dart     رسائل واتساب + مشاركة/طباعة
  pdf/
    official_theme.dart    الثيم الرسمي (officialTable RTL، ترويسة/تذييل)
    documents.dart         DocPdf: invoice · statement · statementDetailed · receipt · claim
  ui/                      shell (بوابات: ترخيص ← دخول ← مجلد ← قفل PIN) · drawer · preview · theme · widgets
  ui/screens/              home, clients, docs, doc_form, doc_detail, payments, payment_form, statements,
                           claims, settings (+backup/trash/security/appearance/about), files, lock,
                           license, signin, storage_setup
android/app/src/osool/     أيقونات أصول الضيافة (flavor)
assets/brand/{keif,osool}/ الشعار، الختم، شعار PDF لكل تطبيق
third_party/pdf/           pdf 3.12.0 معدّلة (مسافات RTL) — KEIF_PATCH.md
test/                      money · models · store · security · pdf · pdf_stress · brand · license · ui_smoke (102)
docs/                      AGENT_GUIDE.md · reference/ (نماذج المستخدم) · renders/ (معاينات المخرجات)
```

## المستندات (PDF)

| المستند | الدالة | المرجع | المعاينة |
|---|---|---|---|
| فاتورة / عرض سعر | `invoice()` | `docs/reference/ref_invoice_official.jpg` | `docs/renders/invoice_p1.jpg` |
| كشف حساب مختصر | `statement()` | `docs/reference/ref_statement_official.jpg` | `docs/renders/statement_p1.jpg` |
| كشف حساب تفصيلي | `statementDetailed()` | يعكس الفاتورة بالكامل | `docs/renders/statement_detailed_*.jpg` |
| سند قبض (A5 عرضي) | `receipt()` | `docs/reference/ref_receipt_halfpage.jpg` | `docs/renders/receipt_*.jpg` |

## قرارات ثابتة (لا تُغيَّر بلا طلب صريح من المستخدم)

- المال `int` بالهللات؛ الضريبة bp (1500 = 15%)؛ الافتراضي **بدون ضريبة** حتى تُفعَّل من الإعدادات.
- الضريبة والخصم **يختفيان** من المستند إذا لم يكونا مفعّلين/موجودين. لا تُخترع بيانات.
- كتلة الإجماليات على **اليسار**؛ عمود «م»؛ حدود واضحة؛ ملف PDF خفيف.
- الكشف المختصر: دفتر كلاسيكي (مدين أحمر / دائن أخضر / رصيد)، بلا «رصيد افتتاحي» إلا «رصيد سابق قبل الفترة» عند التصفية بفترة.
- الخطوط في `assets/fonts/` معالَجة خصيصًا لمكتبة pdf — **لا تستبدلها** بنسخ Google الأصلية.
- الحزمة تُنشر **لكل معمارية** (`--split-per-abi`)؛ الشاملة ثلاثة أضعاف الحجم لأنها تحمل المحرك 3 مرات.
- خارج النطاق: Firebase، iOS، الويب كمنتج (للمعاينة فقط).
- **لا تغيّر أبدًا:** أسماء الحزم، مفتاح التوقيع، مسار ملفات القفل في diafa-apps — كلها مقروءة من التطبيقات المثبّتة.
