# ابدأ هنا — لأي وكيل/مطوّر جديد (اقرأه كاملًا قبل أي أمر)

> المالك: **بروفيسور** (م. معين العباسي، MoTechSys). يردّ بالعربية فقط. لا تقل «تم» إلا بعد تحقق ذاتي (اختبار/لقطة/بصمة).
> لا ترفع `.jks`/`key.properties`/توكن إلى مستودع عام. لا تجعل `diafa-apps` خاصًا ولا تغيّر أسماء مجلداته العربية. ادفع بعد كل خطوة منطقية.

## أول 10 دقائق في بيئة جديدة (انسخ ونفّذ بالترتيب)
```bash
# 1) الكود (إن لم يكن موجودًا في /home/user/flutter_app)
git clone https://github.com/MoTechSys/keif_blins /home/user/flutter_app && cd /home/user/flutter_app
git status                                   # البيئة قد تكتب main.dart/pubspec.yaml قالبًا افتراضيًا ⇒ git checkout -- .
flutter --version | head -1                  # يجب 3.35.4 — لا تحدّث أبدًا
flutter pub get && flutter analyze           # No issues found
flutter test --exclude-tags audit            # All tests passed (153 في 2.6.0) — إن فشل شيء فالبيئة مختلفة، لا تلمس الكود
# 2) المستودعان الآخران (للنشر/التحكم)
git clone https://github.com/MoTechSys/diafa-apps /home/user/diafa-apps
# مفاتيح التوقيع (خاص) — فقط عند البناء للنشر، وتبقى خارج git:
git clone https://github.com/MoTechSys/diafa-signing-keys /tmp/keys && cp /tmp/keys/android/release-key.jks /tmp/keys/android/key.properties android/
# 3) GitHub: استدعِ أداة setup_github_environment أولًا (تكتب ~/.git-credentials) — REST بـ curl، gh غير مثبّت
# 4) معاينة الويب (اختياري): DART_VM_OPTIONS="--old_gen_heap_size=4096" flutter build web --release --dart-define=BRAND=keif
#    ثم (setsid nohup python3 /home/user/preview_server.py &) — التفاصيل ودروس الـsandbox في AGENT_SKILLS §ب وهـ
```

## ما الذي أُنجز حتى الآن (ملخص سطرين)
تطبيقان منشوران حتى **2.6.0** (فواتير/عروض/سندات/كشوف/مطالبات PDF رسمي، SQLite، نسخ SHA-256، مجلدات بالعميل، هجري، ترقيم تاريخ/وقت، قفل عن بُعد، **تحديث داخل التطبيق**). المتبقي المطلوب من المالك في `ROADMAP.md`.

## ترتيب القراءة (15 دقيقة)
1. `ECOSYSTEM.md` — المستودعات الثلاثة، التوقيع، القفل عن بُعد، خطوات الإصدار.
2. `docs/ARCHITECTURE.md` — **كيف يعمل كل شيء** (الإقلاع، البيانات، الترقيم، الملفات، النسخ، القفل، التحديث، PDF) + «أين أغيّر ماذا».
3. `docs/HANDOFF.md` — **الحالة الآن** وخطوات النشر المنفَّذة (يُحدَّث كل جلسة).
4. `docs/ROADMAP.md` — **المؤجَّل المطلوب من المالك** (ابدأ به في 2.7.0).
5. `docs/adr/` — قرارات المالك الثابتة (لا تُغيَّر بلا طلب صريح منه).
6. `docs/AGENT_GUIDE.md` — حلقة العمل الإلزامية + التحقق البصري لـ PDF.
7. `docs/AGENT_SKILLS.md` — دروس البيئة (sandbox، iframe، حجب الشبكة في الاختبارات…).
8. `CHANGELOG.md` — ما تغيّر في كل إصدار.

## عند انتهاء كل جلسة (إلزامي — هكذا يستمر الوكيل التالي كأنه أنت)
1. `docs/HANDOFF.md`: الحالة الآن + ما المتبقي بالترتيب. 2. `CHANGELOG.md` تحت الإصدار الحالي. 3. قرار جديد من المالك ⇒ سطر في `docs/adr/README.md`. 4. درس بيئي جديد ⇒ `AGENT_SKILLS.md`. 5. commit عربي دقيق + push.

## أوامر التحقق الإلزامية قبل أي commit
```bash
cd /home/user/flutter_app && git status            # البيئة قد تستبدل main.dart/pubspec.yaml بقالب — git checkout -- . إن لزم
dart format lib test && flutter analyze            # يجب: No issues found
flutter test --exclude-tags audit                  # يجب: All tests passed (153 في 2.6.0)
flutter test test/ux_metrics_audit_test.dart       # تجاوزات الحدود = 0 على 320/360/412dp
```

## خريطة الكود (lib/)
| المجلد/الملف | المسؤولية |
|---|---|
| `core/store.dart` | الحالة + SQLite + الترقيم + سياسة النسخ. **كل مفتاح setKv يجب أن يكون في `Store.kvKeys`** (اختبار يحرس ذلك) |
| `core/file_service.dart` | `/storage/emulated/0/<التطبيق>/<الخدمة>/<العميل>/` + وضع محدود Documents |
| `core/backup_service.dart` | نسخة SHA-256 ذرّية + يومية كل 24 ساعة |
| `core/update_service.dart` | التحديث داخل التطبيق من `diafa-apps/<التطبيق>/update.json` (ADR-0005) |
| `core/license_service.dart` | القفل عن بُعد من `license.json` |
| `core/hijri.dart` | أم القرى مضمّن (1420–1501) |
| `ui/storage_guard.dart` | حوار الصلاحية الموحّد → إعدادات النظام → إعادة فحص |
| `ui/screens/restore_sheet.dart` | قائمة النسخ فورًا + عرض تلقائي بعد إعادة التثبيت |
| `ui/screens/update_screen.dart` | شاشة التحديث + الحوار التلقائي |
| `android/app/src/main/kotlin/com/hospitalitybilling/keif_diafa/MainActivity.kt` | قناتا `app.storage` و`app.update` (install عبر FileProvider `${applicationId}.update.fileprovider`) |
