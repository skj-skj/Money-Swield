/// Which build this is (phase-9a.md §6.6, P9a-24): **foss** (no
/// closed-source code; F-Droid, the FOSS APK) or **play** (Google Play).
/// In 9a they differ only in play's `-PnoSms` switch; 9b adds the AI.
enum AppFlavor {
  foss,
  play;

  /// From Flutter's `appFlavor` (set by `--flavor`; `default-flavor: foss`
  /// in pubspec.yaml), read by `currentAppFlavor`. Anything but `play` is
  /// foss: null in tests, and a misspelt flavor never turns on play-only
  /// code.
  static AppFlavor fromName(String? name) => name == 'play' ? play : foss;
}
