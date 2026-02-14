import 'package:flutter/foundation.dart';

/// Service to provide high-visibility logs that stand out from system noise
class Logger {
  static const String _prefix = '⭐⭐⭐ [RANSH]';

  static void info(String message) {
    debugPrint('$_prefix INFO: $message');
  }

  static void success(String message) {
    debugPrint('$_prefix SUCCESS ✅: $message');
  }

  static void warning(String message) {
    debugPrint('$_prefix WARNING ⚠️: $message');
  }

  static void error(String message, [dynamic error, StackTrace? stack]) {
    debugPrint('$_prefix ERROR ❌: $message');
    if (error != null) debugPrint('$_prefix Details: $error');
    if (stack != null) debugPrint('$_prefix Stack: $stack');
  }
}
