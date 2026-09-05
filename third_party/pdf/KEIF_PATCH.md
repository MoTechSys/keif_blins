# pdf 3.12.0 — نسخة محلية معدّلة

مصدر: https://pub.dev/packages/pdf/versions/3.12.0 (رخصة Apache-2.0).

## التعديل
`lib/src/widgets/text.dart`: عند ترتيب الكلمات في السطر بالاتجاه RTL كان يُستخدم
عرض الحبر `metrics.width` (right - left) بدلاً من عرض التقدّم `advanceWidth`.
حروف مثل «ر» و«ز» في خط Tajawal لها `xMin` سالب (-93)، فكانت الكلمة تُزاح
يميناً بمقدار هذا الفرق وتبتلع المسافة التي تليها («نورسعيد» بدل «نور سعيد»).

أُضيف `rtlExtent` إلى `_Span` (يساوي `advanceWidth` للكلمات) ويُستخدم في
`_Line.realign` بدلاً من `left + width`.
