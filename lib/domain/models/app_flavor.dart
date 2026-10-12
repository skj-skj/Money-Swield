/// Which build this is: **foss** (no closed-source code; F-Droid, the FOSS APK)
/// or **play** (Google Play). They differ in play's `-PnoSms` switch and
/// play's on-device AI.
enum AppFlavor {
  foss,
  play;

  /// From Flutter's `appFlavor` (set by `--flavor`; `default-flavor: foss`
  /// in pubspec.yaml), read by `currentAppFlavor`. Anything but `play` is
  /// foss: null in tests, and a misspelt flavor never turns on play-only
  /// code.
  static AppFlavor fromName(String? name) => name == 'play' ? play : foss;
}
