import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:growthbook_sdk_flutter/src/Network/lru_etag_cache.dart';
import 'package:growthbook_sdk_flutter/src/Network/sse_event_transformer.dart';

typedef OnSuccess = Future<void> Function(Map<String, dynamic> onSuccess);
typedef OnError = void Function(Object error, StackTrace stackTrace);

abstract class BaseClient {
  const BaseClient();

  /// [headers] carries the caller-configured request headers
  /// (`apiHostRequestHeaders` / `streamingHostRequestHeaders`). They are added
  /// to the request, never in place of the headers the SDK manages itself.
  Future<void> consumeGetRequest(
    String url,
    OnSuccess onSuccess,
    OnError onError, {
    Map<String, String>? headers,
  });

  Future<void> consumePostRequest(
    String baseUrl,
    Map<String, dynamic> params,
    OnSuccess onSuccess,
    OnError onError, {
    Map<String, String>? headers,
  });

  Future<void> consumeSseConnections(
    String url,
    OnSuccess onSuccess,
    OnError onError, {
    Map<String, String>? headers,
  });
}

class DioClient extends BaseClient {
  DioClient() : _dio = Dio();

  final Dio _dio;

  Dio get client => _dio;
  String? lastKnownId;

  final LruEtagCache _etagCache = LruEtagCache(maxSize: 100);

  final _featuresRegex = RegExp(r'.*/api/features/[^/]+');

  Future<void> listenAndRetry({
    required String url,
    required OnSuccess onSuccess,
    required OnError onError,
    Map<String, String>? headers,
  }) async {
    try {
      log('Establishing SSE connection to: $url');
      final resp = await _dio.get(
        url,
        options: Options(
          responseType: ResponseType.stream,
          headers: headers == null ? null : Map<String, String>.from(headers),
        ),
      );

      final data = resp.data;
      final statusCode = resp.statusCode;

      if (data is ResponseBody) {
        data.stream
            .cast<List<int>>()
            .transform(const Utf8Decoder())
            .transform(const SseEventTransformer())
            .listen(
          (sseModel) async {
            log('SSE event received: ${sseModel.name}');
            if (sseModel.name == "features" && lastKnownId != sseModel.id) {
              final data = sseModel.data;
              if (data == null || data.isEmpty) return;
              try {
                final decoded = jsonDecode(data);
                if (decoded is! Map<String, dynamic>) {
                  onError(
                    FormatException('SSE payload is not a JSON object', data),
                    StackTrace.current,
                  );
                  return;
                }
                lastKnownId = sseModel.id;
                await onSuccess(decoded);
              } catch (e, s) {
                onError(e, s);
              }
            }
          },
          onError: (dynamic e, dynamic s) async {
            onError(e, s);
          },
          onDone: () async {
            log('SSE connection closed with status: $statusCode');
            if (statusCode != null && shouldReconnect(statusCode)) {
              log('Attempting to reconnect SSE...');
              await listenAndRetry(
                url: url,
                onError: onError,
                onSuccess: onSuccess,
                headers: headers,
              );
            }
          },
        );
      }
    } catch (error) {
      log('SSE connection error: $error');
      onError(error, StackTrace.current);
    }
  }

  bool shouldReconnect(int statusCode) {
    return statusCode >= 200 && statusCode < 300;
  }

  @override
  Future<void> consumeGetRequest(
    String url,
    OnSuccess onSuccess,
    OnError onError, {
    Map<String, String>? headers,
  }) async {
    try {
      // Caller headers first, so the SDK-managed ones below always win. Names
      // the SDK manages are rejected at configuration time anyway; this keeps
      // the guarantee even for a client constructed some other way.
      final requestHeaders = <String, String>{...?headers};

      if (_featuresRegex.hasMatch(url)) {
        final etag = _etagCache.get(url);
        if (etag != null) {
          requestHeaders["If-None-Match"] = etag;
        }
        requestHeaders["Cache-Control"] = "max-age=3600";
      }

      final response = await _dio.get(
        url,
        options: Options(
          headers: requestHeaders,
          validateStatus: (status) =>
              status != null &&
              ((status >= 200 && status < 300) || status == 304),
        ),
      );

      final newEtag = response.headers.value("etag");
      if (newEtag != null && _featuresRegex.hasMatch(url)) {
        _etagCache.put(url, newEtag);
      }

      if (response.statusCode == 304) {
        log('304 Not Modified — using cached data');
        return;
      }

      if (response.data is Map<String, dynamic>) {
        await onSuccess(response.data);
      } else if (response.data is String) {
        try {
          await onSuccess(jsonDecode(response.data));
        } catch (e) {
          onError(e, StackTrace.current);
        }
      } else {
        onError(Exception('Unexpected response format'), StackTrace.current);
      }
    } on DioException catch (e, s) {
      log('DioException: $e');
      onError(e, s);
    } catch (e, s) {
      log('Unexpected error: $e');
      onError(e, s);
    }
  }

  @override
  Future<void> consumeSseConnections(
    String url,
    OnSuccess onSuccess,
    OnError onError, {
    Map<String, String>? headers,
  }) async {
    await listenAndRetry(
      url: url,
      onError: onError,
      onSuccess: onSuccess,
      headers: headers,
    );
  }

  @override
  Future<void> consumePostRequest(
    String baseUrl,
    Map<String, dynamic> params,
    OnSuccess onSuccess,
    OnError onError, {
    Map<String, String>? headers,
  }) async {
    try {
      Response response = await _dio.post(
        baseUrl,
        data: params,
        options: Options(
          headers: {
            // Caller headers first: the content negotiation below describes the
            // body this method sends and must not be replaced.
            ...?headers,
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      await onSuccess(response.data);
    } catch (e, s) {
      onError(e, s);
    }
  }
}
