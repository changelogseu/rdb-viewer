import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rdb_viewer/rdb/byte_reader.dart';
import 'package:rdb_viewer/rdb/crc64.dart';
import 'package:rdb_viewer/rdb/intset.dart';
import 'package:rdb_viewer/rdb/length_and_string.dart';
import 'package:rdb_viewer/rdb/listpack.dart';
import 'package:rdb_viewer/rdb/lzf.dart';
import 'package:rdb_viewer/rdb/ziplist.dart';

void main() {
  group('crc64', () {
    test('matches Redis crc64.c self-test vector for "123456789"', () {
      // From redis/src/crc64.c's own REDIS_TEST block:
      //   _crc64(0, "123456789", 9) == 0xe9c6d914c4b8d9ca
      final crc = Crc64Jones.update(0, Uint8List.fromList(ascii.encode('123456789')));
      expect(Crc64Jones.toHex64(crc), 'e9c6d914c4b8d9ca');
    });
  });

  group('length encoding', () {
    test('6-bit length', () {
      final r = RdbByteReader(Uint8List.fromList([0x0A])); // 00001010 -> 10
      expect(readLength(r), 10);
    });

    test('14-bit length', () {
      // type bits 01, remaining 6 bits + next byte = 0x144 = 324
      final first = 0x40 | (0x144 >> 8);
      final second = 0x144 & 0xFF;
      final r = RdbByteReader(Uint8List.fromList([first, second]));
      expect(readLength(r), 0x144);
    });

    test('32-bit length', () {
      final r = RdbByteReader(Uint8List.fromList([0x80, 0x00, 0x01, 0x00, 0x00]));
      expect(readLength(r), 0x00010000);
    });
  });

  group('string encoding', () {
    test('raw string', () {
      final bytes = Uint8List.fromList([0x05, ...'hello'.codeUnits]);
      final r = RdbByteReader(bytes);
      final s = readString(r);
      expect(s.displayText, 'hello');
    });

    test('int8 encoded string', () {
      // 0xC0 = special encoding, subtype 0 (int8); value -42
      final r = RdbByteReader(Uint8List.fromList([0xC0, 0xD6])); // 0xD6 = -42 as int8
      final s = readString(r);
      expect(s.displayText, '-42');
    });

    test('int16 encoded string', () {
      // subtype 1 (int16), value 1000 = 0x03E8, LE bytes: E8 03
      final r = RdbByteReader(Uint8List.fromList([0xC1, 0xE8, 0x03]));
      final s = readString(r);
      expect(s.displayText, '1000');
    });

    test('int32 encoded string', () {
      // subtype 2 (int32), value -70000, LE bytes
      final bd = ByteData(4)..setInt32(0, -70000, Endian.little);
      final r = RdbByteReader(
          Uint8List.fromList([0xC2, ...bd.buffer.asUint8List()]));
      final s = readString(r);
      expect(s.displayText, '-70000');
    });

    test('lzf compressed string', () {
      // "aaaaaaaaaaaaaaaa" (16 x 'a') encoded by hand as LZF:
      // literal run of 2 'a's, then a back-reference of len 14 to dist 1
      // (the LZF/liblzf format: ctrl byte, [extension byte if len field==7],
      // then 1 low-distance byte).
      final plain = 'a' * 16;
      final literal = [0x01, 0x61, 0x61]; // literal run len=1+1=2
      // len_field=7 (signals extension) -> len = 7 + extension + 2 = 14
      // requires extension=5; dist=1 -> dist-1=0 split into hi/lo of 0/0.
      final backref = [0xE0, 0x05, 0x00];
      final compressed = Uint8List.fromList([...literal, ...backref]);
      final decompressed = lzfDecompress(compressed, 16);
      expect(String.fromCharCodes(decompressed), plain);
    });
  });

  group('intset', () {
    test('16-bit intset', () {
      final r = RdbByteReader(Uint8List.fromList([
        2, 0, 0, 0, // encoding = 2 (LE)
        3, 0, 0, 0, // length = 3 (LE)
        0xFB, 0xFF, // -5 as int16 LE
        0x00, 0x00, // 0
        0xE8, 0x03, // 1000
      ]));
      expect(decodeIntset(r), [-5, 0, 1000]);
    });
  });

  group('listpack', () {
    test('7-bit uint, 6-bit str, 13-bit int, 32-bit-len str, 16-bit int', () {
      final payload = <int>[];
      // 7-bit uint: 5
      payload.add(0x05);
      payload.add(1); // backlen for 1-byte entry

      // 6-bit str "ab"
      payload.addAll([0x80 | 2, 0x61, 0x62]);
      payload.add(3); // entry len = 3 -> backlen 1 byte

      // 13-bit int: -100 -> raw 13-bit two's complement = 8192-100=8092=0x1F9C
      final raw = 8192 - 100;
      final b0 = 0xC0 | (raw >> 8);
      final b1 = raw & 0xFF;
      payload.addAll([b0, b1]);
      payload.add(2); // entry len = 2

      // 16-bit int marker 0xF1, value -1234 LE
      final bd = ByteData(2)..setInt16(0, -1234, Endian.little);
      payload.addAll([0xF1, ...bd.buffer.asUint8List()]);
      payload.add(3); // entry len = 3

      final header = ByteData(6);
      final totalLen = 6 + payload.length + 1; // + terminator
      header.setUint32(0, totalLen, Endian.little);
      header.setUint16(4, 4, Endian.little);
      final blob = Uint8List.fromList([
        ...header.buffer.asUint8List(),
        ...payload,
        0xFF,
      ]);

      final elements = decodeListpack(blob);
      expect(elements.length, 4);
      expect(elements[0].intValue, 5);
      expect(elements[1].stringValue, [0x61, 0x62]);
      expect(elements[2].intValue, -100);
      expect(elements[3].intValue, -1234);
    });
  });

  group('ziplist', () {
    test('two small strings', () {
      // Entries: "hi" (2 bytes, 6-bit str) and "42" (int-ish string "42", but
      // stored as a 6-bit string entry, not integer-encoded, to keep this a
      // pure string round-trip test).
      final entry1 = <int>[0x00, ...[0x00 | 2, 0x68, 0x69]]; // prevlen=0, str "hi"
      // second entry prevlen = total length of entry1 = 1(prevlen)+1(enc)+2(data)=4
      final entry2 = <int>[4, ...[0x00 | 2, 0x34, 0x32]]; // prevlen=4, str "42"
      final entries = [...entry1, ...entry2];
      final header = ByteData(10);
      header.setUint32(0, 10 + entries.length + 1, Endian.little); // zlbytes
      header.setUint32(4, 1 + entries.length - entry2.length, Endian.little); // zltail (approx, unused by decoder)
      header.setUint16(8, 2, Endian.little); // zllen
      final blob = Uint8List.fromList([
        ...header.buffer.asUint8List(),
        ...entries,
        0xFF,
      ]);
      final elements = decodeZiplist(blob);
      expect(elements.length, 2);
      expect(String.fromCharCodes(elements[0].stringValue!), 'hi');
      expect(String.fromCharCodes(elements[1].stringValue!), '42');
    });

    test('integer entries', () {
      // 4-bit immediate int representing 7: encByte = 0xF1 + (7 - 0) = since
      // value = (encByte & 0x0F) - 1 => encByte = value + 1 + 0xF0 = 0xF8
      final entry1 = <int>[0x00, 0xF8];
      final entry2 = <int>[2, 0xFE, 200]; // prevlen=2, 8-bit int 200 (as signed byte 0xC8=-56)
      final blob = Uint8List.fromList([
        ...List.filled(10, 0), // header placeholder, filled below
        ...entry1,
        ...entry2,
        0xFF,
      ]);
      final header = ByteData.sublistView(blob, 0, 10);
      header.setUint32(0, blob.length, Endian.little);
      header.setUint32(4, 0, Endian.little);
      header.setUint16(8, 2, Endian.little);

      final elements = decodeZiplist(blob);
      expect(elements.length, 2);
      expect(elements[0].intValue, 7);
      expect(elements[1].intValue, -56);
    });
  });
}
