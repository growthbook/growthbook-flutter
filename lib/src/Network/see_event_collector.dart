import 'dart:async';
import 'dart:convert';

/// A [StreamTransformer] that collects [String]s into [List]s of [String]s.
/// Each SSE event is separated by double newline, and this stream just
class SseEventCollector extends StreamTransformerBase<String, List<String>> {
  List<String> _prevLines = [];

  @override
  Stream<List<String>> bind(Stream<String> stream) async* {
    await for (var line in stream.transform(const LineSplitter())) {
      if (line.isEmpty) {
        yield _prevLines;
        _prevLines = [];
      } else {
        _prevLines.add(line);
      }
    }
  }
}