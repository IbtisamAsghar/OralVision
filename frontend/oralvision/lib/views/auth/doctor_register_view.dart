import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../viewmodels/auth_viewmodel.dart';

class DoctorRegisterView extends ConsumerStatefulWidget {
  const DoctorRegisterView({super.key});

  @override
  ConsumerState<DoctorRegisterView> createState() => _DoctorRegisterViewState();
}

class _DoctorRegisterViewState extends ConsumerState<DoctorRegisterView> {
  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();

  int _currentStep = 0;

  // Security & Identity (Page 1)
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _ageController = TextEditingController();
  final _cityController = TextEditingController();
  
  final List<String> _pakistanCities = [
    'Islamabad', 'Karachi', 'Lahore', 'Rawalpindi', 'Faisalabad', 'Multan',
    'Hyderabad', 'Peshawar', 'Quetta', 'Sialkot', 'Gujranwala', 'Sargodha',
    'Bahawalpur', 'Sukkur', 'Larkana', 'Sheikhupura', 'Jhang', 'Gujrat',
    'Mardan', 'Kasur', 'Kahuta', 'Mingora', 'Nawabshah', 'Okara', 'Gilgit', 'Muzaffarabad'
  ];

  // Verification & Professional Info (Page 2)
  final _licenseController = TextEditingController();
  final _experienceController = TextEditingController();
  final _specializationInputController = TextEditingController();
  final List<String> _specializations = [];

  final List<String> _commonSpecializations = [
    'Orthodontics',
    'Endodontics',
    'Periodontics',
    'Prosthodontics',
    'Oral Surgery',
    'Pediatric Dentistry',
    'General Dentistry',
  ];

  // Clinic / Bio (Page 2)
  final _bioController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  int _passwordStrength = 0;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _ageController.dispose();
    _cityController.dispose();
    _licenseController.dispose();
    _experienceController.dispose();
    _specializationInputController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _checkPasswordStrength(String password) {
    int strength = 0;
    if (password.length >= 8) strength++;
    if (RegExp(r"(?=.*[A-Z])").hasMatch(password)) strength++;
    if (RegExp(r"(?=.*[0-9])").hasMatch(password)) strength++;
    if (RegExp(r"(?=.*[!@#\$&*~_])").hasMatch(password)) strength++;
    setState(() => _passwordStrength = strength);
  }

  void _addSpecialization() {
    final text = _specializationInputController.text.trim();
    if (text.isNotEmpty && !_specializations.contains(text)) {
      setState(() {
        _specializations.add(text);
        _specializationInputController.clear();
      });
    }
  }

  void _removeSpecialization(String spec) {
    setState(() => _specializations.remove(spec));
  }

  void _nextStep() {
    if (_formKey1.currentState!.validate()) {
      setState(() => _currentStep = 1);
    }
  }

  void _previousStep() {
    setState(() => _currentStep = 0);
  }

  void _register() {
    if (_formKey2.currentState!.validate()) {
      if (_specializations.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please add at least one specialization!'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      final joinedSpecializations = _specializations.join(', ');

      ref
          .read(authViewModelProvider.notifier)
          .signUpDoctor(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            fullName: _fullNameController.text.trim(),
            age: int.tryParse(_ageController.text) ?? 0,
            city: _cityController.text.trim(),
            phone: _phoneController.text.trim(),
            licenseNumber: _licenseController.text.trim(),
            yearsOfExperience: int.tryParse(_experienceController.text) ?? 0,
            specialization: joinedSpecializations,
            professionalBio: _bioController.text.trim(),
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
          onPressed: () {
            if (_currentStep == 1) {
              _previousStep();
            } else {
              context.go('/role-selection');
            }
          },
        ),
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        title: const Text(
          'Expert Registration',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: IndexedStack(
        index: _currentStep,
        children: [_buildPage1(), _buildPage2(authState)],
      ),
    );
  }

  // ==========================================
  // PAGE 1: SECURITY & IDENTITY
  // ==========================================
  Widget _buildPage1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Step 1 of 2 — Identity',
              style: TextStyle(
                color: AppColors.primaryTeal,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tell us who you are.',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),

            _buildSectionWrapper(
              title: 'Security & Identity',
              icon: Icons.person_outline,
              children: [
                _buildModernTextField(
                  label: 'Dr. Full Name',
                  controller: _fullNameController,
                  hint: 'Enter your formal name',
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Name is required' : null,
                ),
                _buildModernTextField(
                  label: 'Age',
                  controller: _ageController,
                  hint: 'e.g., 35',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Age is required' : null,
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'City',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          hintText: 'Select your city explicitly',
                        ),
                        menuMaxHeight: 300,
                        items: _pakistanCities.map((city) {
                          return DropdownMenuItem(value: city, child: Text(city));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            _cityController.text = val;
                          }
                        },
                        validator: (val) => val == null || val.isEmpty
                            ? 'City is required'
                            : null,
                      ),
                    ],
                  ),
                ),
                _buildModernTextField(
                  label: 'Personal Phone Number',
                  controller: _phoneController,
                  hint: '+92 300 1234567',
                  keyboardType: TextInputType.phone,
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Phone is required';
                    if (!RegExp(
                      r"^(\+92|0)?3\d{9}$",
                    ).hasMatch(val.replaceAll(' ', ''))) {
                      return 'Enter a valid Pakistani phone number';
                    }
                    return null;
                  },
                ),
                _buildModernTextField(
                  label: 'Professional Email',
                  controller: _emailController,
                  hint: 'doctor@clinic.com',
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Email is required';
                    final email = val.toLowerCase().trim();
                    if (!RegExp(
                      r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$",
                    ).hasMatch(email)) {
                      return 'Please enter a structurally valid email';
                    }
                    if (email.endsWith('@gmail.co') ||
                        email.endsWith('@gmail.c') ||
                        email.endsWith('@gmai.com')) {
                      return 'Invalid domain. Did you mean @gmail.com?';
                    }
                    return null;
                  },
                ),
                const Text(
                  'Secure Password',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
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
                    if (val == null || val.isEmpty)
                      return 'Password is required';
                    if (_passwordStrength < 3)
                      return 'Password fails industry standard check';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _buildPasswordStrengthIndicator(),
                const SizedBox(height: 24),

                const Text(
                  'Confirm Password',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    hintText: 'Repeat carefully',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () => setState(
                        () =>
                            _obscureConfirmPassword = !_obscureConfirmPassword,
                      ),
                    ),
                  ),
                  validator: (val) => val != _passwordController.text
                      ? 'Passwords do not match'
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 48),

            Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: AppColors.primaryGradient,
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadowMedium,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Next Step',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: GestureDetector(
                onTap: () => context.go('/login'),
                child: RichText(
                  text: const TextSpan(
                    text: "Already verified? ",
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
            const SizedBox(height: 64),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // PAGE 2: PROFESSIONAL & CLINIC CONFIGURATION
  // ==========================================
  Widget _buildPage2(AuthState authState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Step 2 of 2 — Verification',
              style: TextStyle(
                color: AppColors.primaryTeal,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Map your expertise.',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),

            _buildSectionWrapper(
              title: 'Professional Records',
              icon: Icons.verified_user_outlined,
              children: [
                _buildModernTextField(
                  label: 'Medical License / CNIC Number',
                  controller: _licenseController,
                  hint: 'e.g., 12345-PMDC',
                  validator: (val) =>
                      val == null || val.isEmpty ? 'License is required' : null,
                ),
                _buildModernTextField(
                  label: 'Years of Experience',
                  controller: _experienceController,
                  hint: 'e.g., 5',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (val) => val == null || val.isEmpty
                      ? 'Experience limit strictly digits'
                      : null,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Areas of Specialization',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),

                if (_specializations.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: _specializations
                          .map(
                            (spec) => Chip(
                              label: Text(
                                spec,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              backgroundColor: AppColors.primaryTeal,
                              deleteIconColor: Colors.white,
                              onDeleted: () => _removeSpecialization(spec),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),

                const Text(
                  'Tap to add typical specialities:',
                  style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: _commonSpecializations
                      .where((s) => !_specializations.contains(s))
                      .map(
                        (spec) => ActionChip(
                          label: Text(
                            spec,
                            style: const TextStyle(
                              color: AppColors.primaryTeal,
                            ),
                          ),
                          backgroundColor: AppColors.primaryTeal.withOpacity(
                            0.1,
                          ),
                          side: BorderSide.none,
                          onPressed: () =>
                              setState(() => _specializations.add(spec)),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _specializationInputController,
                        decoration: const InputDecoration(
                          hintText: 'Or type custom specification...',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onFieldSubmitted: (_) => _addSpecialization(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: const BoxDecoration(
                        color: AppColors.successLight,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.add, color: AppColors.success),
                        onPressed: _addSpecialization,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),

            _buildSectionWrapper(
              title: 'Clinic Configuration',
              icon: Icons.local_hospital_outlined,
              children: [
                const Text(
                  'Professional Bio',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _bioController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText:
                        'Briefly describe your expertise, philosophy, and history to patients...',
                  ),
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Bio is required' : null,
                ),
              ],
            ),

            const SizedBox(height: 48),
            if (authState.isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _previousStep,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: const BorderSide(
                          color: AppColors.primaryTeal,
                          width: 2,
                        ),
                      ),
                      child: const Text(
                        'Back',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryTeal,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: AppColors.primaryGradient,
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.shadowMedium,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Submit Expert',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 64),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // SHARED UI COMPONENTS
  // ==========================================

  Widget _buildSectionWrapper({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight.withOpacity(0.5)),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowLow,
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primaryTeal, size: 28),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Divider(color: AppColors.borderLight),
          ),
          ...children,
        ],
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
