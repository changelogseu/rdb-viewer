import 'dart:convert';
import 'dart:typed_data';

import 'crc64.dart';
import 'length_and_string.dart';
import 'rdb_model.dart';
import 'rdb_type_bytes.dart';

/// Thrown when [writeRdbFile] is asked to serialize a document that isn't
/// safe to re-export - see [RdbDocument.isFullyParsed].
class RdbWriteRefusedException implements Exception {
  RdbWriteRefusedException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The RDB version this writer declares. Chosen as the lowest version that
/// already supports every opcode used below (AUX fields and RESIZEDB were
/// introduced in version 7; EXPIRETIME_MS is older still) - not the source
/// file's own version - so the output stays loadable by the widest possible
/// range of Redis versions regardless of what produced the original file.
const int _writerRdbVersion = 7;

void _writeLength(BytesBuilder out, int value) {
  if (value < 0) {
    throw ArgumentError('Länge darf nicht negativ sein: $value');
  }
  if (value < 64) {
    out.addByte(value);
  } else if (value < 16384) {
    out.addByte(0x40 | (value >> 8));
    out.addByte(value & 0xFF);
  } else if (value <= 0xFFFFFFFF) {
    out.addByte(0x80);
    out.addByte((value >> 24) & 0xFF);
    out.addByte((value >> 16) & 0xFF);
    out.addByte((value >> 8) & 0xFF);
    out.addByte(value & 0xFF);
  } else {
    out.addByte(0x81);
    final bd = ByteData(8)..setUint64(0, value, Endian.big);
    out.add(bd.buffer.asUint8List());
  }
}

/// Always writes the plain/raw string form (length-prefixed bytes) - never
/// the compact integer or LZF-compressed encodings. Redis has been able to
/// load raw strings since RDB version 1, so this trades a few bytes of
/// on-disk size for a much simpler, lower-risk writer (no LZF *compressor*
/// needed - only the decompressor in `lzf.dart`, which this never touches).
void _writeString(BytesBuilder out, RdbString s) {
  _writeLength(out, s.bytes.length);
  out.add(s.bytes);
}

void _writeDoubleLE(BytesBuilder out, double v) {
  final bd = ByteData(8)..setFloat64(0, v, Endian.little);
  out.add(bd.buffer.asUint8List());
}

void _writeUint64LE(BytesBuilder out, int v) {
  final bd = ByteData(8)..setUint64(0, v, Endian.little);
  out.add(bd.buffer.asUint8List());
}

/// Serializes [doc] back into a valid `.rdb` file, reflecting whatever is
/// currently in its in-memory model (including edits made in the UI: renamed
/// keys, added/removed entries, changed values/TTLs).
///
/// Every value is written in its "raw" form (see [_writeString]) regardless
/// of how it was originally encoded on disk - `originalTypeByte` /
/// `originalEncodingLabel` are purely informational and ignored here. This
/// is always valid: Redis has supported loading raw-encoded values for
/// every type used here since the earliest RDB versions.
///
/// Throws [RdbWriteRefusedException] if [doc] wasn't fully parsed (see
/// [RdbDocument.isFullyParsed]) - re-exporting a partially-read file would
/// silently drop whatever the parser couldn't read, which is exactly the
/// kind of data loss this check exists to prevent. Callers should also
/// check [RdbDocument.isFullyParsed] themselves before offering the
/// "save as .rdb" action in the UI, so the user never reaches this
/// exception in normal use.
Uint8List writeRdbFile(RdbDocument doc) {
  if (!doc.isFullyParsed) {
    throw RdbWriteRefusedException(
      'Diese Datei wurde nicht vollständig gelesen (nicht unterstützte '
      'Schlüssel oder Modul-Daten gefunden) - ein Speichern als .rdb würde '
      'die nicht gelesenen Teile der Datei verlieren. Nutze stattdessen den '
      'JSON- oder Redis-Befehle-Export.',
    );
  }

  final out = BytesBuilder();
  out.add(ascii.encode('REDIS${_writerRdbVersion.toString().padLeft(4, '0')}'));

  final auxFields = <String, String>{
    ...doc.auxFields,
    'redis-ver': doc.auxFields['redis-ver'] ?? '7.0.0',
    'rdbviewer-exported-at': DateTime.now().toUtc().toIso8601String(),
  };
  for (final entry in auxFields.entries) {
    out.addByte(RdbOpcode.auxField);
    _writeString(out, RdbString.fromText(entry.key));
    _writeString(out, RdbString.fromText(entry.value));
  }

  for (final db in doc.databases) {
    if (db.entries.isEmpty) continue; // matches real Redis: empty DBs are omitted

    out.addByte(RdbOpcode.selectDb);
    _writeLength(out, db.index);

    out.addByte(RdbOpcode.resizeDb);
    _writeLength(out, db.entries.length);
    _writeLength(out, db.entries.where((e) => e.hasExpiry).length);

    for (final entry in db.entries) {
      if (entry.hasExpiry) {
        out.addByte(RdbOpcode.expireTimeMs);
        _writeUint64LE(out, entry.expireAtMs!);
      }
      _writeValue(out, entry);
    }
  }

  out.addByte(RdbOpcode.eof);

  final bytes = out.toBytes();
  final checksum = Crc64Jones.update(0, bytes);
  final checksumBytes = ByteData(8)..setUint64(0, checksum, Endian.little);

  final result = BytesBuilder();
  result.add(bytes);
  result.add(checksumBytes.buffer.asUint8List());
  return result.toBytes();
}

void _writeValue(BytesBuilder out, RdbEntry entry) {
  final value = entry.value;
  switch (value.kind) {
    case RdbValueKind.string:
      out.addByte(RdbType.string);
      _writeString(out, entry.key);
      _writeString(out, value.stringValue!);
      break;

    case RdbValueKind.list:
      out.addByte(RdbType.list);
      _writeString(out, entry.key);
      _writeLength(out, value.listValue!.length);
      for (final item in value.listValue!) {
        _writeString(out, item);
      }
      break;

    case RdbValueKind.set:
      out.addByte(RdbType.set);
      _writeString(out, entry.key);
      _writeLength(out, value.setValue!.length);
      for (final member in value.setValue!) {
        _writeString(out, member);
      }
      break;

    case RdbValueKind.hash:
      out.addByte(RdbType.hash);
      _writeString(out, entry.key);
      _writeLength(out, value.hashValue!.length);
      for (final field in value.hashValue!) {
        _writeString(out, field.field);
        _writeString(out, field.value);
      }
      break;

    case RdbValueKind.zset:
      out.addByte(RdbType.zset2);
      _writeString(out, entry.key);
      _writeLength(out, value.zsetValue!.length);
      for (final member in value.zsetValue!) {
        _writeString(out, member.member);
        _writeDoubleLE(out, member.score);
      }
      break;
  }
}
