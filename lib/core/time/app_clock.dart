import 'package:injectable/injectable.dart';

@lazySingleton
class AppClock {
  DateTime nowUtc() => DateTime.now().toUtc();
}
