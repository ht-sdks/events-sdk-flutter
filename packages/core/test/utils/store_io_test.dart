import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hightouch_events/utils/store/io.dart';

/// A [RandomAccessFile] that records calls and can fail on chosen operations.
class _FakeFile implements RandomAccessFile {
  _FakeFile({this.failOn});

  final String? failOn;
  final calls = <String>[];

  void _record(String name) {
    calls.add(name);
    if (failOn == name) {
      throw const FileSystemException(
        'truncate failed',
        '/fake',
        OSError('No space left on device', 28),
      );
    }
  }

  @override
  void lockSync([FileLock mode = FileLock.exclusive, int start = 0, int end = -1]) => _record('lock');

  @override
  void setPositionSync(int position) => _record('setPosition');

  @override
  void writeFromSync(List<int> buffer, [int start = 0, int? end]) => _record('write');

  @override
  void truncateSync(int length) => _record('truncate');

  @override
  void unlockSync([int start = 0, int end = -1]) => _record('unlock');

  @override
  void closeSync() => _record('close');

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

StoreImpl _storeWith(_FakeFile file) => StoreImpl(fileOpener: (key, {bool create = false}) async => file);

void main() {
  test('successful write locks, writes, truncates, unlocks and closes', () async {
    final file = _FakeFile();
    await _storeWith(file).setPersisted('k', {'a': 1});

    expect(file.calls, ['lock', 'setPosition', 'write', 'truncate', 'unlock', 'close']);
  });

  test('disk-full failure on truncate still unlocks and closes the file', () async {
    final file = _FakeFile(failOn: 'truncate');

    await expectLater(_storeWith(file).setPersisted('k', {'a': 1}), throwsA(isA<FileSystemException>()));

    expect(file.calls, containsAllInOrder(['lock', 'truncate', 'unlock', 'close']));
  });

  test('disk-full failure on write still unlocks and closes the file', () async {
    final file = _FakeFile(failOn: 'write');

    await expectLater(_storeWith(file).setPersisted('k', {'a': 1}), throwsA(isA<FileSystemException>()));

    expect(file.calls, containsAllInOrder(['lock', 'write', 'unlock', 'close']));
    expect(file.calls, isNot(contains('truncate')));
  });

  test('failure to acquire the lock still closes the file and does not unlock', () async {
    final file = _FakeFile(failOn: 'lock');

    await expectLater(_storeWith(file).setPersisted('k', {'a': 1}), throwsA(isA<FileSystemException>()));

    expect(file.calls, ['lock', 'close']);
  });

  test('an error while unlocking/closing does not mask the original write error', () async {
    final file = _FakeFile(failOn: 'unlock');

    // The write itself succeeds here; unlock failing is swallowed so the write
    // is not reported as failed after the data was already written.
    await _storeWith(file).setPersisted('k', {'a': 1});

    expect(file.calls, ['lock', 'setPosition', 'write', 'truncate', 'unlock', 'close']);
  });
}
