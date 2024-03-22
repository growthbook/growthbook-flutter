import 'dart:async';

import 'package:growthbook_sdk_flutter/src/Network/see_event_collector.dart';
import 'package:growthbook_sdk_flutter/src/Network/sse_event.dart';
import 'package:growthbook_sdk_flutter/src/Network/sse_event_parser.dart';

/// A [StreamTransformer] that accepts decoded response body as [String]
/// and decodes them to [SseEvent]s.
class SseEventTransformer extends StreamTransformerBase<String, SseEvent> {
  const SseEventTransformer();
  @override
  Stream<SseEvent> bind(Stream<String> stream) =>
      stream.transform(SseEventCollector()).transform(const SseEventParser());
}