import 'dart:typed_data';

/// A forward-only cursor over an in-memory RDB file buffer.
///
/// All RDB integers wider than one byte are big-endian *except* the ones
/// explicitly documented as little-endian in the format spec (the ziplist /
/// listpack container headers and integer element encodings, and the binary
/// zset score). Each read method below is named after the endianness it
/// uses so call sites in the parser stay self-documenting.
class RdbByteReader {
  RdbByteReader(this.bytes) : _offset = 0;

  final Uint8List bytes;
  int _offset;

  int get offset => _offset;
  int get length => bytes.length;
  bool get isAtEnd => _offset >= bytes.length;
  int get remaining => bytes.length - _offset;

  void _require(int n) {
    if (_offset + n > bytes.length) {
      throw RdbTruncatedException(
        'Unerwartetes Dateiende bei Offset $_offset (benötigt $n weitere Bytes, '
        'nur ${bytes.length - _offset} verfügbar).',
      );
    }
  }

  int readByte() {
    _require(1);
    return bytes[_offset++];
  }

  int peekByte() {
    _require(1);
    return bytes[_offset];
  }

  Uint8List readBytes(int n) {
    _require(n);
    final view = Uint8List.sublistView(bytes, _offset, _offset + n);
    _offset += n;
    return view;
  }

  void skip(int n) {
    _require(n);
    _offset += n;
  }

  int readUint16BE() {
    final b = readBytes(2);
    return (b[0] << 8) | b[1];
  }

  int readUint32BE() {
    final b = readBytes(4);
    return (b[0] << 24) | (b[1] << 16) | (b[2] << 8) | b[3];
  }

  int readUint64BE() {
    final b = readBytes(8);
    var v = 0;
    for (var i = 0; i < 8; i++) {
      v = (v << 8) | b[i];
    }
    return v;
  }

  int readUint16LE() {
    final b = readBytes(2);
    return b[0] | (b[1] << 8);
  }

  int readInt16LE() {
    final v = readUint16LE();
    return v >= 0x8000 ? v - 0x10000 : v;
  }

  int readUint32LE() {
    final b = readBytes(4);
    return b[0] | (b[1] << 8) | (b[2] << 16) | (b[3] << 24);
  }

  int readInt32LE() {
    final v = readUint32LE();
    return v >= 0x80000000 ? v - 0x100000000 : v;
  }

  int readUint64LE() {
    final b = readBytes(8);
    var v = 0;
    for (var i = 7; i >= 0; i--) {
      v = (v << 8) | b[i];
    }
    return v;
  }

  int readInt64LE() {
    final b = readBytes(8);
    var v = 0;
    for (var i = 7; i >= 0; i--) {
      v = (v << 8) | b[i];
    }
    // Interpret as signed 64-bit.
    final bd = ByteData(8);
    for (var i = 0; i < 8; i++) {
      bd.setUint8(i, b[i]);
    }
    return bd.getInt64(0, Endian.little);
  }

  int readInt8() {
    final v = readByte();
    return v >= 0x80 ? v - 0x100 : v;
  }

  int readInt24LE() {
    final b = readBytes(3);
    var v = b[0] | (b[1] << 8) | (b[2] << 16);
    if (v >= 0x800000) v -= 0x1000000;
    return v;
  }

  double readDoubleLE() {
    final b = readBytes(8);
    final bd = ByteData.sublistView(b);
    return bd.getFloat64(0, Endian.little);
  }
}

class RdbTruncatedException implements Exception {
  RdbTruncatedException(this.message);
  final String message;
  @override
  String toString() => message;
}

class RdbFormatException implements Exception {
  RdbFormatException(this.message, {this.offset});
  final String message;
  final int? offset;
  @override
  String toString() =>
      offset == null ? message : '$message (Offset $offset)';
}

class RdbUnsupportedTypeException implements Exception {
  RdbUnsupportedTypeException(this.message, {this.offset, this.typeByte});
  final String message;
  final int? offset;
  final int? typeByte;
  @override
  String toString() =>
      offset == null ? message : '$message (Offset $offset)';
}
