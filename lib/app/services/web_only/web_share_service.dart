// web_share_service.dart
@JS()
library web_share_service;

import 'dart:js_interop';

@JS()
extension type ShareData._(JSObject _) implements JSObject {
  external factory ShareData({String? url, String? text, String? title});
}

@JS('navigator.share')
external JSPromise _shareJs(ShareData data);

@JS('navigator.share')
external JSAny? get _webShareApi;

bool get isWebShareSupportedPlatform => _webShareApi != null;

Future<void> sharePlatform({String? url, String? text, String? title}) async {
  await _shareJs(ShareData(title: title, text: text, url: url)).toDart;
}