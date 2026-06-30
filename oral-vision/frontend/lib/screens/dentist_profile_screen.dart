import 'package:flutter/material.dart';
import '../utils/colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/navigation_utils.dart';
import '../widgets/app_card.dart';

class DentistProfileScreen extends StatefulWidget {
  const DentistProfileScreen({super.key});
  @override
  State<DentistProfileScreen> createState() => _DentistProfileScreenState();
}

class _DentistProfileScreenState extends State<DentistProfileScreen> {
  final _supabase = Supabase.instance.client;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _clinicController = TextEditingController();
  final _cityController = TextEditingController();
  final _experienceController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String _email = '';
  String _specialization = 'General Dentist';
  String _licenseNumber = '';

  final List<String> _specializations = [
    'General Dentist', 'Orthodontist', 'Periodontist', 'Endodontist',
    'Oral Surgeon', 'Pediatric Dentist', 'Prosthodontist',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _clinicController.dispose();
    _cityController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      final profile = await _supabase.from('profiles').select().eq('id', user.id).maybeSingle();
      Map<String, dynamic> dentist = {};
      try {
        final d = await _supabase.from('dentist_profiles').select().eq('user_id', user.id).maybeSingle();
        if (d != null) dentist = d;
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _nameController.text = profile?['full_name'] ?? '';
        _phoneController.text = profile?['phone'] ?? '';
        _email = profile?['email'] ?? user.email ?? '';
        _clinicController.text = dentist['clinic_name'] ?? '';
        _cityController.text = dentist['city'] ?? '';
        _experienceController.text = dentist['experience_years']?.toString() ?? '';
        _specialization = dentist['specialization'] ?? 'General Dentist';
        _licenseNumber = dentist['license_number'] ?? '';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      await _supabase.from('profiles').update({
        'full_name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
      }).eq('id', user.id);
      await _supabase.from('dentist_profiles').update({
        'clinic_name': _clinicController.text.trim(),
        'city': _cityController.text.trim(),
        'experience_years': int.tryParse(_experienceController.text) ?? 0,
        'specialization': _specialization,
      }).eq('user_id', user.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated!'), backgroundColor: AppColors.dentist));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _logout() async {
    showDialog(context: context, builder: (ctx) => AlertDialog(
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
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dentistBg,
      appBar: AppBar(
        backgroundColor: AppColors.dentistDark,
        automaticallyImplyLeading: false,
        title: const Text('Profile & Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.dentist))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                // Profile hero card
                _buildHeroCard(),
                const SizedBox(height: 20),
                // Edit Profile
                _buildEditSection(),
                const SizedBox(height: 16),
                // Documents
                _buildDocumentsSection(),
                const SizedBox(height: 16),
                // App settings
                _buildAppSettings(),
                const SizedBox(height: 16),
                // Logout
                SizedBox(
                  width: double.infinity, height: 50,
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
                const SizedBox(height: 100),
              ]),
            ),
    );
  }

  Widget _buildHeroCard() {
    final name = _nameController.text;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'D';
    final exp = _experienceController.text;
    final isVerified = _licenseNumber.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.dentistDark, AppColors.dentistAccent],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: AppColors.dentist.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(children: [
        Row(children: [
          Container(
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
            child: CircleAvatar(
              radius: 34,
              backgroundColor: Colors.white,
              child: Text(initial, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.dentistDark)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('My Profile', style: TextStyle(color: Colors.white70, fontSize: 12)),
            Text('Dr. ${name.isNotEmpty ? name : 'Dentist'}',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            Text(_specialization, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            Text(_email, style: const TextStyle(color: Colors.white54, fontSize: 11), overflow: TextOverflow.ellipsis),
          ])),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _heroBadge(exp.isNotEmpty ? '${exp}yr' : 'N/A', 'Experience', Icons.work),
            Container(width: 1, height: 36, color: Colors.white24),
            _heroBadge(_clinicController.text.isNotEmpty ? _clinicController.text : 'N/A', 'Clinic', Icons.local_hospital),
            Container(width: 1, height: 36, color: Colors.white24),
            _heroBadge(isVerified ? 'Verified' : 'Pending', 'PMDC', isVerified ? Icons.verified : Icons.pending_outlined),
          ]),
        ),
      ]),
    );
  }

  Widget _heroBadge(String value, String label, IconData icon) {
    return Column(children: [
      Icon(icon, color: Colors.white70, size: 16),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
    ]);
  }

  Widget _buildEditSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 10)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Edit Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
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
            fillColor: Colors.grey.withOpacity(0.1),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),
        _inputField(_phoneController, 'Phone', Icons.phone, type: TextInputType.phone),
        const SizedBox(height: 12),
        _inputField(_clinicController, 'Clinic Name', Icons.local_hospital),
        const SizedBox(height: 12),
        _inputField(_cityController, 'City', Icons.location_city),
        const SizedBox(height: 12),
        _inputField(_experienceController, 'Years of Experience', Icons.work, type: TextInputType.number),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _specialization,
          decoration: InputDecoration(
            labelText: 'Specialization',
            prefixIcon: const Icon(Icons.medical_services, color: AppColors.dentist),
            filled: true,
            fillColor: const Color(0xFFF8F9FA),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          items: _specializations.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (v) => setState(() => _specialization = v!),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity, height: 50,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dentist,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isSaving
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Save Changes', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }

  Widget _buildDocumentsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 8)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Documents & Verification', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
        const SizedBox(height: 12),
        _docRow('PMDC License',
            _licenseNumber.isNotEmpty ? 'Verified' : 'Pending',
            _licenseNumber.isNotEmpty ? Icons.verified : Icons.pending_outlined,
            _licenseNumber.isNotEmpty ? AppColors.riskLow : AppColors.riskMedium),
        const Divider(),
        _docRow('Degree Certificate', 'On file', Icons.school, AppColors.dentist),
      ]),
    );
  }

  Widget _buildAppSettings() {
    return Column(children: [
      AppCard(
        onTap: () {},
        child: const Row(children: [
          Icon(Icons.privacy_tip_outlined, color: AppColors.dentist),
          SizedBox(width: 12),
          Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.w600)),
          Spacer(),
          Icon(Icons.chevron_right, color: AppColors.textLight),
        ]),
      ),
      const SizedBox(height: 8),
      AppCard(
        onTap: () {},
        child: const Row(children: [
          Icon(Icons.description_outlined, color: AppColors.dentist),
          SizedBox(width: 12),
          Text('Terms of Service', style: TextStyle(fontWeight: FontWeight.w600)),
          Spacer(),
          Icon(Icons.chevron_right, color: AppColors.textLight),
        ]),
      ),
      const SizedBox(height: 8),
      AppCard(
        onTap: () {},
        child: const Row(children: [
          Icon(Icons.help_outline, color: AppColors.dentist),
          SizedBox(width: 12),
          Text('Help & Support', style: TextStyle(fontWeight: FontWeight.w600)),
          Spacer(),
          Icon(Icons.chevron_right, color: AppColors.textLight),
        ]),
      ),
    ]);
  }

  Widget _docRow(String title, String status, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w500))),
        Text(status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _inputField(TextEditingController controller, String label, IconData icon, {TextInputType type = TextInputType.text}) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.dentist),
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}
