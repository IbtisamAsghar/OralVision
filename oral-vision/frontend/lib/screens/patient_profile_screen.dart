import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/colors.dart';
import '../utils/health_utils.dart';
import '../utils/navigation_utils.dart';
import '../widgets/app_card.dart';

class PatientProfileScreen extends StatefulWidget {
  const PatientProfileScreen({super.key});

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  final _supabase = Supabase.instance.client;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();
  static const _genders = ['male', 'female', 'other'];

  bool _isLoading = true;
  bool _isSaving = false;
  String _email = '';
  String _gender = 'male';
  String? _error;
  int _scanCount = 0;
  int _symptomCount = 0;
  int _prescriptionCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  String _normalizeGender(dynamic value) {
    final g = (value ?? 'male').toString().toLowerCase();
    return _genders.contains(g) ? g : 'male';
  }

  Future<void> _loadProfile() async {
    setState(() { _isLoading = true; _error = null; });
    final user = _supabase.auth.currentUser;
    if (user == null) {
      setState(() { _error = 'Session expired.'; _isLoading = false; });
      return;
    }
    var profile = <String, dynamic>{'full_name': '', 'phone': '', 'gender': 'male', 'age': 0};
    try {
      final row = await _supabase.from('profiles').select('full_name, phone, age, gender').eq('id', user.id).maybeSingle();
      if (row != null) profile = Map<String, dynamic>.from(row);
    } catch (_) {}

    int scans = 0, symptoms = 0, prescriptions = 0;
    try {
      final r = await _supabase.from('scan_history').select('id').eq('user_id', user.id);
      scans = (r as List).length;
    } catch (_) {}
    try {
      final r = await _supabase.from('symptom_history').select('id').eq('user_id', user.id);
      symptoms = (r as List).length;
    } catch (_) {}
    try {
      final r = await _supabase.from('prescriptions').select('id').eq('patient_id', user.id);
      prescriptions = (r as List).length;
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _nameController.text = profile['full_name']?.toString() ?? '';
      _phoneController.text = profile['phone']?.toString() ?? '';
      _ageController.text = profile['age']?.toString() ?? '';
      _email = user.email ?? '';
      _gender = _normalizeGender(profile['gender']);
      _scanCount = scans;
      _symptomCount = symptoms;
      _prescriptionCount = prescriptions;
      _isLoading = false;
    });
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      await _supabase.from('profiles').update({
        'full_name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'age': int.tryParse(_ageController.text) ?? 0,
        'gender': _gender,
      }).eq('id', user.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated!'), backgroundColor: AppColors.patient),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout', style: TextStyle(color: AppColors.error)),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              await logoutAndGoToRole(context);
            },
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _inputField(TextEditingController controller, String label, IconData icon,
      {TextInputType type = TextInputType.text}) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.patientDark),
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.patientTint.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.patient, width: 1.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.patientBg,
      appBar: AppBar(
        backgroundColor: AppColors.patientDark,
        title: const Text('My Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.logout, color: Colors.white), onPressed: _logout),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.patient))
          : _error != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                  const SizedBox(height: 12),
                  Text(_error!),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _loadProfile,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.patient),
                      child: const Text('Retry', style: TextStyle(color: Colors.white))),
                ]))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    // ── Hero header with gradient ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00838F), Color(0xFF00E5FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: AppColors.patient.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
                      ),
                      child: Column(children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8)],
                          ),
                          child: CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.white,
                            child: Text(
                              _nameController.text.isNotEmpty ? _nameController.text[0].toUpperCase() : 'P',
                              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF00838F)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _nameController.text.isNotEmpty ? _nameController.text : 'Patient',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(_email, style: const TextStyle(fontSize: 13, color: Colors.white70)),
                        const SizedBox(height: 16),
                        // Stats row
                        Row(children: [
                          _heroStat('Scans', '$_scanCount', Icons.camera_alt),
                          _divider(),
                          _heroStat('Symptoms', '$_symptomCount', Icons.psychology),
                          _divider(),
                          _heroStat('Prescriptions', '$_prescriptionCount', Icons.medical_services),
                        ]),
                      ]),
                    ),
                    const SizedBox(height: 20),

                    // ── Edit profile card ──
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 10)],
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: AppColors.patientSurface, borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.edit, color: AppColors.patient, size: 18),
                          ),
                          const SizedBox(width: 10),
                          const Text('Edit Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                        ]),
                        const SizedBox(height: 16),
                        _inputField(_nameController, 'Full Name', Icons.person),
                        const SizedBox(height: 12),
                        TextFormField(
                          initialValue: _email,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'Email (cannot change)',
                            prefixIcon: const Icon(Icons.email, color: Colors.grey),
                            filled: true,
                            fillColor: Colors.grey.withOpacity(0.08),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _inputField(_phoneController, 'Phone', Icons.phone, type: TextInputType.phone),
                        const SizedBox(height: 12),
                        _inputField(_ageController, 'Age', Icons.cake, type: TextInputType.number),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _gender,
                          decoration: InputDecoration(
                            labelText: 'Gender',
                            prefixIcon: const Icon(Icons.people, color: AppColors.patientDark),
                            filled: true,
                            fillColor: const Color(0xFFF8F9FA),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                          items: _genders.map((g) => DropdownMenuItem(
                            value: g,
                            child: Text(g[0].toUpperCase() + g.substring(1)),
                          )).toList(),
                          onChanged: (v) => setState(() => _gender = v!),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.patientDark,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isSaving
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text('Save Changes', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 16),

                    // ── Quick links ──
                    AppCard(onTap: () {}, child: const Row(children: [
                      Icon(Icons.privacy_tip_outlined, color: AppColors.patient),
                      SizedBox(width: 12),
                      Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.w600)),
                      Spacer(),
                      Icon(Icons.chevron_right, color: AppColors.textLight),
                    ])),
                    const SizedBox(height: 8),
                    AppCard(onTap: () {}, child: const Row(children: [
                      Icon(Icons.description_outlined, color: AppColors.patient),
                      SizedBox(width: 12),
                      Text('Terms of Service', style: TextStyle(fontWeight: FontWeight.w600)),
                      Spacer(),
                      Icon(Icons.chevron_right, color: AppColors.textLight),
                    ])),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _logout,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.error),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.logout, color: AppColors.error),
                        label: const Text('Logout', style: TextStyle(color: AppColors.error, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ]),
                ),
    );
  }

  Widget _heroStat(String label, String value, IconData icon) {
    return Expanded(child: Column(children: [
      Icon(icon, color: Colors.white, size: 20),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
    ]));
  }

  Widget _divider() {
    return Container(width: 1, height: 40, color: Colors.white30);
  }
}
