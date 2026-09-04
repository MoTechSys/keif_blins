import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:keif_diafa/core/file_service.dart';
import 'package:keif_diafa/core/lock_service.dart';

void main() {
  late Directory tmp;
  setUpAll(() {
    tmp = Directory.systemTemp.createTempSync('keif_lock_');
    Hive.init(tmp.path);
  });
  tearDownAll(() async {
    await Hive.close();
    tmp.deleteSync(recursive: true);
  });

  test('LockService: set / verify / wrong / disable', () async {
    // نستخدم صندوقًا مباشرًا لأن initFlutter يحتاج منصة
    final box = await Hive.openBox('keif_diafa_secure');
    final lock = LockService.withBox(box);
    expect(lock.enabled, isFalse);
    await lock.setPin('1234');
    expect(lock.enabled, isTrue);
    expect(lock.verify('1234'), isTrue);
    expect(lock.verify('0000'), isFalse);
    // الرمز غير مخزَّن كنص
    expect(box.values.any((v) => v == '1234'), isFalse);
    // تغيير الرمز يغيّر الـ salt
    final h1 = box.get('hash');
    await lock.setPin('1234');
    expect(box.get('hash'), isNot(equals(h1)));
    expect(lock.verify('1234'), isTrue);
    await lock.disable();
    expect(lock.enabled, isFalse);
  });

  test('LockService: cooldown after 5 failures', () async {
    final box = await Hive.openBox('keif_diafa_secure2');
    final lock = LockService.withBox(box);
    await lock.setPin('4321');
    for (var i = 0; i < 5; i++) {
      expect(await lock.unlock('9999'), isFalse);
    }
    expect(lock.cooldownSeconds, greaterThan(0));
    // حتى الرمز الصحيح يُرفض أثناء الانتظار
    expect(await lock.unlock('4321'), isFalse);
  });

  test('isValidPin', () {
    expect(LockService.isValidPin('1234'), isTrue);
    expect(LockService.isValidPin('123456'), isTrue);
    expect(LockService.isValidPin('123'), isFalse);
    expect(LockService.isValidPin('1234567'), isFalse);
    expect(LockService.isValidPin('12a4'), isFalse);
  });

  test('FileService helpers', () {
    expect(FileService.yearOf('2026-03-05'), '2026');
    expect(FileService.yearOf('garbage'), DateTime.now().year.toString());
    expect(FileService.safeName('INV/2026:01?.pdf'), 'INV-2026-01-.pdf');
    expect(FileKind.invoice.folder, 'الفواتير');
    expect(FileKind.backup.byYear, isFalse);
  });
}
