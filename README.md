# Glass Files

A compact, local-first Android file manager built with Flutter and Material 3. It uses a top toolbar and drawer, not bottom navigation. This repository is an early functional foundation, **not** the complete feature set of a mature file manager.

## Implemented

- Browse real shared-storage paths with back/forward and parent navigation, quick folders, list/grid views, sorting, hidden files, refresh and persistent bookmarks.
- Request optional Android all-files access with an explanation; alternatively select a document tree through the system picker. Tree permissions are persisted; tree browsing, opening and sharing are supported, but tree mutation and searching are not.
- Create, rename, delete (with confirmation), select, copy, cut, paste, share and inspect local files. Transfers are streamed, refuse collisions and verify file hashes before deleting moved sources. Work runs on a native worker. Errors may leave earlier completed outputs in place.
- ZIP creation, entry listing, and extraction with path traversal checks, a 10,000-entry and 1 GiB expanded-size limit, and no overwrite. Extraction stops on conflict; entries already extracted remain.
- Configurable extension rules with priority, optional MIME and Android chooser or local UTF-8 text editor. Text editor limits files to 2 MiB and detects external changes before saving. Android chooses compatible apps, using temporary URI grants.
- Recursive folder search by filename substring, extension and minimum size, with hidden/case options, cancellation, an accessible-coverage count and a 100,000-entry cap.
- Persistent theme, accent, glass intensity, density, icon size, language, sorting and bookmarks; versioned settings clipboard import/export. English and Czech are supported for main controls (some platform and error messages remain untranslated).

## Requirements and build

Install a current stable Flutter SDK (Dart 3.6 or newer), Android SDK API 35, JDK 17 and Android build tools. From the repository root:

```sh
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
```

The debug APK, if built, is `build/app/outputs/flutter-apk/app-debug.apk`. Open the repository in Android Studio with Flutter/Dart plugins installed. The Gradle wrapper downloads its distribution on first build. No screenshots are included; capture them on a device after granting the desired storage access.

## Android storage and privacy

Android 10 (API 29) is the minimum. On Android 11+ the optional `MANAGE_EXTERNAL_STORAGE` permission enables a legitimate file-management use case; Google Play applies strict policy review to this permission. On Android 10 legacy storage permissions are requested. Denial is supported: choose a system folder instead. Android may deny access to `Android/data`, `Android/obb`, protected directories, removable devices, or individual document trees regardless of permission. The app does not bypass platform restrictions. FileProvider grants only temporary read permissions to receiving apps. There is no analytics or network backend.

## Important limitations

SAF trees are read-only in the UI. Removable storage discovery, file-operation conflict choices, cancellation/progress, resumable jobs, per-file history, trash, comprehensive metadata, thumbnails, dual-pane, batch rename, media/PDF viewers, archive formats other than ZIP, remote storage, secure credentials, profiles, full accessibility audit, and full localization are **not implemented**. External apps can handle formats not supported by the text editor. No network provider is offered; therefore there is no remote setup. File rules currently match extensions only; selecting a specific permanent external app, MIME matching, glob/regex, import/export of rules alone, and app discovery are not implemented. Settings export contains no credentials (the app stores none).

Transfer/extraction failures can leave partial results; inspect the destination before retrying. No files are intentionally overwritten during copy or ZIP extraction. The text editor replaces the original after an external-change check, but concurrent changes can still race that check. Symlinks are skipped during listing and rejected during copying. FileManager operations are not a substitute for backups.

See [architecture notes](docs/architecture.md) for extension points and security constraints. Tests in `test/` cover rules, settings serialization, sorting and local file operations; device-level Android permission and URI behavior requires real-device testing.
