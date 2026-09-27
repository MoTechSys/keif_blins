/// signin_screen.dart — شاشة الدخول: بحساب Google أو المتابعة بدون تسجيل | كيف الضيافة
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/brand.dart';
import '../../core/drive_service.dart';
import '../../core/store.dart';
import '../theme.dart';
import '../widgets.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _busy = false;

  Future<void> _google() async {
    setState(() => _busy = true);
    try {
      final store = context.read<Store>();
      // نفس جلسة Google المستخدمة للنسخ السحابي (صلاحية مجلد التطبيق في Drive فقط)
      final acc = await DriveService.signIn();
      if (acc == null) {
        if (mounted) toast(context, 'تم إلغاء الدخول');
        return;
      }
      await store.setAccount(
        name: acc.displayName ?? '',
        email: acc.email,
        photo: acc.photoUrl ?? '',
      );
      await store.setKv('driveAuto', true);
    } catch (e) {
      debugPrint('google sign-in: $e');
      if (mounted) {
        toast(
          context,
          'تعذّر الدخول بحساب Google — يمكنك المتابعة بدون تسجيل',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _guest() => context.read<Store>().setAccount();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [C.bg2, C.bg],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        C.gold.withValues(alpha: 0.22),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  // الشعار بنص أبيض (كيف الضيافة / KEIF ALDIAFA) على الخلفية الداكنة؛ الأصلي على الفاتحة
                  child: Image(
                    image: AssetImage(
                      C.isDark ? Brand.current.logoLight : Brand.current.logo,
                    ),
                    width: 150,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  Brand.current.orgName,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: C.text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'نظام الفواتير وكشوف الحساب وسندات القبض',
                  style: TextStyle(
                    color: C.text2,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                _Feature(Ic.invoice, 'فواتير وعروض أسعار احترافية بضغطة'),
                _Feature(Ic.statement, 'كشوف حساب وسندات قبض جاهزة للمشاركة'),
                _Feature(Ic.stamp, 'بياناتك محفوظة على جهازك مع نسخ احتياطي'),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _google,
                    icon: _busy
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: C.onGold,
                            ),
                          )
                        : const _GoogleG(),
                    label: const Text(
                      'الدخول بحساب Google',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _guest,
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                    label: const Text(
                      'المتابعة بدون تسجيل دخول',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'حساب Google يُستخدم للنسخ الاحتياطي اليومي إلى Google Drive فقط (مجلد خاص بالتطبيق). بياناتك الأصلية تبقى على جهازك.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: C.text3, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final String icon, text;
  const _Feature(this.icon, this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        KIcon(icon, size: 34),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: C.text,
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
        ),
      ],
    ),
  );
}

/// حرف G ملوّن (شعار Google المبسّط) بدون أصول خارجية
class _GoogleG extends StatelessWidget {
  const _GoogleG();
  @override
  Widget build(BuildContext context) => Container(
    width: 22,
    height: 22,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
    ),
    child: const Text(
      'G',
      style: TextStyle(
        color: Color(0xFF4285F4),
        fontWeight: FontWeight.w900,
        fontSize: 14,
        fontFamily: 'Roboto',
      ),
    ),
  );
}
