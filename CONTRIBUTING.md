# Contributing to RDB Viewer

Thanks for considering a contribution! This is a small, focused desktop tool,
so the process is kept lightweight.

## Before you start

- For anything bigger than a small fix (a new value type, a new
  export/import format, a UI redesign), please open an issue first to
  discuss the approach - it avoids wasted work if the direction doesn't fit.
- Check open issues and PRs so you're not duplicating someone else's work.

## Development setup

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install)
(stable channel) with the Windows and/or macOS desktop toolchains enabled.

```bash
git clone https://github.com/changelogseu/rdb-viewer.git
cd rdb-viewer
flutter pub get
flutter test
flutter run -d windows   # or -d macos
```

Run `flutter doctor` first if `flutter run` complains about a missing
toolchain (Visual Studio "Desktop development with C++" on Windows, Xcode
command line tools on macOS).

## Project layout

See the [Architecture section of the README](README.md#architecture) - in
short: `lib/rdb/` is a pure-Dart RDB parsing library with no Flutter
dependency (and its own tests in `test/rdb/`), `lib/ui/` is the Flutter UI,
`lib/export/` handles JSON/Redis-command export.

## Before opening a pull request

```bash
flutter analyze   # must be clean
flutter test      # must pass
```

If you touched the RDB parser (`lib/rdb/`), please add a test in
`test/rdb/` - either a hand-built byte fixture for a new encoding/opcode, or
a regression test for the bug you fixed. Real `.rdb` files from a live Redis
instance are the best source of truth, but since fixtures are hand-built
against the format spec here (no `redis-server` was available while writing
this), a small `redis-cli`/`redis-server`-generated `.rdb` you can share
(even just the relevant bytes) is extremely valuable if you're fixing a
parsing bug.

## Reporting a file that won't open correctly

Please open an issue and include:

- What the **Info tab** shows (RDB version, checksum status, and - if
  present - the "nicht unterstützte Schlüssel" / unsupported-keys table with
  the type name and file offset)
- The Redis version that wrote the file, if known
- If possible, the `.rdb` file itself, or the smallest reproduction you can
  make with `redis-cli` (a single key of the problematic type is usually
  enough). Please make sure it doesn't contain data you don't want to share
  publicly - a `redis-cli --pipe`-able synthetic key is best.

## Code style

- Follow the existing style in the file you're editing over any personal
  preference; `flutter analyze` (backed by `analysis_options.yaml` /
  `flutter_lints`) is the actual source of truth.
- Comments explain *why*, not *what* - the code should already say what it
  does.
- Keep `lib/rdb/` free of any `package:flutter` import.

## License

By contributing, you agree that your contributions will be licensed under
the project's [GPL-3.0-or-later license](LICENSE).
