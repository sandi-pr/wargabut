// web_share_service.dart
@JS()
library web_share_service;

import 'dart:async';
import 'package:js/js.dart';

@JS()
@anonymous
class ShareData {
  external factory ShareData({String? url, String? text, String? title});
}

@JS('navigator.share')
external Future<void> _shareJs(ShareData data);

@JS('navigator.share')
external get _webShareApi;

bool get isWebShareSupportedPlatform => _webShareApi != null;

Future<void> sharePlatform({String? url, String? text, String? title}) {
  return _shareJs(ShareData(title: title, text: text, url: url));
}