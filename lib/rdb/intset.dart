import 'byte_reader.dart';

/// Decodes a Redis `intset` blob (used for small integer-only sets, RDB
/// type RDB_TYPE_SET_INTSET). Layout: uint32 LE encoding (2/4/8 = byte
/// width per element), uint32 LE element count, then that many
/// little-endian signed integers of the given width.
List<int> decodeIntset(RdbByteReader r) {
  final encoding = r.readUint32LE();
  final length = r.readUint32LE();
  final result = <int>[];
  for (var i = 0; i < length; i++) {
    switch (encoding) {
      case 2:
        result.add(r.readInt16LE());
        break;
      case 4:
        result.add(r.readInt32LE());
        break;
      case 8:
        result.add(r.readInt64LE());
        break;
      default:
        throw RdbFormatException(
          'Unbekannte intset-Elementbreite: $encoding Bytes',
          offset: r.offset,
        );
    }
  }
  return result;
}
