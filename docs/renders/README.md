# معاينات المخرجات الحالية (v2.2.0+4)

تُولَّد من `build/test_pdfs/` بعد `flutter test` وتُصيَّر بـ pymupdf (dpi 85–110) ثم تُحفظ JPEG مضغوطًا. أعد توليدها عند أي تغيير بصري.

| الصورة | المستند |
|---|---|
| `invoice_p1.jpg` / `quotation_p1.jpg` | فاتورة وعرض سعر (INV-0042 الاختبارية: وصف متعدد الأسطر، مشتريات خارجية، عربون، خصم، ضريبة) |
| `statement_p1.jpg` | كشف حساب مختصر (30 فاتورة، صفحتان) |
| `statement_detailed_p1.jpg` / `_p3.jpg` | كشف تفصيلي: بطاقات بسيطة / بطاقات بمشتريات خارجية وعربون ووصف متعدد الأسطر |
| `statement_detailed_overview.jpg` | الصفحات الخمس معًا |
| `statement_detailed_stress_60_payments.jpg` | اختبار ضغط: 60 دفعة على فاتورة واحدة تنقسم على 3 صفحات |
| `receipt_invoice.jpg` / `receipt_on_account.jpg` | سند قبض لفاتورة / على الحساب (A5 عرضي) |
