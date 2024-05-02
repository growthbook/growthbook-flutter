import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:growthbook_sdk_flutter/src/Network/sse_event_transformer.dart';

typedef OnSuccess = void Function(Map<String, dynamic> onSuccess);
typedef OnError = void Function(Object error, StackTrace stackTrace);

abstract class BaseClient {
  const BaseClient();

  Future<void> consumeGetRequest(
    String baseUrl,
    String path,
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
    String baseUrl,
    String path,
    OnSuccess onSuccess,
    OnError onError,
  );
}

class DioClient extends BaseClient {
  DioClient() : _dio = Dio();

  final Dio _dio;

  Dio get client => _dio;

  @override
  Future<void> consumeGetRequest(
    String baseUrl,
    String path,
    OnSuccess onSuccess,
    OnError onError,
  ) async {
    final dio = _dio..options.baseUrl = baseUrl;

    try {
      final response = await dio.get(path);
      onSuccess(response.data);
    } catch (e, s) {
      onError(e, s);
    }
  }

  @override
  Future<void> consumeSseConnections(
    String baseUrl,
    String path,
    OnSuccess onSuccess,
    OnError onError,
  ) async {
    final dio = _dio..options.baseUrl = baseUrl;

    Future<void> listenAndRetry() async {
      final Response<ResponseBody> resp = await dio.get(
        path,
        options: Options(responseType: ResponseType.stream),
      );

      // Listen to SSE stream
      resp.data?.stream
          .cast<List<int>>()
          .transform(const Utf8Decoder())
          .transform(const SseEventTransformer())
          .listen(
        (sseModel) {
          if (sseModel.name == "features") {
            String jsonData = sseModel.data ?? "";
            Map<String, dynamic> jsonMap = jsonDecode(jsonData);
            onSuccess(jsonMap);
          }
        },
        onError: (dynamic e, dynamic s) async {
          onError;
          await Future.delayed(const Duration(seconds: 5));
          await listenAndRetry();
        },
        onDone: () async {
          await Future.delayed(const Duration(seconds: 5));
          await listenAndRetry();
        },
      );
    }

    await listenAndRetry();
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
