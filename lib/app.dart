import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ransh_app/providers/auth_provider.dart';
import 'package:ransh_app/screens/home_screen.dart';
import 'package:ransh_app/screens/login_screen.dart';
import 'package:ransh_app/screens/splash_screen.dart';
import 'package:ransh_app/screens/onboarding_language_screen.dart';
import 'package:ransh_app/providers/ui_providers.dart';
import 'package:ransh_app/services/device_type_service.dart' show DeviceType;

/// Root widget for the Ransh app
class RanshApp extends ConsumerStatefulWidget {
  const RanshApp({super.key});

  @override
  ConsumerState<RanshApp> createState() => _RanshAppState();
}

class _RanshAppState extends ConsumerState<RanshApp> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Initialize services
    await ref.read(appInitializationProvider.future);

    // Set up session termination handler
    final sessionSentinel = ref.read(sessionSentinelProvider);
    sessionSentinel.onSessionTerminated = (reason) {
      _showForceLogoutDialog(reason);
    };
  }

  void _showForceLogoutDialog(String reason) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Session Ended'),
        content: Text(reason),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(signOutProvider.future);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ransh',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFFFF9933), // Deep Saffron
          secondary: const Color(0xFFFFB703), // Amber Accent (Replaces Gold)
          surface: const Color(0xFF1A1A1A), // Elevated Surface
          background: Colors.black, // Deep Base
          onPrimary: Colors.black,
          onSecondary: Colors.black,
          onSurface: const Color(0xFFF5F5F5), // Vivid White
        ),
        scaffoldBackgroundColor: Colors.black, // Deep Base
        cardColor: const Color(0xFF1A1A1A), // Elevated Surface
        dialogBackgroundColor: const Color(0xFF1A1A1A), // Elevated Surface
        fontFamily: 'Roboto',
      ),
      home: const _AppRouter(),
      shortcuts: {
        ...WidgetsApp.defaultShortcuts,
        // Add TV remote shortcuts
        const SingleActivator(LogicalKeyboardKey.select):
            const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.gameButtonA):
            const ActivateIntent(),
      },
    );
  }
}

final splashCompletedProvider = StateProvider<bool>((ref) => false);

/// Router widget that handles auth state and navigation
class _AppRouter extends ConsumerWidget {
  const _AppRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final splashCompleted = ref.watch(splashCompletedProvider);

    if (!splashCompleted) {
      return SplashScreen(
        onFinished: () =>
            ref.read(splashCompletedProvider.notifier).state = true,
      );
    }

    final authState = ref.watch(authStateProvider);
    final initState = ref.watch(appInitializationProvider);

    // Show loading while initializing
    if (initState.isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 24),
              Text('Loading...', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );
    }

    // Show error if initialization failed
    if (initState.hasError) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text(
                'Initialization failed',
                style: TextStyle(color: Colors.red[300]),
              ),
            ],
          ),
        ),
      );
    }

    // Check for Onboarding
    final onboardingCompleted = ref.watch(onboardingCompletedProvider);
    if (!onboardingCompleted) {
      return const OnboardingLanguageScreen();
    }

    return authState.when(
      data: (user) {
        if (user != null) {
          // Initialize device type detection after login
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _detectDeviceType(context, ref);
          });
          return const HomeScreen();
        }
        return const LoginScreen();
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text(
                'Authentication error',
                style: TextStyle(color: Colors.red[300]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _detectDeviceType(BuildContext context, WidgetRef ref) async {
    final deviceTypeService = ref.read(deviceTypeServiceProvider);
    final deviceType = await deviceTypeService.getDeviceType(context);
    ref.read(deviceTypeStateProvider.notifier).state = deviceType;

    // Lock TV to landscape
    if (deviceType == DeviceType.tv) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }
}
