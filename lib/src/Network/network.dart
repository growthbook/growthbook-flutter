import 'dart:convert';
import 'dart:developer';

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
      log("hmm looks ${data.data}");
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
    try {
      final dio = Dio()..options.baseUrl = baseUrl;
      final Response<ResponseBody> resp = await dio.get(
        path,
        options: Options(responseType: ResponseType.stream),
      );
      resp.data?.stream
          .cast<List<int>>()
          .transform(const Utf8Decoder())
          .transform(const SseEventTransformer())
          .listen((sseModel) {
        if (sseModel.name == "features") {
          String jsonData = sseModel.data ?? "";
          Map<String, dynamic> jsonMap = jsonDecode(jsonData);

          onSuccess(jsonMap);
        } else {}
      });
    } catch (e, s) {
      onError(e, s);
    }
  }
}
