# كيف الضيافة — Keif Aldiafa

تطبيق Flutter/Android لمؤسسة **كيف الضيافة** (ضيافة مناسبات، جدة): فواتير، عروض أسعار، سندات قبض، كشوف حساب (مختصر وتفصيلي) بصيغة PDF رسمية، مع تخزين محلي كامل بلا خادم.

| | |
|---|---|
| الإصدار الحالي | **2.2.0+4** — [صفحة الإصدار والـ APK](https://github.com/MoTechSys/keif_blins/releases/tag/v2.2.0) |
| الحزمة | `com.hospitalitybilling.keif_diafa` — اسم المشروع `keif_diafa` |
| البيئة (مثبّتة، لا تُحدَّث) | Flutter **3.35.4** · Dart **3.9.2** · Android SDK 35 · JDK 17 |
| اللغة مع المستخدم | **العربية دائمًا** (المستخدم: «ياغالي») |

> **لوكيل جديد:** اقرأ هذا الملف ثم `docs/AGENT_GUIDE.md` (طريقة العمل ومعايير الدقة) ثم `CHANGELOG.md` (كل قرار وسببه). لا تبدأ أي تعديل قبل ذلك.

## تشغيل سريع

```bash
cd /home/user/flutter_app
flutter pub get
flutter analyze                      # يجب: No issues found
flutter test                         # يجب: All tests passed (32)
flutter build apk --release --split-per-abi   # arm64 ≈ 10.9 MB
```

اختبارات PDF تكتب ملفاتها في `build/test_pdfs/*.pdf` — هذه هي الطريقة المعتمدة لفحص أي تغيير في المستندات (انظر دليل الوكيل).

## بنية المشروع (5.6k سطر Dart)

```
lib/
  main.dart                RTL + عربية + الثيم → Shell
  core/
    money.dart             المال بالهللات (int)، الضريبة بالـ basis points، تفقيط عربي
    models.dart            Client / LineItem / Invoice(kind: invoice|quotation) / Payment / Org / Statement + buildStatement
    store.dart             Hive: clients, docs, payments, org + ترقيم + سلة محذوفات + نسخ احتياطي JSON
    file_service.dart      مجلد الهاتف Documents/كيف الضيافة/<النوع>/<السنة>/
    lock_service.dart      قفل PIN (SHA-256 + salt)
    share_service.dart     رسائل واتساب + مشاركة/طباعة
  pdf/
    official_theme.dart    الثيم الرسمي المعتمد (O: ألوان، officialTable RTL، ترويسة/تذييل، بطاقات)
    documents.dart         DocPdf: invoice() · statement() · statementDetailed() · receipt()
    pdf_theme.dart         الثيم «الملكي» القديم — لم يعد مستخدمًا في المستندات (مرجع فقط)
  ui/                      shell (5 تبويبات) · drawer · preview_screen · theme (3 ثيمات) · widgets
  ui/screens/              home, clients, docs, doc_form, doc_detail, payments, payment_form,
                           statements, settings (hub + doc settings + appearance + security + trash + about + backup),
                           files, lock, signin
third_party/pdf/           نسخة pdf 3.12.0 معدّلة (إصلاح مسافات RTL) — انظر KEIF_PATCH.md
test/                      money · models · store · security · pdf · pdf_stress (32 اختبارًا)
docs/
  AGENT_GUIDE.md           طريقة العمل، معايير الدقة، حلقة التحقق البصري، القرارات الثابتة
  reference/               النماذج المرجعية التي اعتمدها المستخدم (صور مصغّرة)
  renders/                 معاينات المخرجات الحالية لكل مستند
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
- خارج النطاق: Firebase، حسابات سحابية، الويب كمنتج (للمعاينة فقط).
