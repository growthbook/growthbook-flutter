import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/src/Cache/caching_manager.dart';

/// Regression tests: `saveContent` used `writeAsBytesSync(flush: true)` +
/// `renameSync`, which blocks the main isolate on `fsync` and causes
/// "ANR triggered by slow IO operations" on Android
/// (`dart::bin::Builtin_File_Flush`).
void main() {
  group('CachingManager.saveContent async write', () {
    final manager = CachingManager();

    tearDown(() async {
      await manager.clearCache();
    });

    test('does not call sync file I/O', () async {
      final spy = _SpyIOOverrides();
      final content = Uint8List.fromList(utf8.encode('{"features":{}}'));

      await IOOverrides.runWithIOOverrides(
        () => manager.saveContent(
          fileName: 'async-write-no-sync',
          content: content,
        ),
        spy,
      );

      expect(spy.syncCalls, isEmpty,
          reason: 'saveContent must not block the isolate with sync file I/O');

      final saved = await manager.getContent(fileName: 'async-write-no-sync');
      expect(saved, equals(content));
    });

    test('two back-to-back saves leave the file valid with the last content',
        () async {
      const fileName = 'async-write-back-to-back';
      // Different sizes so that interleaved or truncated writes are visible.
      final first = Uint8List.fromList(
          utf8.encode(json.encode({'v': 1, 'pad': 'x' * 200000})));
      final second = Uint8List.fromList(utf8.encode(json.encode({'v': 2})));

      // Not awaited between them, like two refreshes landing together.
      final firstSave = manager.saveContent(fileName: fileName, content: first);
      final secondSave =
          manager.saveContent(fileName: fileName, content: second);
      await Future.wait([firstSave, secondSave]);

      final saved = await manager.getContent(fileName: fileName);
      expect(saved, isNotNull);
      expect(json.decode(utf8.decode(saved!)), equals({'v': 2}));

      final targetPath = await manager.getTargetFile(fileName);
      expect(File('$targetPath.tmp').existsSync(), isFalse,
          reason: 'temp file must not be left behind');
    });
  });
}

final class _SpyIOOverrides extends IOOverrides {
  final List<String> syncCalls = [];

  // Keep the per-file temp folder set in `test/flutter_test_config.dart`.
  final Directory _systemTemp = Directory.systemTemp;

  @override
  File createFile(String path) => _SpyFile(super.createFile(path), syncCalls);

  @override
  Directory getSystemTempDirectory() => _systemTemp;
}

/// Delegates to a real [File] and records every blocking call that writes,
/// flushes or moves the file.
class _SpyFile implements File {
  _SpyFile(this._file, this._syncCalls);

  final File _file;
  final List<String> _syncCalls;

  void _record(String name) => _syncCalls.add('$name(${_file.path})');

  @override
  String get path => _file.path;

  @override
  File get absolute => _file.absolute;

  @override
  Uri get uri => _file.uri;

  @override
  Directory get parent => _file.parent;

  @override
  bool get isAbsolute => _file.isAbsolute;

  @override
  Future<bool> exists() => _file.exists();

  @override
  bool existsSync() => _file.existsSync();

  @override
  Future<File> create({bool recursive = false, bool exclusive = false}) =>
      _file.create(recursive: recursive, exclusive: exclusive);

  @override
  void createSync({bool recursive = false, bool exclusive = false}) {
    _record('createSync');
    _file.createSync(recursive: recursive, exclusive: exclusive);
  }

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) =>
      _file.delete(recursive: recursive);

  @override
  void deleteSync({bool recursive = false}) {
    _record('deleteSync');
    _file.deleteSync(recursive: recursive);
  }

  @override
  Future<File> rename(String newPath) => _file.rename(newPath);

  @override
  File renameSync(String newPath) {
    _record('renameSync');
    return _file.renameSync(newPath);
  }

  @override
  Future<File> copy(String newPath) => _file.copy(newPath);

  @override
  File copySync(String newPath) {
    _record('copySync');
    return _file.copySync(newPath);
  }

  @override
  Future<int> length() => _file.length();

  @override
  int lengthSync() => _file.lengthSync();

  @override
  Future<FileStat> stat() => _file.stat();

  @override
  FileStat statSync() => _file.statSync();

  @override
  Future<RandomAccessFile> open({FileMode mode = FileMode.read}) =>
      _file.open(mode: mode);

  @override
  RandomAccessFile openSync({FileMode mode = FileMode.read}) {
    _record('openSync');
    return _file.openSync(mode: mode);
  }

  @override
  Stream<List<int>> openRead([int? start, int? end]) =>
      _file.openRead(start, end);

  @override
  IOSink openWrite(
          {FileMode mode = FileMode.write, Encoding encoding = utf8}) =>
      _file.openWrite(mode: mode, encoding: encoding);

  @override
  Future<Uint8List> readAsBytes() => _file.readAsBytes();

  @override
  Uint8List readAsBytesSync() => _file.readAsBytesSync();

  @override
  Future<String> readAsString({Encoding encoding = utf8}) =>
      _file.readAsString(encoding: encoding);

  @override
  String readAsStringSync({Encoding encoding = utf8}) =>
      _file.readAsStringSync(encoding: encoding);

  @override
  Future<File> writeAsBytes(List<int> bytes,
          {FileMode mode = FileMode.write, bool flush = false}) =>
      _file.writeAsBytes(bytes, mode: mode, flush: flush);

  @override
  void writeAsBytesSync(List<int> bytes,
      {FileMode mode = FileMode.write, bool flush = false}) {
    _record(flush ? 'writeAsBytesSync(flush: true)' : 'writeAsBytesSync');
    _file.writeAsBytesSync(bytes, mode: mode, flush: flush);
  }

  @override
  Future<File> writeAsString(String contents,
          {FileMode mode = FileMode.write,
          Encoding encoding = utf8,
          bool flush = false}) =>
      _file.writeAsString(contents,
          mode: mode, encoding: encoding, flush: flush);

  @override
  void writeAsStringSync(String contents,
      {FileMode mode = FileMode.write,
      Encoding encoding = utf8,
      bool flush = false}) {
    _record(flush ? 'writeAsStringSync(flush: true)' : 'writeAsStringSync');
    _file.writeAsStringSync(contents,
        mode: mode, encoding: encoding, flush: flush);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
      '_SpyFile does not forward ${invocation.memberName}; add it to the spy');
}
