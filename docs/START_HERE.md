# ابدأ هنا — لأي وكيل/مطوّر جديد (اقرأه كاملًا قبل أي أمر)

> المالك: **بروفيسور** (م. معين العباسي، MoTechSys). يردّ بالعربية فقط. لا تقل «تم» إلا بعد تحقق ذاتي (اختبار/لقطة/بصمة).
> لا ترفع `.jks`/`key.properties`/توكن إلى مستودع عام. لا تجعل `diafa-apps` خاصًا ولا تغيّر أسماء مجلداته العربية. ادفع بعد كل خطوة منطقية.

## ترتيب القراءة (15 دقيقة)
1. `ECOSYSTEM.md` — المستودعات الثلاثة، التوقيع، القفل عن بُعد، خطوات الإصدار.
2. `docs/HANDOFF.md` — **الحالة الآن وما المتبقي** (يُحدَّث كل جلسة).
3. `docs/adr/` — قرارات المالك الثابتة (لا تُغيَّر بلا طلب صريح منه).
4. `docs/AGENT_GUIDE.md` — حلقة العمل الإلزامية + التحقق البصري لـ PDF.
5. `docs/AGENT_SKILLS.md` — دروس البيئة (sandbox، iframe، حجب الشبكة في الاختبارات…).
6. `CHANGELOG.md` — ما تغيّر في كل إصدار.

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
| `android/.../MainActivity.kt` | قناتا `app.storage` و`app.update` (install عبر FileProvider `${applicationId}.update.fileprovider`) |
