/// RDB value-type byte constants (rdb.h `RDB_TYPE_*`) and the container
/// opcodes (rdb.h `RDB_OPCODE_*`) that can appear at the top level of the
/// key/value stream, between database sections.
class RdbType {
  RdbType._();

  static const int string = 0;
  static const int list = 1;
  static const int set = 2;
  static const int zset = 3;
  static const int hash = 4;
  static const int zset2 = 5;
  static const int module = 6;
  static const int module2 = 7;
  static const int hashZipmap = 9;
  static const int listZiplist = 10;
  static const int setIntset = 11;
  static const int zsetZiplist = 12;
  static const int hashZiplist = 13;
  static const int listQuicklist = 14;
  static const int streamListpacks = 15;
  static const int hashListpack = 16;
  static const int zsetListpack = 17;
  static const int listQuicklist2 = 18;
  static const int streamListpacks2 = 19;
  static const int setListpack = 20;
  static const int streamListpacks3 = 21;
  static const int hashMetadataPreGa = 22;
  static const int hashListpackExPreGa = 23;
  static const int hashMetadata = 24;
  static const int hashListpackEx = 25;

  static String name(int typeByte) {
    switch (typeByte) {
      case string:
        return 'string';
      case list:
        return 'list (raw)';
      case set:
        return 'set (raw)';
      case zset:
        return 'zset (raw, ascii score)';
      case hash:
        return 'hash (raw)';
      case zset2:
        return 'zset (raw, binary score)';
      case module:
        return 'module';
      case module2:
        return 'module2';
      case hashZipmap:
        return 'hash (zipmap, legacy)';
      case listZiplist:
        return 'list (ziplist)';
      case setIntset:
        return 'set (intset)';
      case zsetZiplist:
        return 'zset (ziplist)';
      case hashZiplist:
        return 'hash (ziplist)';
      case listQuicklist:
        return 'list (quicklist/ziplist)';
      case streamListpacks:
        return 'stream (listpacks)';
      case hashListpack:
        return 'hash (listpack)';
      case zsetListpack:
        return 'zset (listpack)';
      case listQuicklist2:
        return 'list (quicklist2/listpack)';
      case streamListpacks2:
        return 'stream (listpacks v2)';
      case setListpack:
        return 'set (listpack)';
      case streamListpacks3:
        return 'stream (listpacks v3)';
      case hashMetadataPreGa:
        return 'hash (field-TTL, pre-GA)';
      case hashListpackExPreGa:
        return 'hash (listpack + field-TTL, pre-GA)';
      case hashMetadata:
        return 'hash (field-TTL)';
      case hashListpackEx:
        return 'hash (listpack + field-TTL)';
      default:
        return 'unbekannt (0x${typeByte.toRadixString(16)})';
    }
  }

  /// Types this parser can fully decode ("Standardtypen": string, list,
  /// hash, set, zset, across their raw/ziplist/listpack/intset/quicklist
  /// encodings). Everything else (streams, modules, zipmap, hash-field-TTL)
  /// is reported to the user but not decoded - see README for the
  /// rationale.
  static bool isSupported(int typeByte) {
    switch (typeByte) {
      case string:
      case list:
      case set:
      case zset:
      case hash:
      case zset2:
      case listZiplist:
      case setIntset:
      case zsetZiplist:
      case hashZiplist:
      case listQuicklist:
      case hashListpack:
      case zsetListpack:
      case listQuicklist2:
      case setListpack:
        return true;
      default:
        return false;
    }
  }
}

class RdbOpcode {
  RdbOpcode._();

  static const int slotInfo = 0xF4;
  static const int function2 = 0xF5;
  static const int function = 0xF6;
  static const int moduleAux = 0xF7;
  static const int idle = 0xF8;
  static const int freq = 0xF9;
  static const int auxField = 0xFA;
  static const int resizeDb = 0xFB;
  static const int expireTimeMs = 0xFC;
  static const int expireTime = 0xFD;
  static const int selectDb = 0xFE;
  static const int eof = 0xFF;
}
