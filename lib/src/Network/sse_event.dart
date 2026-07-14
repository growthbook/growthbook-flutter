import 'package:flutter/foundation.dart';

/// Data class for SSE events
@immutable
class SseEvent {
  final String? id;
  final String? name;
  final String? data;

  const SseEvent({this.id, this.name, this.data});

  @override
  String toString() => 'id: $id name: $name data: $data';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SseEvent &&
          id == other.id &&
          name == other.name &&
          data == other.data;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ data.hashCode;
}
