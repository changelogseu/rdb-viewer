import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rdb_viewer/rdb/length_and_string.dart';
import 'package:rdb_viewer/rdb/rdb_model.dart';
import 'package:rdb_viewer/rdb/rdb_parser.dart';
import 'package:rdb_viewer/rdb/rdb_writer.dart';

RdbDocument _buildDoc() {
  final doc = RdbDocument(rdbVersion: 11, sourcePath: 'in-memory.rdb', fileSizeBytes: 0);
  doc.auxFields['redis-ver'] = '7.4.0';

  final db0 = RdbDatabase(0);
  db0.entries.add(RdbEntry(
    key: RdbString.fromText('greeting'),
    value: RdbValue.string(RdbString.fromText('hällo wörld 👋')),
  ));
  db0.entries.add(RdbEntry(
    key: RdbString.fromText('binary:blob'),
    value: RdbValue.string(RdbString(Uint8List.fromList([0x78, 0x00, 0xFF, 0x80, 0x10]))),
  ));
  db0.entries.add(RdbEntry(
    key: RdbString.fromText('todo'),
    value: RdbValue.list([RdbString.fromText('a'), RdbString.fromText('b')]),
    expireAtMs: 4102444800000, // 2100-01-01, far future
  ));
  db0.entries.add(RdbEntry(
    key: RdbString.fromText('tags'),
    value: RdbValue.set([RdbString.fromText('x'), RdbString.fromText('y')]),
  ));
  db0.entries.add(RdbEntry(
    key: RdbString.fromText('profile'),
    value: RdbValue.hash([HashField(RdbString.fromText('name'), RdbString.fromText('Jane'))]),
  ));
  db0.entries.add(RdbEntry(
    key: RdbString.fromText('scores'),
    value: RdbValue.zset([
      ZsetMember(RdbString.fromText('alice'), 1.5),
      ZsetMember(RdbString.fromText('bob'), -2.0),
    ]),
  ));
  doc.databases.add(db0);

  // An empty DB, which the writer should omit entirely.
  doc.databases.add(RdbDatabase(1));

  return doc;
}

void main() {
  group('writeRdbFile round-trip', () {
    test('re-parses to an equivalent, checksum-valid document', () {
      final original = _buildDoc();
      final bytes = writeRdbFile(original);

      final reparsed = parseRdbFile(bytes, sourcePath: 'roundtrip.rdb');

      expect(reparsed.checksumStatus, ChecksumStatus.valid);
      expect(reparsed.unparsedKeys, isEmpty);
      expect(reparsed.fatalStopReason, isNull);

      // The empty DB 1 must not appear at all.
      expect(reparsed.databases.length, 1);
      expect(reparsed.databases.single.index, 0);

      final byKey = {
        for (final e in reparsed.databases.single.entries) e.key.displayText: e,
      };
      expect(byKey.keys.toSet(), {'greeting', 'binary:blob', 'todo', 'tags', 'profile', 'scores'});

      expect(byKey['greeting']!.value.stringValue!.displayText, 'hällo wörld 👋');
      expect(byKey['binary:blob']!.value.stringValue!.isValidUtf8, isFalse);

      expect(byKey['todo']!.value.listValue!.map((s) => s.displayText).toList(), ['a', 'b']);
      expect(byKey['todo']!.hasExpiry, isTrue);
      expect(byKey['todo']!.expireAtMs, 4102444800000);

      expect(byKey['tags']!.value.setValue!.map((s) => s.displayText).toSet(), {'x', 'y'});

      expect(byKey['profile']!.value.hashValue!.single.field.displayText, 'name');
      expect(byKey['profile']!.value.hashValue!.single.value.displayText, 'Jane');

      final scores = {
        for (final m in byKey['scores']!.value.zsetValue!) m.member.displayText: m.score,
      };
      expect(scores, {'alice': 1.5, 'bob': -2.0});
    });
  });

  group('writeRdbFile safety guard', () {
    test('refuses to write a document that was not fully parsed', () {
      final doc = _buildDoc();
      doc.unparsedKeys.add(UnparsedKeyInfo(
        dbIndex: 0,
        key: RdbString.fromText('stream:x'),
        typeByte: 21,
        typeName: 'stream (listpacks v3)',
        fileOffset: 123,
      ));

      expect(doc.isFullyParsed, isFalse);
      expect(() => writeRdbFile(doc), throwsA(isA<RdbWriteRefusedException>()));
    });

    test('refuses to write after a fatal stop (e.g. MODULE_AUX)', () {
      final doc = _buildDoc();
      doc.fatalStopReason = 'Modul-Daten gefunden';

      expect(doc.isFullyParsed, isFalse);
      expect(() => writeRdbFile(doc), throwsA(isA<RdbWriteRefusedException>()));
    });
  });
}
