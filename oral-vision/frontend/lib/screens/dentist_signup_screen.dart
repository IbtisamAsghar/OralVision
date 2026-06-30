import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../utils/colors.dart';
import '../utils/validators.dart';

class DentistSignupScreen extends StatefulWidget {
  const DentistSignupScreen({super.key});

  @override
  State<DentistSignupScreen> createState() => _DentistSignupScreenState();
}

class _DentistSignupScreenState extends State<DentistSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _licenseController = TextEditingController();
  final _clinicController = TextEditingController();
  final _cityController = TextEditingController();
  final _experienceController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  String? _error;
  String _specialization = 'General Dentist';
  File? _pmdcFile;
  File? _degreeFile;
  final _picker = ImagePicker();

  final List<String> _specializations = [
    'General Dentist',
    'Orthodontist',
    'Periodontist',
    'Endodontist',
    'Oral Surgeon',
    'Pediatric Dentist',
    'Prosthodontist',
  ];

  Future<void> _pickFile(String type) async {
    final picked = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() {
        if (type == 'pmdc') _pmdcFile = File(picked.path);
        if (type == 'degree') _degreeFile = File(picked.path);
      });
    }
  }

  Future<String?> _uploadFile(
      File file, String bucket, String userId, String name) async {
    try {
      final fileName = '$userId/$name.jpg';
      await Supabase.instance.client.storage
          .from(bucket)
          .upload(fileName, file);
      return Supabase.instance.client.storage
          .from(bucket)
          .getPublicUrl(fileName);
    } catch (_) {
      return null;
    }
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pmdcFile == null) {
      setState(() => _error = 'Please upload your PMDC License');
      return;
    }
    if (_degreeFile == null) {
      setState(() => _error = 'Please upload your Degree Certificate');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response =
          await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        data: {
          'full_name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'role': 'dentist',
        },
      );

      if (response.user != null) {
        final uid = response.user!.id;

        final pmdcUrl =
            await _uploadFile(_pmdcFile!, 'pmdc-licenses', uid, 'pmdc');
        final degreeUrl = await _uploadFile(
            _degreeFile!, 'degree-certificates', uid, 'degree');

        try {
          await Supabase.instance.client.from('profiles').upsert({
            'id': uid,
            'email': _emailController.text.trim(),
            'full_name': _nameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'role': 'dentist',
          });
        } catch (e) {
          if (!mounted) return;
          setState(() => _error = 'Profile save failed: $e');
          return;
        }

        try {
          await Supabase.instance.client
              .from('dentist_profiles')
              .insert({
            'user_id': uid,
            'clinic_name': _clinicController.text.trim(),
            'license_number': _licenseController.text.trim(),
            'specialization': _specialization,
            'city': _cityController.text.trim(),
            'experience_years': int.parse(_experienceController.text),
            'pmdc_url': pmdcUrl,
            'degree_url': degreeUrl,
          });
        } catch (e) {
          if (!mounted) return;
          setState(() => _error = 'Dentist profile save failed: $e');
          return;
        }
      }

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.email, color: AppColors.dentist),
            SizedBox(width: 8),
            Text('Check Your Email!',
                style:
                    TextStyle(color: AppColors.dentist, fontSize: 18)),
          ]),
          content: const Text(
            'We sent a confirmation link to your email.\n\nPlease confirm your email before logging in.\n\nYour documents are under review.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.dentist,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushReplacementNamed(
                    context, '/dentist-login');
              },
              child: const Text('Go to Login',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() {
        _error = 'Signup failed: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildTermsText() {
    return const Text(
      'By signing up, you agree to our Terms of Service and Privacy Policy.',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 12, color: AppColors.textLight),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller,
    IconData icon,
    String? Function(String?) validator, {
    TextInputType type = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.dentist),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: AppColors.dentist, width: 2)),
      ),
    );
  }

  Widget _buildUploadBox(String label, String type, File? file) {
    return GestureDetector(
      onTap: () => _pickFile(type),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: file != null
                ? AppColors.dentist
                : Colors.grey.shade300,
            width: file != null ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              file != null ? Icons.check_circle : Icons.upload_file,
              color: file != null ? AppColors.dentist : Colors.grey,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: file != null
                              ? AppColors.dentist
                              : Colors.grey.shade700)),
                  const SizedBox(height: 4),
                  Text(
                    file != null
                        ? 'File selected ✓'
                        : 'Tap to upload (JPG/PNG)',
                    style: TextStyle(
                        fontSize: 12,
                        color:
                            file != null ? Colors.green : Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF3E0),
              Color(0xFFFFE0B2),
              Colors.white
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Image.asset('assets/images/logo.png',
                      width: 80, height: 80),
                  const SizedBox(height: 12),
                  const Text('Dentist Registration',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A237E))),
                  const SizedBox(height: 24),
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.error),
                      ),
                      child: Text(_error!,
                          style: const TextStyle(
                              color: AppColors.error)),
                    ),
                  _buildField('Full Name', _nameController,
                      Icons.person, AppValidators.validateName),
                  const SizedBox(height: 14),
                  _buildField(
                      'Email',
                      _emailController,
                      Icons.email,
                      AppValidators.validateEmail,
                      type: TextInputType.emailAddress),
                  const SizedBox(height: 14),
                  _buildField(
                      'Phone (+92XXXXXXXXXX)',
                      _phoneController,
                      Icons.phone,
                      AppValidators.validatePhone,
                      type: TextInputType.phone),
                  const SizedBox(height: 14),
                  _buildField('License Number', _licenseController,
                      Icons.badge, (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'License number is required';
                    if (v.trim().length < 5)
                      return 'License must be at least 5 characters';
                    return null;
                  }),
                  const SizedBox(height: 14),
                  _buildField('Clinic Name', _clinicController,
                      Icons.local_hospital, (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'Clinic name is required';
                    if (v.trim().length < 3)
                      return 'Clinic name too short';
                    return null;
                  }),
                  const SizedBox(height: 14),
                  _buildField(
                      'City',
                      _cityController,
                      Icons.location_city,
                      (v) => v!.isEmpty ? 'City is required' : null),
                  const SizedBox(height: 14),
                  _buildField(
                      'Years of Experience',
                      _experienceController,
                      Icons.work,
                      (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (int.tryParse(v) == null)
                          return 'Enter a number';
                        return null;
                      },
                      type: TextInputType.number),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: _specialization,
                    decoration: InputDecoration(
                      labelText: 'Specialization',
                      prefixIcon: const Icon(Icons.medical_services,
                          color: AppColors.dentist),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none),
                    ),
                    items: _specializations
                        .map((s) =>
                            DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _specialization = v!),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border:
                          Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(children: [
                          Icon(Icons.verified,
                              color: AppColors.dentist),
                          SizedBox(width: 8),
                          Text('Verification Documents',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF1A237E))),
                        ]),
                        const SizedBox(height: 4),
                        const Text('Required for account verification',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 14),
                        _buildUploadBox(
                            'PMDC License', 'pmdc', _pmdcFile),
                        const SizedBox(height: 12),
                        _buildUploadBox('Degree Certificate (BDS)',
                            'degree', _degreeFile),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_showPassword,
                    onChanged: (v) => setState(() {}),
                    validator: AppValidators.validatePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock,
                          color: AppColors.dentist),
                      suffixIcon: IconButton(
                        icon: Icon(
                            _showPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: AppColors.dentist),
                        onPressed: () => setState(
                            () => _showPassword = !_showPassword),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_passwordController.text.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: AppColors.lightBlue),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Password must have:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppColors.textDark)),
                          const SizedBox(height: 6),
                          _PasswordCheck('Minimum 8 characters',
                              _passwordController.text.length >= 8),
                          _PasswordCheck(
                              'Uppercase letter (A-Z)',
                              _passwordController.text
                                  .contains(RegExp(r'[A-Z]'))),
                          _PasswordCheck(
                              'Lowercase letter (a-z)',
                              _passwordController.text
                                  .contains(RegExp(r'[a-z]'))),
                          _PasswordCheck(
                              'Number (0-9)',
                              _passwordController.text
                                  .contains(RegExp(r'[0-9]'))),
                          _PasswordCheck(
                              'Special character (!@#\$%^&*)',
                              _passwordController.text.contains(
                                  RegExp(r'[!@#$%^&*]'))),
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: !_showConfirmPassword,
                    validator: (v) =>
                        AppValidators.validateConfirmPassword(
                            v, _passwordController.text),
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: const Icon(Icons.lock_outline,
                          color: AppColors.dentist),
                      suffixIcon: IconButton(
                        icon: Icon(
                            _showConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: AppColors.dentist),
                        onPressed: () => setState(() =>
                            _showConfirmPassword =
                                !_showConfirmPassword),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildTermsText(),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _signup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.dentist,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(
                              color: Colors.white)
                          : const Text('Register',
                              style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Already have an account? '),
                      GestureDetector(
                        onTap: () => Navigator.pushReplacementNamed(
                            context, '/dentist-login'),
                        child: const Text('Login',
                            style: TextStyle(
                                color: AppColors.dentist,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordCheck extends StatelessWidget {
  final String label;
  final bool passed;
  const _PasswordCheck(this.label, this.passed);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(passed ? Icons.check_circle : Icons.cancel,
              color: passed ? Colors.green : Colors.red, size: 16),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: passed ? Colors.green : Colors.red)),
        ],
      ),
    );
  }
}