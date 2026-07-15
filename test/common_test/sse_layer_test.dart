import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/src/Network/see_event_collector.dart';
import 'package:growthbook_sdk_flutter/src/Network/sse_event.dart';
import 'package:growthbook_sdk_flutter/src/Network/sse_event_parser.dart';
import 'package:growthbook_sdk_flutter/src/Network/sse_event_transformer.dart';

void main() {
  // -------------------------------------------------------------------------
  // SseEvent — data class
  // -------------------------------------------------------------------------
  group('SseEvent', () {
    test('toString includes id, name, and data', () {
      const event = SseEvent(id: '1', name: 'features', data: '{}');
      final str = event.toString();
      expect(str, contains('1'));
      expect(str, contains('features'));
      expect(str, contains('{}'));
    });

    test('two events with same fields are equal', () {
      const a = SseEvent(id: '1', name: 'ping', data: 'x');
      const b = SseEvent(id: '1', name: 'ping', data: 'x');
      expect(a, equals(b));
    });

    test('events differ when any field differs', () {
      const base = SseEvent(id: '1', name: 'ping', data: 'x');
      expect(base == const SseEvent(id: '2', name: 'ping', data: 'x'), isFalse);
      expect(base == const SseEvent(id: '1', name: 'push', data: 'x'), isFalse);
      expect(base == const SseEvent(id: '1', name: 'ping', data: 'y'), isFalse);
    });

    test('identical reference is equal to itself', () {
      const event = SseEvent(id: '1', name: 'ping', data: 'x');
      // ignore: unrelated_type_equality_checks
      expect(event == event, isTrue);
    });

    test('equal events have the same hashCode', () {
      const a = SseEvent(id: '42', name: 'ev', data: 'payload');
      const b = SseEvent(id: '42', name: 'ev', data: 'payload');
      expect(a.hashCode, b.hashCode);
    });

    test('works with all-null fields', () {
      const event = SseEvent();
      expect(event.id, isNull);
      expect(event.name, isNull);
      expect(event.data, isNull);
      expect(() => event.toString(), returnsNormally);
    });
  });

  // -------------------------------------------------------------------------
  // SseEventCollector — groups lines by double-newline separator
  // -------------------------------------------------------------------------
  group('SseEventCollector', () {
    test('yields one group of lines for a single SSE event', () async {
      final input = Stream.fromIterable(['id: 1\nevent: ping\ndata: {}\n\n']);
      final result = await input.transform(SseEventCollector()).toList();
      expect(result, [
        ['id: 1', 'event: ping', 'data: {}']
      ]);
    });

    test('yields multiple groups for multiple SSE events', () async {
      final input = Stream.fromIterable([
        'event: a\ndata: 1\n\nevent: b\ndata: 2\n\n',
      ]);
      final result = await input.transform(SseEventCollector()).toList();
      expect(result.length, 2);
      expect(result[0], ['event: a', 'data: 1']);
      expect(result[1], ['event: b', 'data: 2']);
    });

    test('handles chunks arriving as separate stream items', () async {
      final input = Stream.fromIterable([
        'event: test\n',
        'data: hello\n',
        '\n',
      ]);
      final result = await input.transform(SseEventCollector()).toList();
      expect(result, [
        ['event: test', 'data: hello']
      ]);
    });
  });

  // -------------------------------------------------------------------------
  // SseEventParser — maps List<String> lines to SseEvent
  // -------------------------------------------------------------------------
  group('SseEventParser', () {
    test('parses standard id / event / data fields', () async {
      final input = Stream.fromIterable([
        ['id: 42', 'event: features', 'data: {"key":"val"}'],
      ]);
      final result = await input.transform(const SseEventParser()).toList();
      expect(result.single,
          const SseEvent(id: '42', name: 'features', data: '{"key":"val"}'));
    });

    test('line without colon is stored with empty value', () async {
      final input = Stream.fromIterable([
        ['ping'],
      ]);
      final result = await input.transform(const SseEventParser()).toList();
      // No id/event/data fields → all null
      expect(result.single, const SseEvent());
    });

    test('field names are lowercased', () async {
      final input = Stream.fromIterable([
        ['ID: 1', 'EVENT: push', 'DATA: {}'],
      ]);
      final result = await input.transform(const SseEventParser()).toList();
      expect(result.single, const SseEvent(id: '1', name: 'push', data: '{}'));
    });

    test('leading and trailing whitespace is trimmed from values', () async {
      final input = Stream.fromIterable([
        ['data:   trimmed   '],
      ]);
      final result = await input.transform(const SseEventParser()).toList();
      expect(result.single.data, 'trimmed');
    });

    test('yields one SseEvent per input list', () async {
      final input = Stream.fromIterable([
        ['data: first'],
        ['data: second'],
      ]);
      final result = await input.transform(const SseEventParser()).toList();
      expect(result.length, 2);
    });
  });

  // -------------------------------------------------------------------------
  // SseEventTransformer — end-to-end raw SSE string → SseEvent
  // -------------------------------------------------------------------------
  group('SseEventTransformer', () {
    test('parses a complete SSE event from raw stream', () async {
      final input = Stream.fromIterable([
        'id: 1\nevent: features\ndata: {"status":200}\n\n',
      ]);
      final result =
          await input.transform(const SseEventTransformer()).toList();
      expect(
          result.single,
          const SseEvent(
            id: '1',
            name: 'features',
            data: '{"status":200}',
          ));
    });

    test('parses multiple events from a single stream', () async {
      final input = Stream.fromIterable([
        'event: ping\ndata: 1\n\nevent: ping\ndata: 2\n\n',
      ]);
      final result =
          await input.transform(const SseEventTransformer()).toList();
      expect(result.length, 2);
      expect(result[0].name, 'ping');
      expect(result[1].data, '2');
    });

    test('handles empty data field', () async {
      final input = Stream.fromIterable(['event: heartbeat\ndata:\n\n']);
      final result =
          await input.transform(const SseEventTransformer()).toList();
      expect(result.single.name, 'heartbeat');
      expect(result.single.data, '');
    });
  });
}
