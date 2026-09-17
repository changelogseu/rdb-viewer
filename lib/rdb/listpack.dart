import 'dart:typed_data';

import 'byte_reader.dart';

/// One decoded listpack element: either an integer or a raw byte string.
class LpElement {
  LpElement.integer(int value)
      : intValue = value,
        stringValue = null;
  LpElement.string(Uint8List value)
      : intValue = null,
        stringValue = value;

  final int? intValue;
  final Uint8List? stringValue;

  bool get isInteger => intValue != null;
}

int _backlenByteCount(int entryLen) {
  if (entryLen <= 127) return 1;
  if (entryLen < 16384) return 2;
  if (entryLen < 2097152) return 3;
  if (entryLen < 268435456) return 4;
  return 5;
}

/// Decodes a Redis `listpack` blob (the modern compact encoding used since
/// Redis 7.0 for small hashes/lists/sets/zsets). Mirrors the entry layout
/// documented at the top of `listpack.c`.
///
/// [bytes] must be the *entire* listpack blob, including its 6-byte header
/// (4-byte total-bytes LE, 2-byte num-elements LE) and trailing 0xFF byte.
List<LpElement> decodeListpack(Uint8List bytes) {
  final r = RdbByteReader(bytes);
  r.skip(4); // total bytes (redundant with bytes.length)
  r.skip(2); // num elements (0xFFFF sentinel possible; we scan to 0xFF anyway)

  final elements = <LpElement>[];
  while (true) {
    if (r.isAtEnd) {
      throw RdbFormatException('Listpack ohne Terminator-Byte (0xFF).');
    }
    final first = r.peekByte();
    if (first == 0xFF) {
      r.skip(1);
      break;
    }

    final entryStart = r.offset;
    LpElement element;

    if ((first & 0x80) == 0x00) {
      // 7-bit unsigned int.
      r.skip(1);
      element = LpElement.integer(first & 0x7F);
    } else if ((first & 0xC0) == 0x80) {
      // 6-bit length string.
      r.skip(1);
      final len = first & 0x3F;
      element = LpElement.string(r.readBytes(len));
    } else if ((first & 0xE0) == 0xC0) {
      // 13-bit signed int.
      r.skip(1);
      final b1 = r.readByte();
      var value = ((first & 0x1F) << 8) | b1;
      if (value >= 4096) value -= 8192;
      element = LpElement.integer(value);
    } else if ((first & 0xF0) == 0xE0) {
      // 12-bit length string.
      r.skip(1);
      final b1 = r.readByte();
      final len = ((first & 0x0F) << 8) | b1;
      element = LpElement.string(r.readBytes(len));
    } else if (first == 0xF1) {
      r.skip(1);
      element = LpElement.integer(r.readInt16LE());
    } else if (first == 0xF2) {
      r.skip(1);
      element = LpElement.integer(r.readInt24LE());
    } else if (first == 0xF3) {
      r.skip(1);
      element = LpElement.integer(r.readInt32LE());
    } else if (first == 0xF4) {
      r.skip(1);
      element = LpElement.integer(r.readInt64LE());
    } else if (first == 0xF0) {
      r.skip(1);
      final len = r.readUint32LE();
      element = LpElement.string(r.readBytes(len));
    } else {
      throw RdbFormatException(
        'Unbekannte Listpack-Kodierung: 0x${first.toRadixString(16)}',
        offset: r.offset,
      );
    }

    final entryLen = r.offset - entryStart;
    r.skip(_backlenByteCount(entryLen));
    elements.add(element);
  }
  return elements;
}
