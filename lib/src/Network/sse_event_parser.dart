import 'dart:async';

import 'package:growthbook_sdk_flutter/src/Network/sse_event.dart';

/// Actual parser of SSE events,
/// where each SSE event is multiline [String] splitted by newlines
class SseEventParser extends StreamTransformerBase<List<String>, SseEvent> {
  const SseEventParser();
  @override
  Stream<SseEvent> bind(Stream<List<String>> events) async* {
    await for (var dataLines in events) {
      final eventData = <String, String>{};
      for (var line in dataLines) {
        final colonIndex = line.indexOf(':');
        if (colonIndex < 0) {
          eventData[line] = '';
          continue;
        }
        final name = line.substring(0, colonIndex).trim().toLowerCase();
        final data = line.substring(colonIndex + 1).trim();
        eventData[name] = data;
      }
      yield SseEvent(
          id: eventData['id'],
          name: eventData['event'],
          data: eventData['data']);
    }
  }
}