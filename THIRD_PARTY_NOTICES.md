# Third-party notices

This project bundles or depends on the following third-party components.

## Inter (font)

`assets/fonts/Inter-Variable.ttf` is the Inter typeface by The Inter Project
Authors, bundled with the app so it renders consistently without an internet
connection.

- Copyright 2020 The Inter Project Authors (<https://github.com/rsms/inter>)
- Licensed under the SIL Open Font License, Version 1.1
- Full license text: [`assets/fonts/OFL.txt`](assets/fonts/OFL.txt), also
  available at <https://scripts.sil.org/OFL>

## Dart / Flutter packages

RDB Viewer is built with the [Flutter](https://flutter.dev) SDK (BSD-3-Clause)
and the following packages (see `pubspec.yaml` for exact version
constraints; each is MIT or BSD-licensed - run `flutter pub deps` or check
the package's page on <https://pub.dev> for its full license text):

- [`provider`](https://pub.dev/packages/provider) - state management
- [`file_selector`](https://pub.dev/packages/file_selector) - native open/save
  file dialogs
- [`intl`](https://pub.dev/packages/intl) - internationalization utilities
- [`cupertino_icons`](https://pub.dev/packages/cupertino_icons) - default
  Flutter template dependency (iOS-style icons, not currently used in the UI)

None of the above are modified from their published versions.
