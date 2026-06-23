Future<Map<String, dynamic>> postJson(
  Uri uri,
  Map<String, dynamic> payload,
) async {
  throw UnsupportedError('Care plan transport is unavailable on this platform');
}

Future<Map<String, dynamic>> getJson(
  Uri uri, {
  Map<String, String> headers = const <String, String>{},
}) async {
  throw UnsupportedError('Care plan transport is unavailable on this platform');
}

Future<Map<String, dynamic>> requestJson(
  String method,
  Uri uri, {
  Map<String, dynamic>? payload,
  Map<String, String> headers = const <String, String>{},
}) async {
  throw UnsupportedError('Care plan transport is unavailable on this platform');
}
