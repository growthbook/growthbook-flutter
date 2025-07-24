import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:growthbook_sdk_flutter/src/Network/sse_event_transformer.dart';

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

  Future<void> listenAndRetry({
    required String url,
    required OnSuccess onSuccess,
    required OnError onError,
  }) async {
    try {
      log('Establishing SSE connection to: $url');
      final resp = await _dio.get(
        url,
        options: Options(responseType: ResponseType.stream),
      );

      final data = resp.data;
      final statusCode = resp.statusCode;

      if (data is ResponseBody) {
        data.stream.cast<List<int>>().transform(const Utf8Decoder()).transform(const SseEventTransformer()).listen(
          (sseModel) {
            log('SSE event received: ${sseModel.name}');
            if (sseModel.name == "features") {
              String jsonData = sseModel.data ?? "";
              Map<String, dynamic> jsonMap = jsonDecode(jsonData);
              onSuccess(jsonMap);
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
    OnError onError,
  ) async {
    try {
      final response = await _dio.get(url);

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
