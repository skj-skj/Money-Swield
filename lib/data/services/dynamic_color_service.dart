import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';

/// Reads the wallpaper's accent color from Android 12+ ("Material You"),
/// through the `expense_tracker/dynamic_color` channel in `MainActivity`.
class DynamicColorService {
  const DynamicColorService();

  static const _channel = MethodChannel('expense_tracker/dynamic_color');

  /// The accent color as ARGB, or null when the device has none (before
  /// Android 12) or it can't be read. The app then uses its default color.
  Future<int?> accentColor() async {
    try {
      return await _channel.invokeMethod<int>('accentColor');
    } on MissingPluginException {
      // Tests and non-Android hosts have no channel.
      return null;
    } on PlatformException catch (error) {
      debugPrint('Reading the wallpaper color failed: $error');
      return null;
    }
  }
}
