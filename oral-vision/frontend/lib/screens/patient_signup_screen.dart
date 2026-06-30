import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/colors.dart';
import '../utils/validators.dart';

class PatientSignupScreen extends StatefulWidget {
  const PatientSignupScreen({super.key});

  @override
  State<PatientSignupScreen> createState() => _PatientSignupScreenState();
}

class _PatientSignupScreenState extends State<PatientSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  String? _error;
  String _gender = 'male';

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        data: {
          'full_name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'gender': _gender,
          'age': int.parse(_ageController.text),
          'role': 'patient',
        },
      );
      if (response.user != null) {
        try {
          await Supabase.instance.client.from('profiles').upsert({
            'id': response.user!.id,
            'email': _emailController.text.trim(),
            'full_name': _nameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'gender': _gender,
            'age': int.parse(_ageController.text),
            'role': 'patient',
          });
        } catch (e) {
          if (!mounted) return;
          setState(() {
            _error = 'Account created but profile save failed: $e. Try logging in or contact support.';
          });
          return;
        }
      }
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.email, color: AppColors.patient),
            SizedBox(width: 8),
            Text('Check Your Email!', style: TextStyle(color: AppColors.patient, fontSize: 18)),
          ]),
          content: const Text('We sent a confirmation link to your email.\n\nPlease confirm your email before logging in.'),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.patient,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushReplacementNamed(context, '/patient-login');
              },
              child: const Text('Go to Login', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() { _error = 'Signup failed: ${e.toString()}'; });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Widget _buildTermsText() {
    return const Text(
      'By signing up, you agree to our Terms of Service and Privacy Policy.',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 12, color: AppColors.textLight),
    );
  }

  Widget _buildField(String label, TextEditingController controller,
      IconData icon, String? Function(String?) validator,
      {TextInputType type = TextInputType.text}) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.patient),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.patient, width: 2)),
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
            colors: [Color(0xFFE0F7FA), Color(0xFFB2EBF2), Colors.white],
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
                  Image.asset('assets/images/logo.png', width: 80, height: 80),
                  const SizedBox(height: 12),
                  const Text('Create Patient Account',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                  const SizedBox(height: 24),
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.error),
                      ),
                      child: Text(_error!, style: const TextStyle(color: AppColors.error)),
                    ),
                  _buildField('Full Name', _nameController, Icons.person, AppValidators.validateName),
                  const SizedBox(height: 14),
                  _buildField('Email', _emailController, Icons.email, AppValidators.validateEmail, type: TextInputType.emailAddress),
                  const SizedBox(height: 14),
                  _buildField('Phone (+92XXXXXXXXXX)', _phoneController, Icons.phone, AppValidators.validatePhone, type: TextInputType.phone),
                  const SizedBox(height: 14),
                  _buildField('Age', _ageController, Icons.cake, AppValidators.validateAge, type: TextInputType.number),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: _gender,
                    decoration: InputDecoration(
                      labelText: 'Gender',
                      prefixIcon: const Icon(Icons.people, color: AppColors.patient),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                    items: ['male', 'female', 'other']
                        .map((g) => DropdownMenuItem(value: g, child: Text(g[0].toUpperCase() + g.substring(1))))
                        .toList(),
                    onChanged: (v) => setState(() => _gender = v!),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_showPassword,
                    onChanged: (v) => setState(() {}),
                    validator: AppValidators.validatePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock, color: AppColors.patient),
                      suffixIcon: IconButton(
                        icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility, color: AppColors.patient),
                        onPressed: () => setState(() => _showPassword = !_showPassword),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_passwordController.text.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.lightBlue),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Password must have:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textDark)),
                          const SizedBox(height: 6),
                          _PasswordCheck('Minimum 8 characters', _passwordController.text.length >= 8),
                          _PasswordCheck('Uppercase letter (A-Z)', _passwordController.text.contains(RegExp(r'[A-Z]'))),
                          _PasswordCheck('Lowercase letter (a-z)', _passwordController.text.contains(RegExp(r'[a-z]'))),
                          _PasswordCheck('Number (0-9)', _passwordController.text.contains(RegExp(r'[0-9]'))),
                          _PasswordCheck('Special character (!@#\$%^&*)', _passwordController.text.contains(RegExp(r'[!@#$%^&*]'))),
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: !_showConfirmPassword,
                    validator: (v) => AppValidators.validateConfirmPassword(v, _passwordController.text),
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: const Icon(Icons.lock_outline, color: AppColors.patient),
                      suffixIcon: IconButton(
                        icon: Icon(_showConfirmPassword ? Icons.visibility_off : Icons.visibility, color: AppColors.patient),
                        onPressed: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildTermsText(),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _signup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.patient,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Create Account', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Already have an account? '),
                      GestureDetector(
                        onTap: () => Navigator.pushReplacementNamed(context, '/patient-login'),
                        child: const Text('Login', style: TextStyle(color: AppColors.patient, fontWeight: FontWeight.bold)),
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