import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:growthbook_sdk_flutter/src/Network/sse_model.dart';

import 'package:dio/dio.dart';

enum SSERequestType { GET, POST }

class SSEManager {
  static final Dio _dio = Dio();
  static CancelToken? _cancelToken;

  static Stream<SSEModel> subscribeToSSE({
    required SSERequestType method,
    required String url,
    required Map<String, String> header,
    Map<String, dynamic>? body,
  }) {
    var lineRegex = RegExp(r'^([^:]*)(?::)?(?: )?(.*)?$');
    var currentSSEModel = SSEModel(data: '', id: '', event: '');
    StreamController<SSEModel> streamController = StreamController();
    log("--SUBSCRIBING TO SSE---");

    _dio.interceptors
        .add(LogInterceptor(responseBody: true, requestBody: true));

    try {
      _dio.options.headers = header;

      if (method == SSERequestType.GET) {
        _dio.options.method = 'GET';
      } else {
        _dio.options.method = 'POST';
        _dio.options.headers['Content-Type'] = 'application/json';
      }

      _cancelToken = CancelToken();

      _dio
          .request(
            url,
            cancelToken: _cancelToken,
            data: body != null ? jsonEncode(body) : null,
            onReceiveProgress: (int received, int total) {
              // You can add progress handling here
            },
          )
          .asStream()
          .listen(
            (response) {
              // Assuming response.data is a String
              var dataLine = response.data as String;

              if (dataLine.isEmpty) {
                streamController.add(currentSSEModel);
                currentSSEModel = SSEModel(data: '', id: '', event: '');
                return;
              }

              Match match = lineRegex.firstMatch(dataLine)!;
              var field = match.group(1);
              if (field!.isEmpty) {
                return;
              }
              var value = '';
              if (field == 'data') {
                value = dataLine.substring(5);
              } else {
                value = match.group(2) ?? '';
              }
              switch (field) {
                case 'event':
                  currentSSEModel.event = value;
                  break;
                case 'data':
                  currentSSEModel.data =
                      (currentSSEModel.data ?? '') + value + '\n';
                  break;
                case 'id':
                  currentSSEModel.id = value;
                  break;
                case 'retry':
                  break;
              }
            },
            onError: (e, s) {
              print('---ERROR---');
              print(e);
              streamController.addError(e, s);
            },
          );
    } catch (e, s) {
      print('---ERROR---');
      print(e);
      streamController.addError(e, s);
    }

    return streamController.stream;
  }

  static void unsubscribeFromSSE() {
    _cancelToken?.cancel();
  }
}
