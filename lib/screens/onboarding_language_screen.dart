import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ransh_app/providers/ui_providers.dart';
import 'package:ransh_app/widgets/focusable_card.dart';

// Handles navigation logic or relies on app.dart watching the provider.

class OnboardingLanguageScreen extends ConsumerStatefulWidget {
  const OnboardingLanguageScreen({super.key});

  @override
  ConsumerState<OnboardingLanguageScreen> createState() =>
      _OnboardingLanguageScreenState();
}

class _OnboardingLanguageScreenState
    extends ConsumerState<OnboardingLanguageScreen> {
  String? _selectedCode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              // App Icon/Logo (Optional small)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.language,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              const Text(
                'Choose your Language\nभाषा चुनें',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Select the language for cartoons and stories',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 16),
              ),
              const SizedBox(height: 48),

              // Language Cards
              Expanded(
                child: ListView(
                  children: supportedLanguages.map((lang) {
                    final code = lang['code']!;
                    final isSelected = _selectedCode == code;

                    return FocusableCard(
                      onTap: () => setState(() => _selectedCode = code),
                      borderRadius: 16,
                      margin: const EdgeInsets.only(bottom: 16),
                      focusColor: Theme.of(context).colorScheme.secondary,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 20,
                          horizontal: 24,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.white.withOpacity(0.05),
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.secondary
                                : Colors.white12,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: isSelected
                                  ? Colors.white
                                  : Colors.white10,
                              radius: 24,
                              child: Text(
                                code.toUpperCase(),
                                style: TextStyle(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lang['nativeName']!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  lang['name']!,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white70
                                        : Colors.white38,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle,
                                color: Colors.white,
                                size: 28,
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 24),

              // Continue Button
              Center(
                child: FocusableCard(
                  onTap: _selectedCode != null ? _onContinue : null,
                  borderRadius: 30,
                  focusColor: Theme.of(context).colorScheme.secondary,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _selectedCode != null
                          ? Theme.of(context).colorScheme.secondary
                          : Colors.white10,
                    ),
                    child: Center(
                      child: Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _selectedCode != null
                              ? Colors.black
                              : Colors.white38,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _onContinue() async {
    if (_selectedCode == null) return;

    // Save language selection
    await ref
        .read(selectedLanguageProvider.notifier)
        .setLanguage(_selectedCode!);

    // Mark onboarding as complete (triggers navigation in app.dart)
    await ref.read(onboardingCompletedProvider.notifier).complete();
  }
}
