import 'dart:convert';
import 'dart:typed_data';

import 'byte_reader.dart';
import 'crc64.dart';
import 'intset.dart';
import 'length_and_string.dart';
import 'listpack.dart';
import 'rdb_model.dart';
import 'rdb_type_bytes.dart';
import 'ziplist.dart';

/// Parses a full .rdb file buffer into an [RdbDocument].
///
/// Design note: RDB has no generic "skip a value I don't understand"
/// mechanism - every type's loader must consume exactly its own bytes, and
/// an unknown type byte makes the rest of the stream unrecoverable (this is
/// also true of Redis's own loader). So when we hit a type this parser
/// doesn't support (see [RdbType.isSupported]), we record it in
/// [RdbDocument.unparsedKeys] and stop scanning - everything decoded up to
/// that point is still returned.
RdbDocument parseRdbFile(Uint8List bytes, {required String sourcePath}) {
  if (bytes.length < 9) {
    throw RdbFormatException('Datei ist zu kurz für einen gültigen RDB-Header.');
  }
  final magic = ascii.decode(bytes.sublist(0, 5), allowInvalid: true);
  if (magic != 'REDIS') {
    throw RdbFormatException(
      'Kein gültiger RDB-Header gefunden (erwartet "REDIS...", gefunden "$magic").',
    );
  }
  final versionStr = ascii.decode(bytes.sublist(5, 9), allowInvalid: true);
  final version = int.tryParse(versionStr);
  if (version == null) {
    throw RdbFormatException('Ungültige RDB-Versionsnummer: "$versionStr".');
  }

  final r = RdbByteReader(bytes);
  r.skip(9);

  final doc = RdbDocument(
    rdbVersion: version,
    sourcePath: sourcePath,
    fileSizeBytes: bytes.length,
  );

  RdbDatabase? currentDb;
  int? pendingExpireMs;

  void ensureDb() {
    if (currentDb == null) {
      currentDb = RdbDatabase(0);
      doc.databases.add(currentDb!);
    }
  }

  bool stopped = false;

  while (!stopped) {
    if (r.isAtEnd) {
      // Malformed file: ran out of bytes before an EOF opcode. Treat what
      // we have as final, but flag it.
      doc.checksumStatus = ChecksumStatus.notChecked;
      break;
    }
    final opcode = r.readByte();

    if (opcode == RdbOpcode.eof) {
      _verifyChecksum(doc, bytes, r);
      break;
    } else if (opcode == RdbOpcode.selectDb) {
      final index = readLength(r);
      currentDb = RdbDatabase(index);
      doc.databases.add(currentDb!);
    } else if (opcode == RdbOpcode.resizeDb) {
      final hashSize = readLength(r);
      final expiresSize = readLength(r);
      ensureDb();
      currentDb!.resizeDbHashSize = hashSize;
      currentDb!.resizeDbExpiresSize = expiresSize;
    } else if (opcode == RdbOpcode.expireTime) {
      final seconds = r.readUint32LE();
      pendingExpireMs = seconds * 1000;
    } else if (opcode == RdbOpcode.expireTimeMs) {
      pendingExpireMs = r.readUint64LE();
    } else if (opcode == RdbOpcode.auxField) {
      final k = readString(r);
      final v = readString(r);
      doc.auxFields[k.displayText] = v.displayText;
    } else if (opcode == RdbOpcode.idle) {
      readLength(r); // idle seconds - not modelled in phase 1, just consumed
    } else if (opcode == RdbOpcode.freq) {
      r.readByte(); // LFU freq - not modelled in phase 1, just consumed
    } else if (opcode == RdbOpcode.slotInfo) {
      readLength(r); // slot id
      readLength(r); // slot size
      readLength(r); // expires slot size
    } else if (opcode == RdbOpcode.function || opcode == RdbOpcode.function2) {
      readString(r); // function library code blob - not a key, discarded
    } else if (opcode == RdbOpcode.moduleAux) {
      doc.fatalStopReason =
          'Die Datei enthält Modul-Daten (MODULE_AUX) bei Offset ${r.offset - 1}, '
          'die dieser Parser nicht lesen kann. Der Aufbau von Moduldaten ist '
          'modulspezifisch und ohne das jeweilige Modul nicht sicher '
          'überspringbar - alle bis hierhin gelesenen Schlüssel bleiben aber '
          'erhalten.';
      stopped = true;
    } else {
      // Anything else is a value-type byte: [type][key][value], optionally
      // preceded by an EXPIRETIME(_MS) opcode already consumed above.
      final typeByte = opcode;
      ensureDb();
      final key = readString(r);
      final expireAtMs = pendingExpireMs;
      pendingExpireMs = null;

      if (!RdbType.isSupported(typeByte)) {
        doc.unparsedKeys.add(UnparsedKeyInfo(
          dbIndex: currentDb!.index,
          key: key,
          typeByte: typeByte,
          typeName: RdbType.name(typeByte),
          fileOffset: r.offset,
        ));
        stopped = true;
        break;
      }

      final value = _readValue(r, typeByte);
      currentDb!.entries.add(RdbEntry(
        key: key,
        value: value,
        expireAtMs: expireAtMs,
        originalTypeByte: typeByte,
        originalEncodingLabel: RdbType.name(typeByte),
      ));
    }
  }

  return doc;
}

void _verifyChecksum(RdbDocument doc, Uint8List bytes, RdbByteReader r) {
  if (doc.rdbVersion < 5) {
    doc.checksumStatus = ChecksumStatus.disabled;
    return;
  }
  if (r.remaining < 8) {
    doc.checksumStatus = ChecksumStatus.notChecked;
    return;
  }
  final storedBytes = r.readBytes(8);
  var stored = 0;
  for (var i = 7; i >= 0; i--) {
    stored = (stored << 8) | storedBytes[i];
  }
  if (stored == 0) {
    doc.checksumStatus = ChecksumStatus.disabled;
    return;
  }
  final coveredLength = r.offset - 8;
  final computed = Crc64Jones.update(0, Uint8List.sublistView(bytes, 0, coveredLength));
  doc.storedChecksum = stored;
  doc.computedChecksum = computed;
  doc.checksumStatus =
      computed == stored ? ChecksumStatus.valid : ChecksumStatus.mismatch;
}

RdbValue _readValue(RdbByteReader r, int typeByte) {
  switch (typeByte) {
    case RdbType.string:
      return RdbValue.string(readString(r));

    case RdbType.list:
      final n = readLength(r);
      return RdbValue.list(List.generate(n, (_) => readString(r)));

    case RdbType.set:
      final n = readLength(r);
      return RdbValue.set(List.generate(n, (_) => readString(r)));

    case RdbType.zset:
      final n = readLength(r);
      return RdbValue.zset(List.generate(n, (_) {
        final member = readString(r);
        final score = readAsciiDouble(r);
        return ZsetMember(member, score);
      }));

    case RdbType.zset2:
      final n = readLength(r);
      return RdbValue.zset(List.generate(n, (_) {
        final member = readString(r);
        final score = r.readDoubleLE();
        return ZsetMember(member, score);
      }));

    case RdbType.hash:
      final n = readLength(r);
      return RdbValue.hash(List.generate(n, (_) {
        final field = readString(r);
        final value = readString(r);
        return HashField(field, value);
      }));

    case RdbType.listZiplist:
      final blob = readString(r).bytes;
      final elements = decodeZiplist(blob);
      return RdbValue.list(elements.map(_lpElementToRdbString).toList());

    case RdbType.setIntset:
      final blob = readString(r).bytes;
      final ints = decodeIntset(RdbByteReader(blob));
      return RdbValue.set(
          ints.map((i) => RdbString.fromText(i.toString())).toList());

    case RdbType.zsetZiplist:
      final blob = readString(r).bytes;
      final elements = decodeZiplist(blob);
      return RdbValue.zset(_pairsToZset(elements));

    case RdbType.hashZiplist:
      final blob = readString(r).bytes;
      final elements = decodeZiplist(blob);
      return RdbValue.hash(_pairsToHash(elements));

    case RdbType.listQuicklist:
      final nodeCount = readLength(r);
      final items = <RdbString>[];
      for (var i = 0; i < nodeCount; i++) {
        final nodeBlob = readString(r).bytes;
        final elements = decodeZiplist(nodeBlob);
        items.addAll(elements.map(_lpElementToRdbString));
      }
      return RdbValue.list(items);

    case RdbType.hashListpack:
      final blob = readString(r).bytes;
      final elements = decodeListpack(blob);
      return RdbValue.hash(_pairsToHash(elements));

    case RdbType.zsetListpack:
      final blob = readString(r).bytes;
      final elements = decodeListpack(blob);
      return RdbValue.zset(_pairsToZset(elements));

    case RdbType.setListpack:
      final blob = readString(r).bytes;
      final elements = decodeListpack(blob);
      return RdbValue.set(elements.map(_lpElementToRdbString).toList());

    case RdbType.listQuicklist2:
      final nodeCount = readLength(r);
      final items = <RdbString>[];
      for (var i = 0; i < nodeCount; i++) {
        final container = readLength(r); // 1 = PLAIN, 2 = PACKED (listpack)
        final nodeBlob = readString(r).bytes;
        if (container == 1) {
          items.add(RdbString(nodeBlob));
        } else if (container == 2) {
          final elements = decodeListpack(nodeBlob);
          items.addAll(elements.map(_lpElementToRdbString));
        } else {
          throw RdbFormatException(
            'Unbekannter Quicklist2-Container-Typ: $container',
            offset: r.offset,
          );
        }
      }
      return RdbValue.list(items);

    default:
      // Should be unreachable - callers check RdbType.isSupported first.
      throw RdbUnsupportedTypeException(
        'Nicht unterstützter Werttyp: ${RdbType.name(typeByte)}',
        offset: r.offset,
        typeByte: typeByte,
      );
  }
}

RdbString _lpElementToRdbString(LpElement e) {
  if (e.isInteger) return RdbString.fromText(e.intValue!.toString());
  return RdbString(e.stringValue!);
}

double _lpElementToDouble(LpElement e) {
  if (e.isInteger) return e.intValue!.toDouble();
  final text = utf8.decode(e.stringValue!, allowMalformed: true);
  final parsed = double.tryParse(text);
  if (parsed == null) {
    throw RdbFormatException('Ungültiger Zset-Score: "$text"');
  }
  return parsed;
}

List<HashField> _pairsToHash(List<LpElement> elements) {
  if (elements.length.isOdd) {
    throw RdbFormatException('Hash-Container mit ungerader Elementanzahl.');
  }
  final result = <HashField>[];
  for (var i = 0; i < elements.length; i += 2) {
    result.add(HashField(
      _lpElementToRdbString(elements[i]),
      _lpElementToRdbString(elements[i + 1]),
    ));
  }
  return result;
}

List<ZsetMember> _pairsToZset(List<LpElement> elements) {
  if (elements.length.isOdd) {
    throw RdbFormatException('Zset-Container mit ungerader Elementanzahl.');
  }
  final result = <ZsetMember>[];
  for (var i = 0; i < elements.length; i += 2) {
    result.add(ZsetMember(
      _lpElementToRdbString(elements[i]),
      _lpElementToDouble(elements[i + 1]),
    ));
  }
  return result;
}
