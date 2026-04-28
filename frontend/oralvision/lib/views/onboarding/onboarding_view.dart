import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/providers/preferences_provider.dart';

class OnboardingView extends ConsumerStatefulWidget {
  const OnboardingView({super.key});

  @override
  ConsumerState<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends ConsumerState<OnboardingView> {
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    // Trigger smooth fade-in animation slightly after frame mount
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _isVisible = true);
    });
  }

  void _finishOnboarding() {
    // Once completed, record permanently and utilize pure URL transitions
    ref.read(onboardingProvider.notifier).completeOnboarding();
    context.go('/role-selection');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Dynamic gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.3),
                radius: 1.2,
                colors: [AppColors.chatbotBg, AppColors.backgroundPrimary],
              ),
            ),
          ),
          SafeArea(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              opacity: _isVisible ? 1.0 : 0.0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Spacer(),
                    
                    // Abstract Interactive Logo Area
                    Container(
                      padding: const EdgeInsets.all(36),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWhite,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryTeal.withOpacity(0.25),
                            blurRadius: 40,
                            offset: const Offset(0, 15),
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.psychology_outlined,
                        size: 90,
                        color: AppColors.primaryTeal,
                      ),
                    ),
                    
                    const SizedBox(height: 56),
                    
                    // Primary Flagship Title
                    const Text(
                      'OralVision',
                      style: TextStyle(
                        fontSize: 46,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Tagline
                    const Text(
                      'Smarter Dental Diagnosis.\nPowered by AI.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryTeal,
                        height: 1.3,
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Subtitle Content
                    const Text(
                      'Connect securely with certified dental experts, rapidly analyze oral imagery, and manage your health seamlessly.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                        height: 1.6,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Glowing Action Button
                    Container(
                      width: double.infinity,
                      height: 64,
                      margin: const EdgeInsets.only(bottom: 48),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: AppColors.primaryGradient,
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.shadowMedium,
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _finishOnboarding,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Get Started',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(width: 12),
                            Icon(Icons.arrow_forward_rounded, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
