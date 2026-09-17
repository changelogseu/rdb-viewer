import 'dart:typed_data';

import 'byte_reader.dart';

/// Decompresses a buffer produced by LZF (liblzf), the compression scheme
/// Redis uses for RDB string encoding. Mirrors `lzf_d.c`'s `lzf_decompress`.
Uint8List lzfDecompress(Uint8List input, int expectedOutputLength) {
  final out = Uint8List(expectedOutputLength);
  var ip = 0;
  var op = 0;

  while (ip < input.length) {
    var ctrl = input[ip++];
    if (ctrl < 32) {
      // Literal run of (ctrl + 1) bytes.
      final len = ctrl + 1;
      if (ip + len > input.length || op + len > out.length) {
        throw RdbFormatException('LZF: literal run überschreitet Puffergrenzen.');
      }
      out.setRange(op, op + len, input, ip);
      ip += len;
      op += len;
    } else {
      // Back-reference.
      var len = ctrl >> 5;
      if (len == 7) {
        if (ip >= input.length) {
          throw RdbFormatException('LZF: unerwartetes Ende bei Längen-Erweiterung.');
        }
        len += input[ip++];
      }
      if (ip >= input.length) {
        throw RdbFormatException('LZF: unerwartetes Ende bei Rückverweis.');
      }
      var ref = op - ((ctrl & 0x1f) << 8) - input[ip++] - 1;
      len += 2;
      if (ref < 0 || op + len > out.length) {
        throw RdbFormatException('LZF: ungültiger Rückverweis (ref=$ref).');
      }
      for (var i = 0; i < len; i++) {
        out[op + i] = out[ref + i];
      }
      op += len;
    }
  }

  if (op != expectedOutputLength) {
    throw RdbFormatException(
      'LZF: dekomprimierte Länge stimmt nicht überein (erwartet '
      '$expectedOutputLength, erhalten $op).',
    );
  }
  return out;
}
