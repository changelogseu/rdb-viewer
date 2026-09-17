import 'dart:typed_data';

import 'byte_reader.dart';
import 'listpack.dart' show LpElement;

/// Decodes a legacy Redis `ziplist` blob (pre-7.0 compact encoding, still
/// found in RDB files written by, or migrated from, older Redis versions).
/// Mirrors `ziplist.c`.
///
/// [bytes] must be the entire ziplist blob: 4-byte zlbytes LE, 4-byte
/// zltail LE, 2-byte zllen LE, entries, trailing 0xFF byte.
List<LpElement> decodeZiplist(Uint8List bytes) {
  final r = RdbByteReader(bytes);
  r.skip(4); // zlbytes
  r.skip(4); // zltail
  r.skip(2); // zllen (may be the 0xFFFF "unknown, scan to find" sentinel)

  final elements = <LpElement>[];
  while (true) {
    if (r.isAtEnd) {
      throw RdbFormatException('Ziplist ohne Terminator-Byte (0xFF).');
    }
    if (r.peekByte() == 0xFF) {
      r.skip(1);
      break;
    }

    // prevlen field: 1 byte if < 254, otherwise a 0xFE marker + 4 bytes LE.
    final prevlenMarker = r.readByte();
    if (prevlenMarker == 254) {
      r.skip(4);
    }

    final encByte = r.readByte();
    LpElement element;
    if ((encByte & 0xC0) != 0xC0) {
      // String entry; top 2 bits of encByte select the length width.
      final strType = encByte & 0xC0;
      int len;
      if (strType == 0x00) {
        len = encByte & 0x3F;
      } else if (strType == 0x40) {
        final b1 = r.readByte();
        len = ((encByte & 0x3F) << 8) | b1;
      } else {
        // 0x80: 32-bit big-endian length.
        len = r.readUint32BE();
      }
      element = LpElement.string(r.readBytes(len));
    } else {
      // Integer entry; full byte value selects the width.
      switch (encByte) {
        case 0xC0:
          element = LpElement.integer(r.readInt16LE());
          break;
        case 0xD0:
          element = LpElement.integer(r.readInt32LE());
          break;
        case 0xE0:
          element = LpElement.integer(r.readInt64LE());
          break;
        case 0xF0:
          element = LpElement.integer(r.readInt24LE());
          break;
        case 0xFE:
          element = LpElement.integer(r.readInt8());
          break;
        default:
          if (encByte >= 0xF1 && encByte <= 0xFD) {
            element = LpElement.integer((encByte & 0x0F) - 1);
          } else {
            throw RdbFormatException(
              'Unbekannte Ziplist-Ganzzahlkodierung: 0x${encByte.toRadixString(16)}',
              offset: r.offset,
            );
          }
      }
    }
    elements.add(element);
  }
  return elements;
}
