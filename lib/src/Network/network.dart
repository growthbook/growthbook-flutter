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

  @override
  Future<void> consumeGetRequest(
    String baseUrl,
    String path,
    OnSuccess onSuccess,
    OnError onError,
  ) async {
    final dio = _dio..options.baseUrl = baseUrl;

    try {
      final data = await dio.get(path);
      onSuccess(data.data);
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

    // Define a function to listen to SSE and handle retries
    Future<void> listenAndRetry() async {
      final Response<ResponseBody> resp = await dio.get(
        path,
        options: Options(responseType: ResponseType.stream),
      );

      // Listen to SSE stream
      await resp.data?.stream
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
            cancelOnError: true, // Cancel the subscription on error
            onError: (dynamic e, dynamic s) async {
              onError;
              // Retry listening after a delay
              await Future.delayed(
                  const Duration(seconds: 5)); // Adjust the delay as needed
              await listenAndRetry(); // Recursive call for retry
            },
            onDone: () async {
              print("SSE stream closed. Retrying...");
              await Future.delayed(
                  const Duration(seconds: 5)); // Adjust the delay as needed
              await listenAndRetry(); // Recursive call for retry
            },
          );
    }

    // Call the function to start listening with retries
    await listenAndRetry();
  }
}
