// share_service_gate.dart
export 'share_platform_stub.dart'
  if (dart.library.js) 'package:wargabut/app/services/web_only/web_share_service.dart'
  if (dart.library.io) 'mobile_share_service.dart';