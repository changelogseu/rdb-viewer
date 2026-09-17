import 'dart:convert';
import 'dart:typed_data';

import 'byte_reader.dart';
import 'lzf.dart';

/// Result of decoding an RDB "length" field. RDB overloads the length
/// encoding to also signal special string encodings (integers / LZF), so
/// [isSpecialEncoding] + [specialEncoding] must be checked by callers that
/// accept both plain lengths and encoded strings (i.e. `rdbLoadStringObject`
/// call sites); callers that only ever expect a plain count (list/hash/set
/// sizes, ziplist header fields with lengths already resolved, etc.) can
/// ignore them - a special-encoding byte in that position is a format error
/// and [readLength] throws for it automatically.
class RdbLength {
  RdbLength.plain(this.value)
      : isSpecialEncoding = false,
        specialEncoding = -1;
  RdbLength.special(this.specialEncoding)
      : isSpecialEncoding = true,
        value = -1;

  final int value;
  final bool isSpecialEncoding;
  final int specialEncoding;
}

const int rdbEncInt8 = 0;
const int rdbEncInt16 = 1;
const int rdbEncInt32 = 2;
const int rdbEncLzf = 3;

/// Reads a length-encoded integer, per `rdbLoadLenByRef` in rdb.c.
/// The top two bits of the first byte select the encoding:
///   00xxxxxx                -> 6-bit length
///   01xxxxxx yyyyyyyy       -> 14-bit length
///   10000000 + 4 bytes BE   -> 32-bit length
///   10000001 + 8 bytes BE   -> 64-bit length
///   11xxxxxx                -> "special encoding", xxxxxx identifies it
RdbLength readLengthAllowSpecial(RdbByteReader r) {
  final first = r.readByte();
  final type = (first & 0xC0) >> 6;
  switch (type) {
    case 0:
      return RdbLength.plain(first & 0x3F);
    case 1:
      final next = r.readByte();
      return RdbLength.plain(((first & 0x3F) << 8) | next);
    case 2:
      if (first == 0x80) {
        return RdbLength.plain(r.readUint32BE());
      } else if (first == 0x81) {
        return RdbLength.plain(r.readUint64BE());
      }
      throw RdbFormatException(
        'Unbekannte 32/64-Bit Längenkodierung: 0x${first.toRadixString(16)}',
        offset: r.offset,
      );
    case 3:
      return RdbLength.special(first & 0x3F);
    default:
      throw StateError('unreachable');
  }
}

/// Reads a plain length (list/hash/set element counts, etc.). Throws if the
/// byte turns out to encode a special string encoding instead - that would
/// indicate the file is corrupt or the parser called the wrong reader.
int readLength(RdbByteReader r) {
  final l = readLengthAllowSpecial(r);
  if (l.isSpecialEncoding) {
    throw RdbFormatException(
      'Erwartete einfache Länge, aber Spezial-Kodierung gefunden.',
      offset: r.offset,
    );
  }
  return l.value;
}

/// A decoded RDB string value. RDB strings are binary-safe byte sequences;
/// [text] is a best-effort UTF-8 decoding used for display/editing, and
/// [isValidUtf8] tells the UI whether it is safe to treat this as editable
/// text or whether it must be shown/exported as opaque binary.
class RdbString {
  RdbString(this.bytes)
      : text = _tryUtf8(bytes),
        isValidUtf8 = _tryUtf8(bytes) != null;

  final Uint8List bytes;
  final String? text;
  final bool isValidUtf8;

  static String? _tryUtf8(Uint8List bytes) {
    try {
      return utf8.decode(bytes, allowMalformed: false);
    } catch (_) {
      return null;
    }
  }

  /// Text for display purposes: valid UTF-8 if possible, otherwise a lossy
  /// decoding (replacement characters) purely so something renders.
  String get displayText => text ?? utf8.decode(bytes, allowMalformed: true);

  factory RdbString.fromText(String text) => RdbString(Uint8List.fromList(utf8.encode(text)));

  @override
  String toString() => displayText;
}

/// Reads an RDB "string object": either a raw byte string, an integer
/// stored compactly (int8/16/32), or an LZF-compressed string. Mirrors
/// `rdbGenericLoadStringObject` in rdb.c.
RdbString readString(RdbByteReader r) {
  final l = readLengthAllowSpecial(r);
  if (!l.isSpecialEncoding) {
    return RdbString(r.readBytes(l.value));
  }
  switch (l.specialEncoding) {
    case rdbEncInt8:
      return RdbString.fromText(r.readInt8().toString());
    case rdbEncInt16:
      return RdbString.fromText(r.readInt16LE().toString());
    case rdbEncInt32:
      return RdbString.fromText(r.readInt32LE().toString());
    case rdbEncLzf:
      final clen = readLength(r);
      final ulen = readLength(r);
      final compressed = r.readBytes(clen);
      final plain = lzfDecompress(compressed, ulen);
      return RdbString(plain);
    default:
      throw RdbFormatException(
        'Unbekannte String-Spezialkodierung: ${l.specialEncoding}',
        offset: r.offset,
      );
  }
}

/// Reads the legacy ASCII-formatted double used by RDB_TYPE_ZSET (score
/// stored as text, 1-byte length prefix, with sentinels for +-inf/nan).
double readAsciiDouble(RdbByteReader r) {
  final len = r.readByte();
  switch (len) {
    case 255:
      return double.negativeInfinity;
    case 254:
      return double.infinity;
    case 253:
      return double.nan;
    default:
      final bytes = r.readBytes(len);
      return double.parse(ascii.decode(bytes));
  }
}
