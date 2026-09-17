import 'dart:typed_data';

/// CRC-64 (Jones variant, reflected) as used for the trailing checksum of
/// an RDB file (RDB version >= 5).
///
/// This is a direct transcription of Redis's own reference implementation,
/// `_crc64()` in `src/crc64.c`:
///
/// ```c
/// #define POLY UINT64_C(0xad93d23594c935a9)
///
/// uint64_t _crc64(uint_fast64_t crc, const void *in_data, const uint64_t len) {
///     const uint8_t *data = in_data;
///     unsigned long long bit;
///     for (uint64_t offset = 0; offset < len; offset++) {
///         uint8_t c = data[offset];
///         for (uint_fast8_t i = 0x01; i & 0xff; i <<= 1) {
///             bit = crc & 0x8000000000000000;
///             if (c & i) bit = !bit;
///             crc <<= 1;
///             if (bit) crc ^= POLY;
///         }
///     }
///     return crc_reflect(crc, 64);
/// }
/// ```
///
/// `POLY` is the *normal* (MSB-first) polynomial; each input byte's bits
/// are read LSB-first (the `i <<= 1` loop, an "input reflection" trick),
/// the internal register is advanced MSB-first against `POLY`, and the
/// whole 64-bit register is bit-reversed exactly once at the very end.
///
/// An earlier version of this file instead used `POLY` directly as the
/// polynomial for a table-driven, right-shifting "reflected" algorithm
/// (the usual fast implementation for refin/refout CRCs). That is only
/// equivalent to the code above if the polynomial is *also* bit-reversed
/// first - using `POLY` unreversed there silently computed a different,
/// internally self-consistent but wrong checksum, which is why real
/// Redis-written RDB files always showed a checksum mismatch even though
/// nothing was actually corrupt. This version matches Redis bit-for-bit
/// instead of re-deriving a reflected polynomial by hand.
///
/// Verified against `crc64.c`'s own `REDIS_TEST` vector:
/// `_crc64(0, "123456789", 9) == 0xe9c6d914c4b8d9ca` (see
/// `test/rdb/decoders_test.dart`).
///
/// Note: because the bit-reflection happens once at the end rather than
/// per byte, the returned value is *not* a valid `crc` seed for a
/// follow-up call the way a typical streaming CRC's is. Every call site in
/// this app checksums a whole buffer in one call (`update(0, allBytes)`),
/// which this implementation supports directly.
class Crc64Jones {
  Crc64Jones._();

  static const int _poly = 0xad93d23594c935a9;

  static int update(int crc, Uint8List data) {
    var c = crc;
    for (final byte in data) {
      for (var i = 0x01; (i & 0xff) != 0; i <<= 1) {
        var bit = (c & 0x8000000000000000) != 0;
        if ((byte & i) != 0) bit = !bit;
        c <<= 1;
        if (bit) c ^= _poly;
      }
    }
    return _reflect64(c);
  }

  static int _reflect64(int value) {
    var result = 0;
    var v = value;
    for (var i = 0; i < 64; i++) {
      result = (result << 1) | (v & 1);
      v >>>= 1;
    }
    return result;
  }

  /// Formats a 64-bit CRC as unsigned lowercase hex, zero-padded to 16
  /// digits. Dart's `int` is 64-bit signed, so a value with bit 63 set
  /// prints with a leading "-" from `toRadixString` directly; this splits
  /// the value into two 32-bit (always non-negative) halves instead.
  static String toHex64(int value) {
    final hi = (value >>> 32) & 0xFFFFFFFF;
    final lo = value & 0xFFFFFFFF;
    return hi.toRadixString(16).padLeft(8, '0') +
        lo.toRadixString(16).padLeft(8, '0');
  }
}
