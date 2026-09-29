# Changelog

All notable changes to this project are documented here. Format loosely
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.2.0] - 2026-09-29

### Added

- **Save as .rdb**: export the current (possibly edited) document as a new,
  loadable `.rdb` file, via "Als .rdb-Datei speichern..." in the export
  menu. Always writes a *new* file - the original is never overwritten.
  Only available when the source file was fully parsed (see below); values
  are always written in their simple "raw" on-disk form.
- **Update check**: a manual, user-triggered button in the top nav bar
  checks GitHub Releases for a newer version and offers a direct download
  link. Never runs automatically - the only network request anywhere in
  the app.

### Changed

- Clarified that "Save as .rdb" is refused (with an explanatory dialog) if
  the source file contains keys this parser couldn't decode (streams,
  modules, legacy zipmap hashes, Redis 7.4+ hash-field-TTL) - re-exporting a
  partially-read file would otherwise silently drop that data.

## [0.1.0] - 2026-09-17

Initial public release.

### Added

- Open, browse, search/filter, and edit Redis `.rdb` backup files on
  Windows and macOS.
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
  or Redis commands instead (see the README's "Limitations" section for
  the rationale).
- Streams, Redis module types, legacy zipmap-encoded hashes, and the Redis
  7.4+ hash-field-TTL encodings are not decoded; the app reports them
  clearly instead of silently skipping or corrupting data.

[Unreleased]: https://github.com/changelogseu/rdb-viewer/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/changelogseu/rdb-viewer/releases/tag/v0.2.0
[0.1.0]: https://github.com/changelogseu/rdb-viewer/releases/tag/v0.1.0
