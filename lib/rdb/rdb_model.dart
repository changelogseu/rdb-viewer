import 'length_and_string.dart';

/// The kind of value stored under an RDB key, independent of the specific
/// on-disk encoding (ziplist vs. listpack vs. raw all collapse to their
/// logical type here).
enum RdbValueKind { string, list, hash, set, zset }

/// A single member of a sorted set: value + score.
class ZsetMember {
  ZsetMember(this.member, this.score);
  RdbString member;
  double score;
}

/// A single field/value pair of a hash. A plain class (not `MapEntry`, and
/// not a `Map<RdbString, RdbString>`) so both sides can be edited in place
/// and so we don't have to rely on `RdbString`'s identity-based equality
/// for map-key semantics.
class HashField {
  HashField(this.field, this.value);
  RdbString field;
  RdbString value;
}

/// The decoded value of one key, in a form the UI can render and edit
/// without knowing anything about ziplist/listpack/intset on-disk details.
class RdbValue {
  RdbValue.string(RdbString value)
      : kind = RdbValueKind.string,
        stringValue = value,
        listValue = null,
        hashValue = null,
        setValue = null,
        zsetValue = null;

  RdbValue.list(List<RdbString> value)
      : kind = RdbValueKind.list,
        stringValue = null,
        listValue = value,
        hashValue = null,
        setValue = null,
        zsetValue = null;

  RdbValue.hash(List<HashField> value)
      : kind = RdbValueKind.hash,
        stringValue = null,
        listValue = null,
        hashValue = value,
        setValue = null,
        zsetValue = null;

  RdbValue.set(List<RdbString> value)
      : kind = RdbValueKind.set,
        stringValue = null,
        listValue = null,
        hashValue = null,
        setValue = value,
        zsetValue = null;

  RdbValue.zset(List<ZsetMember> value)
      : kind = RdbValueKind.zset,
        stringValue = null,
        listValue = null,
        hashValue = null,
        setValue = null,
        zsetValue = value;

  final RdbValueKind kind;
  RdbString? stringValue;
  List<RdbString>? listValue;
  List<HashField>? hashValue;
  List<RdbString>? setValue;
  List<ZsetMember>? zsetValue;

  /// Rough size, used for sorting/highlighting "big keys".
  int get elementCount {
    switch (kind) {
      case RdbValueKind.string:
        return 1;
      case RdbValueKind.list:
        return listValue!.length;
      case RdbValueKind.hash:
        return hashValue!.length;
      case RdbValueKind.set:
        return setValue!.length;
      case RdbValueKind.zset:
        return zsetValue!.length;
    }
  }

  int get approxByteSize {
    switch (kind) {
      case RdbValueKind.string:
        return stringValue!.bytes.length;
      case RdbValueKind.list:
        return listValue!.fold(0, (a, b) => a + b.bytes.length);
      case RdbValueKind.hash:
        return hashValue!
            .fold(0, (a, e) => a + e.field.bytes.length + e.value.bytes.length);
      case RdbValueKind.set:
        return setValue!.fold(0, (a, b) => a + b.bytes.length);
      case RdbValueKind.zset:
        return zsetValue!.fold(0, (a, b) => a + b.member.bytes.length + 8);
    }
  }
}

/// One key in one database of the RDB file, plus metadata (TTL, and the
/// index/LFU/LRU hints Redis stores alongside it).
class RdbEntry {
  RdbEntry({
    required this.key,
    required this.value,
    this.expireAtMs,
    this.originalTypeByte,
    this.originalEncodingLabel,
  });

  RdbString key;
  RdbValue value;

  /// Absolute expiry as Unix epoch milliseconds, or null if the key has no
  /// TTL.
  int? expireAtMs;

  /// The raw RDB type byte this entry was decoded from - kept for display
  /// ("Encoding: listpack" etc.) and for future RDB re-write support.
  final int? originalTypeByte;
  final String? originalEncodingLabel;

  bool get hasExpiry => expireAtMs != null;

  bool get isExpired =>
      expireAtMs != null &&
      DateTime.fromMillisecondsSinceEpoch(expireAtMs!).isBefore(DateTime.now());

  /// Tracks whether this entry was modified in the UI since load, purely
  /// for display (e.g. a "changed" badge) - phase 1 has no RDB write-back.
  bool dirty = false;

  /// True for entries created in the UI (Add-Key) rather than read from the
  /// file - shown as a distinct "neu" badge instead of "geändert".
  bool isNew = false;
}

/// One logical Redis database (SELECTDB) within the file.
class RdbDatabase {
  RdbDatabase(this.index);
  final int index;
  final List<RdbEntry> entries = [];
  int? resizeDbHashSize;
  int? resizeDbExpiresSize;
}

/// The fully parsed contents of one .rdb file.
class RdbDocument {
  RdbDocument({
    required this.rdbVersion,
    required this.sourcePath,
    required this.fileSizeBytes,
  });

  final int rdbVersion;
  final String sourcePath;
  final int fileSizeBytes;
  final List<RdbDatabase> databases = [];
  final Map<String, String> auxFields = {}; // redis-ver, os, ctime, etc.

  /// Keys whose value type this parser could not decode (streams, modules,
  /// hash-field-TTL, ...). We record the key so the user can see it exists
  /// even though we can't show its contents, and stop decoding further
  /// entries in that database once we hit one (see rdb_parser.dart).
  final List<UnparsedKeyInfo> unparsedKeys = [];

  /// Set when parsing had to stop for a reason that isn't tied to one
  /// specific key (currently: MODULE_AUX data, which is module-specific and
  /// not structurally skippable). Everything parsed before the stop point
  /// is still valid and present in [databases].
  String? fatalStopReason;

  ChecksumStatus checksumStatus = ChecksumStatus.notChecked;

  /// The checksum stored in the file's trailing 8 bytes, and the one this
  /// parser computed over the bytes it covers - both as raw 64-bit values
  /// (format with `Crc64Jones.toHex64`). Set together with
  /// [checksumStatus]; both null when [checksumStatus] is
  /// [ChecksumStatus.disabled] or [ChecksumStatus.notChecked].
  int? storedChecksum;
  int? computedChecksum;

  int get totalKeyCount =>
      databases.fold(0, (a, db) => a + db.entries.length) + unparsedKeys.length;
}

enum ChecksumStatus { notChecked, disabled, valid, mismatch }

class UnparsedKeyInfo {
  UnparsedKeyInfo({
    required this.dbIndex,
    required this.key,
    required this.typeByte,
    required this.typeName,
    required this.fileOffset,
  });
  final int dbIndex;
  final RdbString key;
  final int typeByte;
  final String typeName;
  final int fileOffset;
}
