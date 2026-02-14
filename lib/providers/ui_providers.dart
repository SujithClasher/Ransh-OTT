import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Supported languages
const List<Map<String, String>> supportedLanguages = [
  {'code': 'en', 'name': 'English', 'nativeName': 'English'},
  {'code': 'hi', 'name': 'Hindi', 'nativeName': 'हिंदी'},
  {'code': 'mr', 'name': 'Marathi', 'nativeName': 'मराठी'},
];

/// Supported categories for chips
const List<String> contentCategories = ['All', 'Cartoon', 'Rhymes', 'Stories'];

/// Provider for SharedPreferences (Overridden in main.dart)
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences not initialized');
});

/// StateNotifier for Language Selection with Persistence
class LanguageNotifier extends StateNotifier<String> {
  final SharedPreferences _prefs;

  LanguageNotifier(this._prefs)
    : super(_prefs.getString('selected_language') ?? 'en');

  Future<void> setLanguage(String code) async {
    state = code;
    await _prefs.setString('selected_language', code);
  }
}

/// Provider for the currently selected language
final selectedLanguageProvider =
    StateNotifierProvider<LanguageNotifier, String>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return LanguageNotifier(prefs);
    });

/// StateNotifier for Onboarding Status
class OnboardingNotifier extends StateNotifier<bool> {
  final SharedPreferences _prefs;
  OnboardingNotifier(this._prefs)
    : super(_prefs.getBool('is_language_onboarding_completed') ?? false);

  Future<void> complete() async {
    state = true;
    await _prefs.setBool('is_language_onboarding_completed', true);
  }
}

/// Provider to check/update if language onboarding is completed
final onboardingCompletedProvider =
    StateNotifierProvider<OnboardingNotifier, bool>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return OnboardingNotifier(prefs);
    });

/// Provider for the currently selected category
/// Defaults to 'All'
final selectedCategoryProvider = StateProvider<String>((ref) => 'All');
