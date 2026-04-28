import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../viewmodels/auth_viewmodel.dart';

class PatientRegisterView extends ConsumerStatefulWidget {
  const PatientRegisterView({super.key});

  @override
  ConsumerState<PatientRegisterView> createState() =>
      _PatientRegisterViewState();
}

class _PatientRegisterViewState extends ConsumerState<PatientRegisterView> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _cityController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  int _passwordStrength = 0;

  @override
  void dispose() {
    _fullNameController.dispose();
    _ageController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _checkPasswordStrength(String password) {
    int strength = 0;
    if (password.length >= 8) strength++;
    if (RegExp(r"(?=.*[A-Z])").hasMatch(password)) strength++;
    if (RegExp(r"(?=.*[0-9])").hasMatch(password)) strength++;
    if (RegExp(r"(?=.*[!@#\$&*~_])").hasMatch(password)) strength++;
    setState(() {
      _passwordStrength = strength;
    });
  }

  void _register() {
    if (_formKey.currentState!.validate()) {
      ref
          .read(authViewModelProvider.notifier)
          .signUpPatient(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            fullName: _fullNameController.text.trim(),
            age: int.tryParse(_ageController.text) ?? 0,
            city: _cityController.text.trim(),
            phone: _phoneController.text.trim(),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authViewModelProvider, (previous, next) {
      if (next.error != null && next.error!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: next.error!.startsWith('Success')
                ? Colors.green
                : Colors.redAccent,
          ),
        );
      }
    });

    final authState = ref.watch(authViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.go('/role-selection'),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Patient Registration',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Personal Information Required',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 32),

              _buildModernTextField(
                label: 'Full Name',
                controller: _fullNameController,
                hint: 'Enter Name',
                validator: (val) =>
                    val == null || val.isEmpty ? 'Full Name is required' : null,
              ),
              _buildModernTextField(
                label: 'Age',
                controller: _ageController,
                hint: 'Enter age',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (val) =>
                    val == null || val.isEmpty ? 'Age is required' : null,
              ),
              _buildModernTextField(
                label: 'City',
                controller: _cityController,
                hint: 'Enter city',
                validator: (val) =>
                    val == null || val.isEmpty ? 'City is required' : null,
              ),
              _buildModernTextField(
                label: 'Phone Number',
                controller: _phoneController,
                hint: '+92 300 1234567',
                keyboardType: TextInputType.phone,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Phone is required';
                  if (!RegExp(
                    r"^(\+92|0)?3\d{9}$",
                  ).hasMatch(val.replaceAll(' ', ''))) {
                    return 'Enter a valid Pakistani phone number (e.g. +92300...)';
                  }
                  return null;
                },
              ),
              _buildModernTextField(
                label: 'Email',
                controller: _emailController,
                hint: 'john@example.com',
                keyboardType: TextInputType.emailAddress,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Email is required';
                  final email = val.toLowerCase().trim();

                  // 1. Core structural regex (Validates presence of @ and minimum 2 char TLD)
                  if (!RegExp(
                    r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$",
                  ).hasMatch(email)) {
                    return 'Please enter a structurally valid email (e.g., name@gmail.com)';
                  }

                  // 2. Advanced Typo Catching for common provider extensions
                  if (email.endsWith('@gmail.co') ||
                      email.endsWith('@gmail.c') ||
                      email.endsWith('@gmail.con')) {
                    return 'Invalid domain. Did you mean @gmail.com?';
                  }
                  if (email.endsWith('@gmai.com') ||
                      email.endsWith('@gamil.com') ||
                      email.endsWith('@gmaill.com')) {
                    return 'Invalid provider. Did you mean @gmail.com?';
                  }
                  if (email.endsWith('@hotmail.co') ||
                      email.endsWith('@yahoo.co')) {
                    return 'Check your domain spelling (e.g., .com)';
                  }

                  return null;
                },
              ),

              const Text(
                'Password',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                onChanged: _checkPasswordStrength,
                decoration: InputDecoration(
                  hintText: 'Enter robust password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Password is required';
                  if (_passwordStrength < 3) {
                    return 'Password fails industry standard check';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _buildPasswordStrengthIndicator(),
              const SizedBox(height: 24),

              const Text(
                'Confirm Password',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                decoration: InputDecoration(
                  hintText: 'Refill carefully',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () => setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword,
                    ),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Confirm your password';
                  }
                  if (val != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 48),
              if (authState.isLoading)
                const Center(child: CircularProgressIndicator())
              else
                ElevatedButton(
                  onPressed: _register,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Create Account'),
                ),
              const SizedBox(height: 24),

              // Rich Text Navigation applied below the button
              Center(
                child: GestureDetector(
                  onTap: () => context.go('/login'),
                  child: RichText(
                    text: const TextSpan(
                      text: "Already have an account? ",
                      style: TextStyle(color: AppColors.textSecondary),
                      children: [
                        TextSpan(
                          text: "Login",
                          style: TextStyle(
                            color: AppColors.primaryTeal,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            validator: validator,
            decoration: InputDecoration(hintText: hint),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordStrengthIndicator() {
    Color getStrengthColor() {
      if (_passwordStrength == 0) return AppColors.borderLight;
      if (_passwordStrength == 1) return AppColors.error;
      if (_passwordStrength == 2) return AppColors.warning;
      if (_passwordStrength >= 3) return AppColors.success;
      return AppColors.borderLight;
    }

    String getStrengthText() {
      if (_passwordStrength == 0) return 'Very Weak';
      if (_passwordStrength == 1) return 'Weak';
      if (_passwordStrength == 2) return 'Fair';
      if (_passwordStrength >= 3) return 'Strong';
      return 'Very Weak';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(4, (index) {
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: EdgeInsets.only(right: index == 3 ? 0 : 4),
                height: 4,
                decoration: BoxDecoration(
                  color: index < _passwordStrength
                      ? getStrengthColor()
                      : AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Text(
          getStrengthText(),
          style: TextStyle(
            color: getStrengthColor(),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
