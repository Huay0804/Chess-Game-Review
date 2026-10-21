class AppConfig {
  static const engineThreads = 2;
  static const engineHashMb = 64;
  static const multiPv = 2;
  static const engineTimeout = Duration(minutes: 3);
  static const handshakeTimeout = Duration(seconds: 15);
  static const engineStopTimeout = Duration(seconds: 2);
  static const maxCachedPositions = 4096;
  static const maxCachedMonths = 24;
}
