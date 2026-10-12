# SQLite 3.22.0 as shipped in Android 10

`sqlite3.c` is the SQLite amalgamation that Android 10 (API 29, the app's
`minSdk`) builds into the system, unchanged:

- Source: `https://android.googlesource.com/platform/external/sqlite/+/refs/heads/android10-release/dist/sqlite3.c`
- `SQLITE_VERSION` `3.22.0`, `SQLITE_SOURCE_ID` `2018-12-19 01:30:22 c255889b…`
  (3.22.0 plus security fixes that Android backported)
- SHA-256 `69e8321a998779dc825ae688cb13b5d52a58c573acbefaa5a0341e0e259bdae6`

Tests only. The app never uses it: on a phone, sqflite talks to Android's own
SQLite. `pubspec.yaml` (`hooks: user_defines: sqlite3:`) makes the
`sqlite3` package compile this file for `flutter test` on Windows, so tests
run the same SQL engine as the oldest phone the app supports. What still
differs from a phone: see `AGENTS.md`.

The compile flags in `pubspec.yaml` are Android 10's
(`dist/Android.bp` on the same branch), minus the ones that only mean
something on Linux/Android and minus ICU (needs ICU libraries on Windows).

Android's changes in this file are all in the Unix VFS (`os_unix.c`), which
a Windows build doesn't compile. `.gitattributes` keeps the bytes exact
(no CRLF conversion), so the hash above still matches after a checkout.

SQLite is in the public domain: https://www.sqlite.org/copyright.html
