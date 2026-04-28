import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in main.dart');
});

class OnboardingNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool('onboardingComplete') ?? false;
  }

  void completeOnboarding() {
    state = true;
    ref.read(sharedPreferencesProvider).setBool('onboardingComplete', true);
  }

  void undoOnboarding() {
    state = false;
    ref.read(sharedPreferencesProvider).setBool('onboardingComplete', false);
  }
}

final onboardingProvider = NotifierProvider<OnboardingNotifier, bool>(OnboardingNotifier.new);
