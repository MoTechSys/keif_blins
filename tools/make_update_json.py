#!/usr/bin/env python3
"""يُنشئ update.json لكل تطبيق من ملفات APK المنشورة (ADR-0005).
الاستخدام: python3 make_update_json.py <version> <build> <dir-with-apks> <out-diafa-apps-root>
"""
import hashlib, json, os, sys, datetime
version, build, apk_dir, out_root = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]
base = f"https://github.com/MoTechSys/diafa-apps/releases/download/v{version}/"
notes = {
 "keif": "الإصدار 2.6.0:\n• مجلدات PDF حسب العميل داخل كل خدمة\n• التاريخ الهجري (تفعيل/إيقاف من الإعدادات)\n• الترقيم التلقائي بالتاريخ والوقت\n• نسخة احتياطية يومية + اختيارية عند الخروج\n• استعادة تعرض كل النسخ فورًا\n• التحديث من داخل التطبيق",
}
notes["osool"] = notes["keif"]
apps = {"keif": ("كيف الضيافة", "keif-aldiafa"), "osool": ("أصول الضيافة", "asoul-aldiafa")}
def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for c in iter(lambda: f.read(1 << 20), b""): h.update(c)
    return h.hexdigest()
for brand, (folder, prefix) in apps.items():
    apks = {}
    for abi in ("arm64", "armv7"):
        fn = f"{prefix}-v{version}-{abi}.apk"
        p = os.path.join(apk_dir, fn)
        apks[abi] = {"url": base + fn, "sha256": sha(p), "size": os.path.getsize(p)}
    doc = {
        "version": version, "build": build,
        "versionCodes": {"arm64": 2000 + build, "armv7": 1000 + build},
        "apks": apks, "notes": notes[brand],
        "publishedAt": datetime.date.today().isoformat(),
        "minSupportedBuild": 2500,
    }
    out = os.path.join(out_root, folder, "update.json")
    with open(out, "w", encoding="utf-8") as f:
        json.dump(doc, f, ensure_ascii=False, indent=2); f.write("\n")
    print("wrote", out)
