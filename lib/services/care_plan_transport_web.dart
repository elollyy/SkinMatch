// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

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
  late html.HttpRequest response;
  try {
    response = await html.HttpRequest.request(
      uri.toString(),
      method: method,
      sendData: payload == null ? null : json.encode(payload),
      requestHeaders: <String, String>{
        'Content-Type': 'application/json',
        ...headers,
      },
    );
  } on html.ProgressEvent catch (e) {
    final xhr = e.target as html.HttpRequest?;
    final statusCode = xhr?.status ?? 0;
    final body = xhr?.responseText ?? '';
    throw ApiHttpException(statusCode, body);
  }

  if (response.status != null &&
      (response.status! < 200 || response.status! >= 300)) {
    throw ApiHttpException(response.status!, response.responseText ?? '');
  }

  final decodedBody = json.decode(response.responseText ?? 'null');
  if (decodedBody is Map<String, dynamic>) {
    return decodedBody;
  }

  throw const FormatException('API response must be a JSON object');
}
