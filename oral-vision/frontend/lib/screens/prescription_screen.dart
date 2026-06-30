import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/colors.dart';
import '../services/pdf_service.dart';

class PrescriptionScreen extends StatefulWidget {
  // Accept patient info passed from dentist patients screen
  final String? patientId;
  final String? patientName;

  const PrescriptionScreen({super.key, this.patientId, this.patientName});

  @override
  State<PrescriptionScreen> createState() => _PrescriptionScreenState();
}

class _PrescriptionScreenState extends State<PrescriptionScreen> {
  final _supabase = Supabase.instance.client;
  final _patientNameController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _medicationsController = TextEditingController();
  final _dosageController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _notesController = TextEditingController();

  List<Map<String, dynamic>> _prescriptions = [];
  List<Map<String, dynamic>> _patients = [];
  String? _selectedPatientId;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill patient info if passed from patient screen
    if (widget.patientId != null) {
      _selectedPatientId = widget.patientId;
    }
    if (widget.patientName != null) {
      _patientNameController.text = widget.patientName!;
    }
    _loadData();
  }

  @override
  void dispose() {
    _patientNameController.dispose();
    _diagnosisController.dispose();
    _medicationsController.dispose();
    _dosageController.dispose();
    _instructionsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Load patients from appointments
      final appointments = await _supabase
          .from('appointments')
          .select('patient_id')
          .eq('dentist_id', user.id);

      final patientIds = (appointments as List)
          .map((a) => a['patient_id'] as String)
          .toSet()
          .toList();

      List<Map<String, dynamic>> patients = [];
      if (patientIds.isNotEmpty) {
        final profiles = await _supabase
            .from('profiles')
            .select('id, full_name, phone')
            .inFilter('id', patientIds);
        patients = List<Map<String, dynamic>>.from(profiles);
      }

      List<Map<String, dynamic>> prescriptions = [];
      try {
        final data = await _supabase
            .from('prescriptions')
            .select()
            .eq('dentist_id', user.id)
            .order('created_at', ascending: false);
        prescriptions = List<Map<String, dynamic>>.from(data);
      } catch (_) {}

      setState(() {
        _patients = patients;
        _prescriptions = prescriptions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _savePrescription() async {
    if (_patientNameController.text.trim().isEmpty ||
        _diagnosisController.text.trim().isEmpty ||
        _medicationsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Patient name, diagnosis and medications are required'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final dentistProfile = await _supabase
          .from('profiles')
          .select('full_name')
          .eq('id', user.id)
          .maybeSingle();
      final dentistName = dentistProfile?['full_name']?.toString() ?? 'Dentist';

      // Try to find patient_id from profiles by name if not already selected
      String? finalPatientId = _selectedPatientId;
      if (finalPatientId == null && _patientNameController.text.trim().isNotEmpty) {
        try {
          final profile = await _supabase
              .from('profiles')
              .select('id')
              .eq('full_name', _patientNameController.text.trim())
              .maybeSingle();
          finalPatientId = profile?['id']?.toString();
        } catch (_) {}
      }

      final medicines = [
        {
          'name': _medicationsController.text.trim(),
          'dosage': _dosageController.text.trim(),
          'frequency': '',
          'duration': '',
          'instructions': _instructionsController.text.trim(),
        }
      ];

      await _supabase.from('prescriptions').insert({
        'dentist_id': user.id,
        'patient_id': finalPatientId,   // NOW PROPERLY SET
        'patient_name': _patientNameController.text.trim(),
        'dentist_name': dentistName,
        'diagnosis': _diagnosisController.text.trim(),
        'medications': _medicationsController.text.trim(),
        'medicines': medicines,
        'dosage': _dosageController.text.trim(),
        'instructions': _instructionsController.text.trim(),
        'note': _notesController.text.trim(),
        'notes': _notesController.text.trim(),
      });

      _patientNameController.clear();
      _diagnosisController.clear();
      _medicationsController.clear();
      _dosageController.clear();
      _instructionsController.clear();
      _notesController.clear();
      setState(() => _selectedPatientId = null);

      await _loadData();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prescription saved successfully!'),
          backgroundColor: AppColors.dentist,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.dentist),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: AppColors.dentist.withOpacity(0.08), blurRadius: 12)],
      ),
      child: Column(children: [
        if (_patients.isNotEmpty) ...[
          DropdownButtonFormField<String>(
            value: _selectedPatientId,
            decoration: _inputDecoration('Select Patient', Icons.person),
            items: _patients.map((p) => DropdownMenuItem(
              value: p['id'] as String,
              child: Text(p['full_name'] ?? 'Patient'),
            )).toList(),
            onChanged: (id) {
              setState(() {
                _selectedPatientId = id;
                if (id != null) {
                  final patient = _patients.firstWhere((p) => p['id'] == id);
                  _patientNameController.text = patient['full_name'] ?? '';
                }
              });
            },
          ),
          const SizedBox(height: 12),
        ],
        TextField(controller: _patientNameController, decoration: _inputDecoration('Patient Name *', Icons.badge)),
        const SizedBox(height: 12),
        TextField(controller: _diagnosisController, decoration: _inputDecoration('Diagnosis *', Icons.medical_information)),
        const SizedBox(height: 12),
        TextField(controller: _medicationsController, maxLines: 2, decoration: _inputDecoration('Medications *', Icons.medication_liquid)),
        const SizedBox(height: 12),
        TextField(controller: _dosageController, decoration: _inputDecoration('Dosage', Icons.schedule)),
        const SizedBox(height: 12),
        TextField(controller: _instructionsController, maxLines: 3, decoration: _inputDecoration('Instructions', Icons.notes)),
        const SizedBox(height: 12),
        TextField(controller: _notesController, maxLines: 2, decoration: _inputDecoration('Additional Notes', Icons.note_alt)),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity, height: 50,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _savePrescription,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dentistDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isSaving
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Save Prescription', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: AppColors.dentistDark,
        title: const Text('Write Prescription', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.dentistDark, AppColors.dentistAccent]),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Row(children: [
                    Icon(Icons.medication, color: Colors.white, size: 32),
                    SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Digital Prescription', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Create and manage patient prescriptions', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ])),
                  ]),
                ),
                const SizedBox(height: 20),
                _buildFormCard(),
                const SizedBox(height: 24),
                const Text('Recent Prescriptions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                const SizedBox(height: 12),
                if (_prescriptions.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: const Center(child: Text('No prescriptions yet', style: TextStyle(color: AppColors.textLight))),
                  )
                else
                  ..._prescriptions.map((p) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.dentist.withOpacity(0.15)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.person, color: AppColors.dentist, size: 16),
                        const SizedBox(width: 6),
                        Text(p['patient_name'] ?? 'Patient', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const Spacer(),
                        Text(p['created_at']?.toString().substring(0, 10) ?? '',
                            style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
                      ]),
                      const SizedBox(height: 4),
                      Text(p['diagnosis'] ?? '', style: const TextStyle(color: AppColors.dentist, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text('Medications: ${p['medications'] ?? ''}', style: const TextStyle(fontSize: 13)),
                      if ((p['dosage'] ?? '').toString().isNotEmpty)
                        Text('Dosage: ${p['dosage']}', style: const TextStyle(fontSize: 13)),
                      if ((p['instructions'] ?? '').toString().isNotEmpty)
                        Text('Instructions: ${p['instructions']}', style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => PdfService.generatePrescriptionReport(
                          prescription: p,
                          patientName: p['patient_name']?.toString() ?? 'Patient',
                        ),
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Download PDF'),
                      ),
                    ]),
                  )),
              ]),
            ),
    );
  }
}
