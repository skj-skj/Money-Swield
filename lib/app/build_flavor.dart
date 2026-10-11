import 'package:flutter/services.dart' show appFlavor;

import '../domain/models/app_flavor.dart';

/// This build's flavor. Outside the domain because it reads Flutter's
/// `appFlavor`; the rule itself is [AppFlavor.fromName].
AppFlavor get currentAppFlavor => AppFlavor.fromName(appFlavor);
