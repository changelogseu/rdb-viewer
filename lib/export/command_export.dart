import '../rdb/length_and_string.dart';
import '../rdb/rdb_model.dart';

/// Quotes a value for use in a redis-cli-style command line, the way
/// `redis-cli` itself parses arguments back: bare if it contains no
/// whitespace/quote/backslash and decodes as valid UTF-8, otherwise a
/// double-quoted string with \n \r \t \\ \" and \xHH escapes. This is a
/// convenience export for pasting into `redis-cli` or piping through
/// `redis-cli --pipe`; it is not a byte-exact serialization the way the
/// JSON export (with base64 for binary values) is.
String _quote(RdbString s) {
  if (s.isValidUtf8 && !_needsQuoting(s.text!)) {
    return s.text!;
  }
  final buffer = StringBuffer('"');
  for (final byte in s.bytes) {
    switch (byte) {
      case 0x22: // "
        buffer.write(r'\"');
        break;
      case 0x5C: // backslash
        buffer.write(r'\\');
        break;
      case 0x0A:
        buffer.write(r'\n');
        break;
      case 0x0D:
        buffer.write(r'\r');
        break;
      case 0x09:
        buffer.write(r'\t');
        break;
      default:
        if (byte >= 0x20 && byte < 0x7F) {
          buffer.writeCharCode(byte);
        } else {
          buffer.write('\\x${byte.toRadixString(16).padLeft(2, '0')}');
        }
    }
  }
  buffer.write('"');
  return buffer.toString();
}

bool _needsQuoting(String text) {
  if (text.isEmpty) return true;
  return text.contains(RegExp(r'[\s"\\]'));
}

/// Renders one key as one or more Redis commands that would recreate it,
/// e.g. for pasting into `redis-cli` or a `MULTI` script.
List<String> commandsForEntry(RdbEntry entry) {
  final key = _quote(entry.key);
  final lines = <String>[];
  final v = entry.value;
  switch (v.kind) {
    case RdbValueKind.string:
      lines.add('SET $key ${_quote(v.stringValue!)}');
      break;
    case RdbValueKind.list:
      if (v.listValue!.isEmpty) break;
      final items = v.listValue!.map(_quote).join(' ');
      lines.add('RPUSH $key $items');
      break;
    case RdbValueKind.hash:
      if (v.hashValue!.isEmpty) break;
      final pairs =
          v.hashValue!.map((f) => '${_quote(f.field)} ${_quote(f.value)}').join(' ');
      lines.add('HSET $key $pairs');
      break;
    case RdbValueKind.set:
      if (v.setValue!.isEmpty) break;
      final items = v.setValue!.map(_quote).join(' ');
      lines.add('SADD $key $items');
      break;
    case RdbValueKind.zset:
      if (v.zsetValue!.isEmpty) break;
      final pairs = v.zsetValue!
          .map((m) => '${_formatScore(m.score)} ${_quote(m.member)}')
          .join(' ');
      lines.add('ZADD $key $pairs');
      break;
  }
  if (entry.hasExpiry && lines.isNotEmpty) {
    lines.add('PEXPIREAT $key ${entry.expireAtMs}');
  }
  return lines;
}

String _formatScore(double score) {
  if (score.isInfinite) return score.isNegative ? '-inf' : '+inf';
  if (score == score.roundToDouble() && score.abs() < 1e15) {
    return score.toInt().toString();
  }
  return score.toString();
}

/// Renders every key of a database as a command script.
String commandsForDatabase(RdbDatabase db) {
  final buffer = StringBuffer();
  for (final entry in db.entries) {
    for (final line in commandsForEntry(entry)) {
      buffer.writeln(line);
    }
  }
  return buffer.toString();
}
