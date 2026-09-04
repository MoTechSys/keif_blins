# HANDOFF — كيف الضيافة (Keif Aldiafa) — نظام الفواتير وكشوف الحساب

> **اقرأ هذا الملف أولًا قبل أي تعديل.** هذا توثيق تسليم بين جلسات العمل.
> اللغة مع المستخدم: **عربي (مصري/سعودي بسيط)**.

---

## 1. ماذا يريد المستخدم (النطاق الصارم)

المستخدم ("ياغالي") لديه PWA قديم (vanilla JS) لمؤسسة **كيف الضيافة** (ضيافة/كوفي للمناسبات، جدة).
قال إن المشروع القديم "غير مهني وفيه قصور" والفواتير لا تُطبع بالشكل المطلوب. طلب:

1. **إعادة بناء المشروع كتطبيق Flutter/Android (APK فقط)** — حجم صغير ودقيق.
2. **طباعة الفواتير + عروض الأسعار + كشوف الحساب** بترويسة كاملة وبنمط **"الفخامة الملكية"**:
   كحلي `#17264f` / ذهبي `#C9A961` / كريمي، إطار ذهبي مزدوج، زخارف أركان، شريط عنوان ذهبي، رأس جدول كحلي، تذييل كحلي فيه IBAN.
   المرجع: `DESIGN-SPEC.md` من حزم التصميم التي رفعها (`keif-aldiafa-delivery-note-system.zip`, `keif-aldiafa-receipt-voucher-package.zip`) — مستخرجة في `/home/user/analysis/`.
3. **مشاركة الفاتورة كـ PDF مع رسالة** (واتساب وغيره).
4. **اختبارات** تعمل، شغل "دقيق جدًا جدًا جدًا"، تصميم رائع، خفيف، سهل.
5. الرد **بالعربية**.

**خارج النطاق:** Firebase، حسابات مستخدمين، ويب كمنتج نهائي (الويب فقط للمعاينة).

ملاحظات جانبية للمستخدم (لم تُقال له بعد في هذه الجلسة):
- قال إنه أنشأ ريبو GitHub نظيف ورفع كل شيء — **لم نجد أي ريبو مطابق** على حسابه `moain2026`. اسأله عن الرابط.
- سبق ونصحناه بإلغاء توكن `ghp_Z6DR…` المكشوف — كرّر التنبيه.

---

## 2. حالة المشروع الآن (100% محفوظ في git)

- المسار: `/home/user/flutter_app/` — Flutter 3.35.4 / Dart 3.9.2 — اسم الحزمة `keif_diafa`.
- App info: **Hospitality Billing** / `com.hospitalitybilling.invoice`.
- Git: فرع `main`، آخر commit `e2c3fe0 genspark auto-backup`، **لا تغييرات غير ملتزمة** (تحقّق بـ `git status`).
- `flutter analyze` → **0 issues**.
- `flutter test` → **20/20 passed** ولا توجد أي تحذيرات خطوط (تم إصلاح `◆`/`←`).
- **لم يُبنَ بعد**: لا web preview ولا APK.
- لا أيقونة مخصصة بعد.

### الحِزم (pubspec.yaml)
`provider 6.1.5+1`, `hive 2.2.3`, `hive_flutter 1.1.0`, `pdf ^3.11.3` (3.12.0), `printing ^5.14.2`, `share_plus ^10.1.4`, `path_provider 2.1.5`, `intl 0.20.2`, `flutter_localizations`.
خط Tajawal (Regular/Bold w700/Black w900) في `assets/fonts/`، صور `assets/img/logo.png` (30KB) و `stamp.png` (22KB).

### بنية الكود
```
lib/
  main.dart                  KeifApp (RTL, ar, dark navy/gold theme) → Shell
  core/money.dart            هللات (int) + VAT بالـ basis points + roundHalfUp + تفقيط عربي
  core/models.dart           Client, LineItem, Invoice(kind: invoice|quotation), Payment, Org, Statement builder
  core/store.dart            Hive box 'keif_diafa' (keys: clients, docs, payments, org) + ترقيم INV-/QT-/REC-/SOA- + تحويل عرض→فاتورة + نسخ احتياطي JSON (يستورد بيانات PWA القديم)
  core/share_service.dart    رسائل عربية + Share.shareXFiles / Printing.layoutPdf
  pdf/pdf_theme.dart         الثيم الملكي: PageTheme (خلفية كريمي + علامة مائية + إطار ذهبي مزدوج + زخارف أركان CustomPaint)، royalHeader, titleBand, dataCard, royalFooter, pageNum, signatures, goldDiamond
  pdf/documents.dart         DocPdf: invoice() (فاتورة أو عرض سعر), statement(), receipt()
  ui/theme.dart, widgets.dart, preview_screen.dart (PdfPreview + طباعة/مشاركة), shell.dart (5 تبويبات)
  ui/screens/ home, clients, client_form, docs (فواتير/عروض), doc_form, doc_detail, payment_form, statements, settings
test/ money_test.dart, models_test.dart, pdf_test.dart (يكتب build/test_pdfs/*.pdf)
```

---

## 3. ما تم إنجازه في هذه الجلسة تحديدًا

1. استبدال رمزَي `◆` و`←` غير المتوفرين في Tajawal:
   - `goldDiamond()` (معيّن ذهبي مرسوم بـ `Transform.rotateBox`) في `pdf_theme.dart` ويُستخدم في `dataCard` و`_descCell`.
   - نطاق التاريخ صار «من X إلى Y» بدل السهم.
2. **إصلاح مشكلة عرض الحروف العربية في PDF**: كانت بعض الحروف تُرسم بأشكال غلط (مثلًا «العميل» تظهر «ي لعميل»، «العمر» تظهر «العمق»). السبب: مكتبة `pdf` تقرأ cmap الخط بطريقة تتعارض مع ترتيب glyphs الأصلي.
   الحل المطبّق على الخطوط الثلاثة في `assets/fonts/` (بـ fontTools):
   - `pyftsubset --unicodes='*' --layout-features='*' --no-hinting` (تنظيف) ← 52KB لكل خط.
   - إعادة ترتيب glyphs حسب Unicode تصاعديًا (`reorderGlyphs`).
   - حذف جداول cmap غير Windows (إبقاء platformID 3 فقط).
   **النتيجة**: التفقيط والعناوين والجداول سليمة. ⚠️ **ما زال هناك خلل في تسميات `dataCard` فقط** (انظر البند 4.1).
3. توسيع عمود التسمية في `dataCard` إلى `26 * mm` مع `maxLines:1, softWrap:false` (السطر 304 في pdf_theme.dart).
4. تثبيت `pymupdf` + `fonttools` في الساندبوكس للفحص البصري (`pdftoppm` غير موجود).

---

## 4. المتبقي — بالترتيب

### 4.1 ✅ محلول — خلل عرض نص التسميات في `dataCard` (والأوصاف الفرعية/الملاحظات)
**السبب الحقيقي (ليس Layout):** مكتبة `pdf` مع `useBidi=true` تحوّل العربية إلى Presentation Forms (U+FE70–FEFF). خط Tajawal لا يحوي كل الأشكال المعزولة، فـ `ttf_parser._parseCMapFormat4` يربط الكود الناقص بنفس glyph الحرف الأساسي. عند تضمين الخط (`ttf_writer.withChars`) يُحذف الـ glyph المشترك مرة واحدة من `glyphsMap` ثم يعود fallback `glyphsMap.values.first` → حرف خاطئ. يظهر الخلل فقط في السطور التي تجتمع فيها الحرف الأساسي وشكله المعزول.
**الحل المطبّق:** إعادة بناء الخطوط الثلاثة من نسخة Google الأصلية بـ fontTools مع **إضافة glyph منفصل (نسخة glyf+hmtx) لكل شكل عرض ناقص (51 شكلًا)** بحيث لكل codepoint glyph مستقل. لا تغيير في كود Dart. تم التحقق بصريًا للمستندات الأربعة.
**إصلاح إضافي:** `_contact()` في `pdf_theme.dart` كان يفرض LTR على عنوان الترويسة العربي → أُضيف `{bool ltr = true}` ويُمرَّر `ltr: false` للعنوان.

<details><summary>الوصف القديم للمشكلة</summary>

في بطاقتَي «بيانات العميل / بيانات الفاتورة» التسميات (العميل، جهة الاتصال، الهاتف، الرقم الضريبي، العنوان، رقم الفاتورة، تاريخ الإصدار، تاريخ المناسبة، الموقع، عدد الحضور) تظهر **بأحرف مقطّعة/معكوسة جزئيًا** («ي لعميل»، «اقم لفاتواف»، «تاايخ لإصيا»)، بينما **القيم** بجانبها والعناوين والجداول **سليمة 100%**.
- المؤثر الظاهر: النص داخل `pw.SizedBox(width: 26*mm, child: pw.Text(...))` داخل `pw.Row` — احتمال أن السبب هو اتجاه/التفاف داخل Row مع `Expanded`، أو أن `pw.Row` داخل RTL يقلب ترتيب الـ runs.
- **خطوات مقترحة**: 
  1. جرّب لفّ التسمية في `pw.Directionality(textDirection: pw.TextDirection.rtl, child: ...)` أو استخدام `pw.Text(..., textDirection: pw.TextDirection.rtl)`.
  2. أو استبدل الـ Row بـ `pw.Table` بعمودين (نفس أسلوب الجداول التي تعمل سليمة).
  3. أعد: `flutter test test/pdf_test.dart` ثم صيّر بـ pymupdf وافحص:
     ```bash
     cd /home/user/flutter_app/build/test_pdfs && python3 -c "
     import pymupdf; p=pymupdf.open('invoice.pdf')[0]; r=p.rect
     p.get_pixmap(dpi=200, clip=pymupdf.Rect(0,r.height*0.18,r.width,r.height*0.31)).save('inv-zoom.png')"
     ```
     ثم `Read` الصورة.
- حالة `→` في نطاق الحدث: تم استبدالها، لا مشكلة.
</details>

### 4.2 ✅ تم — فحص بصري كامل للـ 4 مستندات
صُيِّرت الفاتورة وعرض السعر وكشف الحساب (صفحتان، 30 فاتورة + 15 دفعة، رصيد جارٍ متراكم صحيح) وسند القبض بـ pymupdf — كلها سليمة (نصوص، تفقيط، جداول، فوتر، توقيعات). تم تعديل fixture اختبار الكشف ليستخدم `status: 'sent'` (المسودات تُستبعد من الدفتر بتصميم) وأُضيف assert على تعدد الصفحات.

<details><summary>التعليمات القديمة</summary>
`invoice.pdf`, `quotation.pdf`, `statement.pdf`, `receipt.pdf` في `build/test_pdfs/` — صيّر كل صفحة (dpi 75 كاملة + مقاطع 150-200) وقارن مع المرجع `hungerstation-filled.png` و`preview-a4-page.png` في `/home/user/analysis/`. الفاتورة عمومًا **مطابقة للنمط الملكي** (شوهدت كاملة وكانت ممتازة عدا 4.1).
</details>

### 4.3 أيقونة التطبيق
`image_generation` (192×192 مربع، كحلي/ذهبي، فنجان قهوة/شعار كيف الضيافة) → `DownloadFileWrapper` إلى `/home/user/assets/icons/app_icon.png` → 
`cd /home/user/flutter_app && python3 /opt/flutter/scripts/integrate_app_icon.py /home/user/assets/icons/app_icon.png`

### 4.4 معاينة ويب (للفحص فقط)
```bash
cd /home/user/flutter_app && flutter analyze && flutter build web --release && cd build/web && python3 -c "import http.server, socketserver
class H(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin','*'); self.send_header('X-Frame-Options','ALLOWALL'); self.send_header('Content-Security-Policy','frame-ancestors *'); super().end_headers()
socketserver.TCPServer(('0.0.0.0',5060),H).serve_forever()" &
```
ثم `GetServiceUrl(5060)` وافحص الشاشات الخمس + إنشاء فاتورة + معاينة PDF.

### 4.5 بناء APK (المُخرَج النهائي الوحيد للمستخدم)
`flutter_signing_tool(build_type: apk, build_command: "cd /home/user/flutter_app && flutter build apk --release")`
- تحقق من الحجم (الهدف: صغير — ~15-20MB متوقع). لو كبير: `--split-per-abi` أو `--target-platform android-arm64`.
- ثم `flutter_build_completion_notifier`.

### 4.6 git commit + تقرير عربي للمستخدم
- `git add -A && git commit -m "..."` (الدفع تلقائي لريموت genspark آخر الدور).
- التقرير يشمل: تحليل قصور المشروع القديم، ما بُني، رابط APK، سؤاله عن ريبو GitHub «النظيف»، تذكير إلغاء التوكن.

---

## 5. أوامر التشغيل السريعة
```bash
cd /home/user/flutter_app
flutter analyze                 # يجب 0 issues
flutter test                    # يجب 20/20
git status                      # يجب نظيف
```

## 6. قرارات تصميم مهمة (لا تغيّرها)
- المال بالهللات int؛ VAT بالـ bp (1500=15%)؛ `roundHalfUp`.
- الفاتورة وعرض السعر نفس الموديل `Invoice` مع `DocKind`; عروض الأسعار لا تدخل كشف الحساب (`countsInLedger`).
- كشف الحساب: رصيد افتتاحي = openingBalance + (فواتير − عربون − دفعات) قبل الفترة.
- الخطوط تُحمَّل بـ `pw.Font.ttf` من `rootBundle` عبر `PdfAssets.load()` (singleton). لا تستبدل ملفات الخط بالنسخ الأصلية من Google Fonts — النسخ الحالية معالَجة خصيصًا لمكتبة pdf.
- الثيم: `K` في `pdf_theme.dart` و`C` في `ui/theme.dart`.
