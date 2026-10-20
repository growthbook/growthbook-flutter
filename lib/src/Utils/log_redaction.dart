import 'package:dio/dio.dart';

/// Replaces the client key in an SDK endpoint with `***`.
///
/// Every endpoint ends with the key as its last path segment
/// (`api/features/<key>`, `sub/<key>`, `api/eval/<key>`), so logging a URL as-is
/// copies the key into device logs and crash reports. The query string and
/// fragment are dropped as well: nothing there is worth logging and both are
/// easy places for identifiers to end up.
String redactUrl(String? url) {
  if (url == null || url.isEmpty) return '<no url>';

  final uri = Uri.tryParse(url);
  if (uri == null) return '<invalid url>';

  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.isNotEmpty) segments[segments.length - 1] = '***';

  final origin = uri.hasAuthority ? '${uri.scheme}://${uri.authority}' : '';
  return '$origin/${segments.join('/')}';
}

/// Describes a failed request without quoting anything the request carried.
///
/// A [DioException] stringifies with its request options attached, which for a
/// remote-evaluation POST means the user's attributes, and response bodies for
/// other calls. Only the diagnostic parts are logged; the error object itself is
/// still handed to the app through `GBError`, so an app that wants the full
/// detail can log it under its own privacy rules.
String describeRequestError(Object error) {
  if (error is DioException) {
    final status = error.response?.statusCode;
    return 'DioException(${error.type.name}'
        '${status != null ? ', status $status' : ''}) '
        'for ${redactUrl(error.requestOptions.uri.toString())}';
  }
  return error.runtimeType.toString();
}
