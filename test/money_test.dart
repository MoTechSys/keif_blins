import 'package:flutter_test/flutter_test.dart';
import 'package:keif_diafa/core/money.dart';

void main() {
  group('toHalalas', () {
    test('parses numbers and strings', () {
      expect(toHalalas(12.5), 1250);
      expect(toHalalas('1,045.50'), 104550);
      expect(toHalalas('ر.س 1,045'), 104500);
      expect(toHalalas('١٢٣٤٫٥٠'), 123450);
      expect(toHalalas(''), 0);
      expect(toHalalas(null), 0);
      expect(toHalalas('1e5'), 0);
      expect(toHalalas('-20'), -2000);
      expect(toHalalasPositive('-20'), 0);
    });
  });

  group('fmt', () {
    test('formats thousands and decimals', () {
      expect(fmt(2131000), '21,310.00');
      expect(fmt(2131000, trimZeros: true), '21,310');
      expect(fmt(578050), '5,780.50');
      expect(fmt(-1500), '-15.00');
      expect(fmtSAR(578000), '5,780.00 ر.س');
      expect(fmtSARSmart(578000), '5,780 ر.س');
      expect(fmtQty(2), '2');
      expect(fmtQty(1.5), '1.5');
    });
  });

  group('roundHalfUp', () {
    test('rounds .5 away from zero', () {
      expect(roundHalfUp(2.5), 3);
      expect(roundHalfUp(2.4), 2);
      expect(roundHalfUp(-2.5), -3);
    });
  });

  group('tafqit', () {
    test('basic grammar', () {
      expect(tafqit(0), 'فقط صفر ريال سعودي لا غير');
      expect(tafqit(100), 'فقط ريال سعودي لا غير');
      expect(tafqit(200), 'فقط ريالان سعوديان لا غير');
      expect(tafqit(300), 'فقط ثلاثة ريالات سعودية لا غير');
      expect(tafqit(1000), 'فقط عشرة ريالات سعودية لا غير');
      expect(tafqit(1100), 'فقط أحد عشر ريالًا سعوديًا لا غير');
      expect(tafqit(2100), 'فقط واحد وعشرون ريالًا سعوديًا لا غير');
      expect(tafqit(10000), 'فقط مائة ريال سعودي لا غير');
      expect(tafqit(20000), 'فقط مائتا ريال سعودي لا غير');
      expect(tafqit(10100), 'فقط مائة وواحد ريال سعودي لا غير');
    });
    test('thousands and millions', () {
      expect(tafqit(100000), 'فقط ألف ريال سعودي لا غير');
      expect(tafqit(200000), 'فقط ألفا ريال سعودي لا غير');
      expect(tafqit(300000), 'فقط ثلاثة آلاف ريال سعودي لا غير');
      expect(tafqit(1100000), 'فقط أحد عشر ألف ريال سعودي لا غير');
      expect(tafqit(2131000), 'فقط واحد وعشرون ألفًا وثلاثمائة وعشرة ريالات سعودية لا غير');
      expect(tafqit(20000000), 'فقط مائتا ألف ريال سعودي لا غير');
      expect(tafqit(100000000), 'فقط مليون ريال سعودي لا غير');
      expect(tafqit(578000), 'فقط خمسة آلاف وسبعمائة وثمانون ريالًا سعوديًا لا غير');
    });
    test('halalas feminine', () {
      expect(tafqit(150), 'فقط ريال سعودي وخمسون هللة لا غير');
      expect(tafqit(101), 'فقط ريال سعودي وهللة لا غير');
      expect(tafqit(102), 'فقط ريال سعودي وهللتان لا غير');
      expect(tafqit(103), 'فقط ريال سعودي وثلاث هللات لا غير');
      expect(tafqit(111), 'فقط ريال سعودي وإحدى عشرة هللة لا غير');
      expect(tafqit(125), 'فقط ريال سعودي وخمس وعشرون هللة لا غير');
      expect(tafqit(-100), 'فقط سالب ريال سعودي لا غير');
    });
  });
}
