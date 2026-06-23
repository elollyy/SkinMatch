import 'dart:convert';
import 'dart:io';

import 'api_http_exception.dart';

Future<Map<String, dynamic>> postJson(
  Uri uri,
  Map<String, dynamic> payload,
) async {
  return requestJson('POST', uri, payload: payload);
}

Future<Map<String, dynamic>> getJson(
  Uri uri, {
  Map<String, String> headers = const <String, String>{},
}) async {
  return requestJson('GET', uri, headers: headers);
}

Future<Map<String, dynamic>> requestJson(
  String method,
  Uri uri, {
  Map<String, dynamic>? payload,
  Map<String, String> headers = const <String, String>{},
}) async {
  final client = HttpClient();

  try {
    final request = await client.openUrl(method, uri);
    request.headers.contentType = ContentType.json;
    headers.forEach(request.headers.set);
    if (payload != null) {
      request.write(json.encode(payload));
    }

    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    final decodedBody = body.isEmpty ? null : json.decode(body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiHttpException(response.statusCode, body);
    }

    if (decodedBody is Map<String, dynamic>) {
      return decodedBody;
    }

    throw const FormatException('API response must be a JSON object');
  } finally {
    client.close();
  }
}
