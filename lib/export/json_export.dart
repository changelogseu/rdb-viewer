import 'dart:convert';

import '../rdb/length_and_string.dart';
import '../rdb/rdb_model.dart';

/// Converts an [RdbString] to a JSON-safe value: the decoded text if it is
/// valid UTF-8, otherwise a `{"__base64__": "..."}` wrapper so binary
/// values still round-trip losslessly through the export.
dynamic _stringToJson(RdbString s) {
  if (s.isValidUtf8) return s.text;
  return {'__base64__': base64Encode(s.bytes)};
}

Map<String, dynamic> _valueToJson(RdbValue v) {
  switch (v.kind) {
    case RdbValueKind.string:
      return {'type': 'string', 'value': _stringToJson(v.stringValue!)};
    case RdbValueKind.list:
      return {
        'type': 'list',
        'value': v.listValue!.map(_stringToJson).toList(),
      };
    case RdbValueKind.hash:
      return {
        'type': 'hash',
        'value': {
          for (final f in v.hashValue!) _jsonKeyFor(f.field): _stringToJson(f.value),
        },
      };
    case RdbValueKind.set:
      return {
        'type': 'set',
        'value': v.setValue!.map(_stringToJson).toList(),
      };
    case RdbValueKind.zset:
      return {
        'type': 'zset',
        'value': [
          for (final m in v.zsetValue!)
            {'member': _stringToJson(m.member), 'score': m.score},
        ],
      };
  }
}

/// JSON object keys must be strings; binary field names are hex-encoded
/// with a marker prefix so they stay distinguishable and lossless.
String _jsonKeyFor(RdbString s) => s.isValidUtf8 ? s.text! : '__hex:${_toHex(s.bytes)}';

String _toHex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// Exports the full document (all databases) as pretty-printed JSON.
String exportDocumentToJson(RdbDocument doc) {
  final root = {
    'sourceFile': doc.sourcePath,
    'rdbVersion': doc.rdbVersion,
    'auxFields': doc.auxFields,
    'databases': [
      for (final db in doc.databases)
        {
          'index': db.index,
          'keys': {
            for (final e in db.entries)
              _jsonKeyFor(e.key): {
                ..._valueToJson(e.value),
                if (e.hasExpiry) 'expireAtMs': e.expireAtMs,
              },
          },
        },
    ],
    if (doc.unparsedKeys.isNotEmpty)
      'unsupportedKeys': [
        for (final u in doc.unparsedKeys)
          {'db': u.dbIndex, 'key': _jsonKeyFor(u.key), 'type': u.typeName},
      ],
  };
  return const JsonEncoder.withIndent('  ').convert(root);
}

/// Exports a single entry as pretty-printed JSON (for "export this key").
String exportEntryToJson(RdbEntry entry) {
  final root = {
    'key': _jsonKeyFor(entry.key),
    ..._valueToJson(entry.value),
    if (entry.hasExpiry) 'expireAtMs': entry.expireAtMs,
  };
  return const JsonEncoder.withIndent('  ').convert(root);
}
