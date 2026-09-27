/// db_factory.dart — اختيار مصنع SQLite حسب المنصة (استيراد شرطي حتى لا يُسحب كود أصلي في الويب)
library;

export 'db_factory_stub.dart' if (dart.library.io) 'db_factory_io.dart';
