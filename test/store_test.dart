import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:keif_diafa/core/models.dart';
import 'package:keif_diafa/core/store.dart';

void main() {
  late Directory tmp;
  setUpAll(() {
    tmp = Directory.systemTemp.createTempSync('keif_store_');
    Hive.init(tmp.path);
    Store.skipHiveInit = true;
  });
  tearDownAll(() async {
    await Hive.close();
    tmp.deleteSync(recursive: true);
  });

  test('import tolerates corrupt records and keeps valid ones', () async {
    final s = Store();
    await s.init();
    expect(s.ready, isTrue);
    final json = jsonEncode({
      'app': 'keif-diafa',
      'schema': 2,
      'data': {
        'clients': [
          Client(name: 'عميل صالح').toMap(),
          'not-a-map',
          {'id': 'bad', 'openingBalance': 'xyz'}, // قد يُتجاوز أو يُقبل حسب النموذج
        ],
        'docs': [Invoice(clientId: 'c1', number: 'INV-0007').toMap(), 42],
        'payments': [null],
        'org': {'name': 'مؤسسة الاختبار'},
      },
    });
    final n = await s.importJson(json);
    expect(n, greaterThanOrEqualTo(2));
    expect(s.clients.any((c) => c.name == 'عميل صالح'), isTrue);
    expect(s.docs.any((d) => d.number == 'INV-0007'), isTrue);
    expect(s.org.name, 'مؤسسة الاختبار');
    // الترقيم يتخطى الرقم الأكبر ولا ينهار على أرقام ضخمة
    s.docs.add(Invoice(clientId: 'c1', number: 'INV-99999999999999999999999'));
    expect(() => s.nextNumber(DocKind.invoice), returnsNormally);
    expect(s.nextNumber(DocKind.invoice), endsWith('0008'));
    await s.wipe();
    expect(s.clients, isEmpty);
    expect(s.org.name, isNot('مؤسسة الاختبار'));
  });

  test('invalid backup rejected', () async {
    final s = Store();
    await s.init();
    expect(() => s.importJson('{"x":1}'), throwsA(isA<FormatException>()));
  });
}
