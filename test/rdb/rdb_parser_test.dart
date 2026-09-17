import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rdb_viewer/rdb/crc64.dart';
import 'package:rdb_viewer/rdb/rdb_model.dart';
import 'package:rdb_viewer/rdb/rdb_parser.dart';

/// Minimal encoder helpers mirroring the RDB length/string format, used
/// only to build synthetic fixture files for these tests.
void _writeLength(BytesBuilder b, int value) {
  if (value < 64) {
    b.addByte(value);
  } else if (value < 16384) {
    b.addByte(0x40 | (value >> 8));
    b.addByte(value & 0xFF);
  } else {
    b.addByte(0x80);
    b.addByte((value >> 24) & 0xFF);
    b.addByte((value >> 16) & 0xFF);
    b.addByte((value >> 8) & 0xFF);
    b.addByte(value & 0xFF);
  }
}

void _writeRawString(BytesBuilder b, String s) {
  final bytes = utf8.encode(s);
  _writeLength(b, bytes.length);
  b.add(bytes);
}

void _writeDoubleLE(BytesBuilder b, double v) {
  final bd = ByteData(8)..setFloat64(0, v, Endian.little);
  b.add(bd.buffer.asUint8List());
}

Uint8List _buildFixture({required bool withChecksum}) {
  final b = BytesBuilder();
  b.add(ascii.encode(withChecksum ? 'REDIS0011' : 'REDIS0001'));

  // AUX field.
  b.addByte(0xFA);
  _writeRawString(b, 'redis-ver');
  _writeRawString(b, '7.4.0');

  // DB 0.
  b.addByte(0xFE);
  _writeLength(b, 0);
  b.addByte(0xFB); // RESIZEDB
  _writeLength(b, 2);
  _writeLength(b, 1);

  // key "foo" -> string "bar", no expiry.
  b.addByte(0); // RDB_TYPE_STRING
  _writeRawString(b, 'foo');
  _writeRawString(b, 'bar');

  // key "h1" -> hash {a: '1', b: '2'}, with a millisecond expiry.
  b.addByte(0xFC); // EXPIRETIME_MS
  final expireAt = DateTime.utc(2030, 1, 1).millisecondsSinceEpoch;
  final bd = ByteData(8)..setUint64(0, expireAt, Endian.little);
  b.add(bd.buffer.asUint8List());
  b.addByte(4); // RDB_TYPE_HASH
  _writeRawString(b, 'h1');
  _writeLength(b, 2);
  _writeRawString(b, 'a');
  _writeRawString(b, '1');
  _writeRawString(b, 'b');
  _writeRawString(b, '2');

  // DB 1.
  b.addByte(0xFE);
  _writeLength(b, 1);

  // key "s1" -> set {x, y}.
  b.addByte(2); // RDB_TYPE_SET
  _writeRawString(b, 's1');
  _writeLength(b, 2);
  _writeRawString(b, 'x');
  _writeRawString(b, 'y');

  // key "z1" -> zset2 {m1: 1.5, m2: -2.0}.
  b.addByte(5); // RDB_TYPE_ZSET_2
  _writeRawString(b, 'z1');
  _writeLength(b, 2);
  _writeRawString(b, 'm1');
  _writeDoubleLE(b, 1.5);
  _writeRawString(b, 'm2');
  _writeDoubleLE(b, -2.0);

  b.addByte(0xFF); // EOF

  final withoutChecksum = b.toBytes();
  if (!withChecksum) {
    return withoutChecksum;
  }
  final crc = Crc64Jones.update(0, withoutChecksum);
  final crcBytes = ByteData(8)..setUint64(0, crc, Endian.little);
  final out = BytesBuilder();
  out.add(withoutChecksum);
  out.add(crcBytes.buffer.asUint8List());
  return out.toBytes();
}

void main() {
  test('parses a multi-db fixture with strings/hash/set/zset and TTL', () {
    final bytes = _buildFixture(withChecksum: true);
    final doc = parseRdbFile(bytes, sourcePath: 'fixture.rdb');

    expect(doc.rdbVersion, 11);
    expect(doc.auxFields['redis-ver'], '7.4.0');
    expect(doc.checksumStatus, ChecksumStatus.valid);
    expect(doc.unparsedKeys, isEmpty);
    expect(doc.fatalStopReason, isNull);
    expect(doc.databases.length, 2);

    final db0 = doc.databases[0];
    expect(db0.index, 0);
    expect(db0.entries.length, 2);

    final foo = db0.entries.firstWhere((e) => e.key.displayText == 'foo');
    expect(foo.value.kind, RdbValueKind.string);
    expect(foo.value.stringValue!.displayText, 'bar');
    expect(foo.hasExpiry, isFalse);

    final h1 = db0.entries.firstWhere((e) => e.key.displayText == 'h1');
    expect(h1.value.kind, RdbValueKind.hash);
    expect(h1.value.hashValue!.length, 2);
    expect(h1.value.hashValue![0].field.displayText, 'a');
    expect(h1.value.hashValue![0].value.displayText, '1');
    expect(h1.hasExpiry, isTrue);
    expect(h1.expireAtMs, DateTime.utc(2030, 1, 1).millisecondsSinceEpoch);

    final db1 = doc.databases[1];
    expect(db1.index, 1);
    final s1 = db1.entries.firstWhere((e) => e.key.displayText == 's1');
    expect(s1.value.kind, RdbValueKind.set);
    expect(s1.value.setValue!.map((e) => e.displayText).toSet(), {'x', 'y'});

    final z1 = db1.entries.firstWhere((e) => e.key.displayText == 'z1');
    expect(z1.value.kind, RdbValueKind.zset);
    final scores = {for (final m in z1.value.zsetValue!) m.member.displayText: m.score};
    expect(scores['m1'], 1.5);
    expect(scores['m2'], -2.0);
  });

  test('checksum disabled (RDB version < 5) is reported, not flagged as mismatch', () {
    final bytes = _buildFixture(withChecksum: false);
    final doc = parseRdbFile(bytes, sourcePath: 'fixture.rdb');
    expect(doc.rdbVersion, 1);
    expect(doc.checksumStatus, ChecksumStatus.disabled);
  });

  test('rejects a file without a REDIS header', () {
    final bytes = Uint8List.fromList(ascii.encode('NOTREDIS1'));
    expect(() => parseRdbFile(bytes, sourcePath: 'bad.rdb'), throwsA(anything));
  });
}
