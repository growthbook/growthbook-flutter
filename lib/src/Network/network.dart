import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:growthbook_sdk_flutter/src/Network/lru_etag_cache.dart';
import 'package:growthbook_sdk_flutter/src/Network/sse_event_transformer.dart';

import '../Utils/logger.dart';

typedef OnSuccess = void Function(Map<String, dynamic> onSuccess);
typedef OnError = void Function(Object error, StackTrace stackTrace);

abstract class BaseClient {
  const BaseClient();

  Future<void> consumeGetRequest(
    String url,
    OnSuccess onSuccess,
    OnError onError,
  );

  Future<void> consumePostRequest(
    String baseUrl,
    Map<String, dynamic> params,
    OnSuccess onSuccess,
    OnError onError,
  );

  Future<void> consumeSseConnections(
    String url,
    OnSuccess onSuccess,
    OnError onError,
  );
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
  }) async {
    try {
      logger.i('Establishing SSE connection to: $url');
      final resp = await _dio.get(
        url,
        options: Options(responseType: ResponseType.stream),
      );

      final data = resp.data;
      final statusCode = resp.statusCode;

      if (data is ResponseBody) {
        data.stream
            .cast<List<int>>()
            .transform(const Utf8Decoder())
            .transform(const SseEventTransformer())
            .listen(
          (sseModel) {
            logger.i('SSE event received: ${sseModel.name}');
            if (sseModel.name == "features" && lastKnownId != sseModel.id) {
              lastKnownId = sseModel.id;
              String jsonData = sseModel.data ?? "";
              Map<String, dynamic> jsonMap = jsonDecode(jsonData);
              onSuccess(jsonMap);
            }
          },
          onError: (dynamic e, dynamic s) async {
            onError(e, s);
          },
          onDone: () async {
            logger.i('SSE connection closed with status: $statusCode');
            if (statusCode != null && shouldReconnect(statusCode)) {
              logger.i('Attempting to reconnect SSE...');
              await listenAndRetry(
                url: url,
                onError: onError,
                onSuccess: onSuccess,
              );
            }
          },
        );
      }
    } catch (error) {
      logger.e('SSE connection error: $error');
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
    OnError onError,
  ) async {
    try {
      final headers = <String, String>{};

      if (_featuresRegex.hasMatch(url)) {
        final etag = _etagCache.get(url);
        if (etag != null) {
          headers["If-None-Match"] = etag;
        }
        headers["Cache-Control"] = "max-age=3600";
        headers["Accept-Encoding"] = "gzip, deflate, br";
      }

      final response = await _dio.get(
        url,
        options: Options(headers: headers),
      );

      final newEtag = response.headers.value("etag");
      if (newEtag != null && _featuresRegex.hasMatch(url)) {
        _etagCache.put(url, newEtag);
      }

      if (response.data is Map<String, dynamic>) {
        onSuccess(response.data);
      } else if (response.data is String) {
        try {
          onSuccess(jsonDecode(response.data));
        } catch (e) {
          onError(e, StackTrace.current);
        }
      } else {
        onError(Exception('Unexpected response format'), StackTrace.current);
      }
    } on DioException catch (e, s) {
      if (e.response?.statusCode == 304) {
        logger.e('DioException: $e');
        onError(e, s);
        return;
      }
      logger.e('DioException: $e');
      onError(e, s);
    } catch (e, s) {
      logger.e('Unexpected error: $e');
      onError(e, s);
    }
  }

  @override
  Future<void> consumeSseConnections(
    String url,
    OnSuccess onSuccess,
    OnError onError,
  ) async {
    await listenAndRetry(
      url: url,
      onError: onError,
      onSuccess: onSuccess,
    );
  }

  @override
  Future<void> consumePostRequest(
    String baseUrl,
    Map<String, dynamic> params,
    OnSuccess onSuccess,
    OnError onError,
  ) async {
    try {
      Response response = await _dio.post(
        baseUrl,
        data: params,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      onSuccess(response.data);
    } catch (e, s) {
      onError(e, s);
    }
  }
}
