import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Device type classification
enum DeviceType { mobile, tablet, tv }

/// Service to detect the current device type (Mobile, Tablet, or TV)
class DeviceTypeService {
  static DeviceTypeService? _instance;
  DeviceType? _cachedDeviceType;
  bool? _isLeanbackDevice;

  DeviceTypeService._();

  static DeviceTypeService get instance {
    _instance ??= DeviceTypeService._();
    return _instance!;
  }

  /// Check if running on Android TV (Leanback device)
  Future<bool> isAndroidTV() async {
    if (_isLeanbackDevice != null) return _isLeanbackDevice!;

    if (!Platform.isAndroid) {
      _isLeanbackDevice = false;
      return false;
    }

    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;

      // Check for Leanback feature (Android TV)
      _isLeanbackDevice = androidInfo.systemFeatures.contains(
        'android.software.leanback',
      );
      return _isLeanbackDevice!;
    } catch (e) {
      debugPrint('Error detecting Leanback: $e');
      _isLeanbackDevice = false;
      return false;
    }
  }

  /// Determine if device is a tablet based on screen size
  /// Uses the shortestSide >= 600dp heuristic
  bool isTablet(BuildContext context) {
    final data = MediaQuery.of(context);
    return data.size.shortestSide >= 600;
  }

  /// Get the current device type
  /// Must be called with BuildContext for accurate tablet detection
  Future<DeviceType> getDeviceType(BuildContext context) async {
    if (_cachedDeviceType != null) return _cachedDeviceType!;

    // First check if it's an Android TV
    final isTV = await isAndroidTV();
    if (isTV) {
      _cachedDeviceType = DeviceType.tv;
      return DeviceType.tv;
    }

    // Check if it's a tablet
    if (isTablet(context)) {
      _cachedDeviceType = DeviceType.tablet;
      return DeviceType.tablet;
    }

    // Default to mobile
    _cachedDeviceType = DeviceType.mobile;
    return DeviceType.mobile;
  }

  /// Get device type synchronously (use cached value)
  /// Returns null if not yet determined
  DeviceType? getCachedDeviceType() => _cachedDeviceType;

  /// Check if current device is TV (cached)
  bool get isTV => _cachedDeviceType == DeviceType.tv;

  /// Check if current device is Mobile (cached)
  bool get isMobile => _cachedDeviceType == DeviceType.mobile;

  /// Check if device allows touch input
  bool get supportsTouchInput => _cachedDeviceType != DeviceType.tv;

  /// Get grid column count based on device type
  int getGridColumns(BuildContext context) {
    switch (_cachedDeviceType) {
      case DeviceType.tv:
        return 5; // Horizontal carousel style
      case DeviceType.tablet:
        final isLandscape =
            MediaQuery.of(context).orientation == Orientation.landscape;
        return isLandscape ? 4 : 3;
      case DeviceType.mobile:
      default:
        final isLandscape =
            MediaQuery.of(context).orientation == Orientation.landscape;
        return isLandscape ? 2 : 1;
    }
  }

  /// Get appropriate padding based on device type
  EdgeInsets getContentPadding(BuildContext context) {
    switch (_cachedDeviceType) {
      case DeviceType.tv:
        return const EdgeInsets.symmetric(horizontal: 48, vertical: 24);
      case DeviceType.tablet:
        return const EdgeInsets.symmetric(horizontal: 32, vertical: 16);
      case DeviceType.mobile:
      default:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
    }
  }

  /// Clear cached values (useful for testing)
  void clearCache() {
    _cachedDeviceType = null;
    _isLeanbackDevice = null;
  }
}

/// Riverpod provider for device type
final deviceTypeServiceProvider = Provider<DeviceTypeService>((ref) {
  return DeviceTypeService.instance;
});

/// Provider that holds the current device type (async)
final deviceTypeProvider = FutureProvider.family<DeviceType, BuildContext>((
  ref,
  context,
) async {
  final service = ref.watch(deviceTypeServiceProvider);
  return service.getDeviceType(context);
});
