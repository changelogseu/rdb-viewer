# Changelog

All notable changes to this project are documented here. Format loosely
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- Initial public release: open, browse, search/filter, and edit Redis `.rdb`
  backup files on Windows and macOS.
- Support for String, List, Hash, Set, and Sorted Set values across their
  common on-disk encodings (raw, ziplist, listpack, intset, quicklist).
- Multi-database support, TTL/expiry display and editing, AUX metadata
  display.
- Add-key and delete-key support (in-memory; see Known limitations).
- Info tab: file-level diagnostics (RDB version, CRC64 checksum
  verification, per-database keyspace stats, unsupported-key report).
- Export: full document or a single key as JSON (binary-safe via base64) or
  as Redis commands (`SET`/`HSET`/`SADD`/`ZADD`/`RPUSH`/`PEXPIREAT`) for
  re-import via `redis-cli`.
- Command-line file argument support (`rdb_viewer.exe path/to/file.rdb`) for
  "Open with" integration.

### Known limitations

- No direct write-back into a `.rdb` file yet - edits are exported as JSON
  or Redis commands instead (see the README's "Bewusst nicht enthalten"
  section for the rationale).
- Streams, Redis module types, legacy zipmap-encoded hashes, and the Redis
  7.4+ hash-field-TTL encodings are not decoded; the app reports them
  clearly instead of silently skipping or corrupting data.
