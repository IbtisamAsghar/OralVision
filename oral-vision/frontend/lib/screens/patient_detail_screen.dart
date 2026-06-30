import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/colors.dart';
import '../utils/health_utils.dart';
import '../widgets/app_card.dart';
import '../widgets/section_header.dart';

class PatientDetailScreen extends StatefulWidget {
  final String patientId;
  const PatientDetailScreen({super.key, required this.patientId});

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;

  bool _isLoading = true;
  Map<String, dynamic> _patient = {};
  List<Map<String, dynamic>> _scans = [];
  List<Map<String, dynamic>> _symptoms = [];
  List<Map<String, dynamic>> _prescriptions = [];
  String? _error;

  // Add prescription form
  final _noteController = TextEditingController();
  final List<Map<String, TextEditingController>> _medicines = [];
  bool _isSaving = false;

  double? get _healthScore => HealthUtils.computeOralHealthScore(
        scans: _scans,
        symptoms: _symptoms,
      );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _noteController.dispose();
    for (final m in _medicines) {
      m.values.forEach((c) => c.dispose());
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // Patient profile
      final profile = await _supabase
          .from('profiles')
          .select()
          .eq('id', widget.patientId)
          .maybeSingle();

      var scans = <Map<String, dynamic>>[];
      var symptoms = <Map<String, dynamic>>[];
      var prescriptions = <Map<String, dynamic>>[];

      try {
        final rows = await _supabase
            .from('scan_history')
            .select()
            .eq('user_id', widget.patientId)
            .order('scanned_at', ascending: false);
        scans = List<Map<String, dynamic>>.from(rows);
      } catch (_) {}

      try {
        final rows = await _supabase
            .from('symptom_history')
            .select()
            .eq('user_id', widget.patientId)
            .order('checked_at', ascending: false);
        symptoms = List<Map<String, dynamic>>.from(rows);
      } catch (_) {}

      try {
        final rows = await _supabase
            .from('prescriptions')
            .select()
            .eq('patient_id', widget.patientId)
            .order('created_at', ascending: false);
        prescriptions = List<Map<String, dynamic>>.from(rows);
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _patient = profile ?? {};
        _scans = scans;
        _symptoms = symptoms;
        _prescriptions = prescriptions;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load patient data: $e';
        _isLoading = false;
      });
    }
  }

  // ── ADD MEDICINE ROW ─────────────────────────────────────────────────────────
  void _addMedicineRow() {
    setState(() {
      _medicines.add({
        'name': TextEditingController(),
        'dosage': TextEditingController(),
        'frequency': TextEditingController(),
        'duration': TextEditingController(),
        'instructions': TextEditingController(),
      });
    });
  }

  void _removeMedicineRow(int index) {
    final row = _medicines[index];
    row.values.forEach((c) => c.dispose());
    setState(() => _medicines.removeAt(index));
  }

  // ── SAVE PRESCRIPTION ────────────────────────────────────────────────────────
  Future<void> _savePrescription() async {
    if (_noteController.text.trim().isEmpty && _medicines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a note or at least one medicine.'),
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

      final dentistName =
          dentistProfile?['full_name'] ?? 'Unknown Dentist';

      final medicines = _medicines
          .map((m) => {
                'name': m['name']!.text.trim(),
                'dosage': m['dosage']!.text.trim(),
                'frequency': m['frequency']!.text.trim(),
                'duration': m['duration']!.text.trim(),
                'instructions': m['instructions']!.text.trim(),
              })
          .where((m) => m['name']!.isNotEmpty)
          .toList();

      await _supabase.from('prescriptions').insert({
        'patient_id': widget.patientId,
        'dentist_id': user.id,
        'dentist_name': dentistName,
        'note': _noteController.text.trim(),
        'medicines': medicines,
      });

      // Clear form
      _noteController.clear();
      for (final m in _medicines) {
        m.values.forEach((c) => c.dispose());
      }
      setState(() => _medicines.clear());

      // Reload prescriptions
      await _loadData();

      if (!mounted) return;
      Navigator.pop(context); // close bottom sheet
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
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── PRESCRIPTION FORM SHEET ──────────────────────────────────────────────────
  void _showAddPrescriptionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          builder: (_, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                children: [
                  const Icon(Icons.medical_services,
                      color: AppColors.dentist),
                  const SizedBox(width: 8),
                  const Text('Add Note / Prescription',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              // Quick note
              TextFormField(
                controller: _noteController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Quick note for patient',
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: const Color(0xFFF8F9FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Medicines
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Medicines',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark)),
                  TextButton.icon(
                    onPressed: () {
                      setSheetState(() {
                        _medicines.add({
                          'name': TextEditingController(),
                          'dosage': TextEditingController(),
                          'frequency': TextEditingController(),
                          'duration': TextEditingController(),
                          'instructions': TextEditingController(),
                        });
                      });
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Medicine'),
                  ),
                ],
              ),
              ..._medicines.asMap().entries.map((entry) {
                final i = entry.key;
                final m = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.dentistSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.dentistTint),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Medicine ${i + 1}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.dentistDark)),
                          IconButton(
                            icon: const Icon(Icons.close,
                                color: AppColors.error, size: 18),
                            onPressed: () => setSheetState(
                                () => _removeMedicineRow(i)),
                          ),
                        ],
                      ),
                      _medField(m['name']!, 'Medicine Name'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                              child: _medField(m['dosage']!, 'Dosage')),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _medField(
                                  m['frequency']!, 'Frequency')),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                              child:
                                  _medField(m['duration']!, 'Duration')),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _medField(
                                  m['instructions']!, 'Instructions')),
                        ],
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _savePrescription,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.dentist,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(
                          color: Colors.white)
                      : const Text('Save Prescription',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _medField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  // ── HELPERS ──────────────────────────────────────────────────────────────────
  Color _riskColor(String risk) {
    switch (risk.toLowerCase()) {
      case 'high':
        return AppColors.riskHigh;
      case 'medium':
        return AppColors.riskMedium;
      default:
        return AppColors.riskLow;
    }
  }

  void _showScanDetail(Map<String, dynamic> scan) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Scan Details',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text(
                'Date: ${scan['scanned_at']?.toString().substring(0, 10) ?? 'Unknown'}'),
            Text('Result: ${HealthUtils.diseaseFromScan(scan)}'),
            Text(
                'Confidence: ${((scan['confidence_score'] as num?)?.toDouble() ?? 0) * 100}%'),
            const SizedBox(height: 8),
            Text('AI Notes: ${HealthUtils.scanAiNotes(scan)}',
                style: const TextStyle(
                    color: AppColors.textLight, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  void _showSymptomDetail(Map<String, dynamic> sym) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Symptom Details',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text('Result: ${HealthUtils.diseaseFromSymptom(sym)}'),
            Text(
                'Confidence: ${((sym['confidence_score'] as num?)?.toDouble() ?? 0) * 100}%'),
            const SizedBox(height: 8),
            Text('AI Notes: ${HealthUtils.symptomAiNotes(sym)}',
                style: const TextStyle(
                    color: AppColors.textLight, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // ── TAB BUILDERS ─────────────────────────────────────────────────────────────
  Widget _buildOverviewTab() {
    final score = _healthScore;
    final name = _patient['full_name'] ?? 'Patient';
    final age = _patient['age']?.toString() ?? '';
    final gender = HealthUtils.formatGender(_patient['gender'] ?? '');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Patient info card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.dentistDark, AppColors.dentistAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.white,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'P',
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.dentistDark),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      if (age.isNotEmpty)
                        Text('$age yrs · $gender',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13)),
                      Text(_patient['email'] ?? '',
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 11)),
                    ],
                  ),
                ),
                if (score != null)
                  Column(
                    children: [
                      Text(
                        score.toStringAsFixed(0),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold),
                      ),
                      const Text('Score',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 11)),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Stats
          Row(
            children: [
              _statCard('Scans', '${_scans.length}', Icons.camera_alt),
              const SizedBox(width: 10),
              _statCard(
                  'Symptoms', '${_symptoms.length}', Icons.psychology),
              const SizedBox(width: 10),
              _statCard('Prescriptions', '${_prescriptions.length}',
                  Icons.medical_services),
            ],
          ),
          const SizedBox(height: 16),
          // Add prescription button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _showAddPrescriptionSheet,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.dentist,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add Note / Prescription',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),
          // Recent scans preview
          SectionHeader(
            title: 'Recent Scans',
            icon: Icons.camera_alt,
            color: AppColors.dentist,
          ),
          if (_scans.isEmpty)
            const AppCard(
              child: Text('No scans found.',
                  style: TextStyle(color: AppColors.textLight)),
            )
          else
            ..._scans.take(3).map((s) => _buildScanCard(s)),
          const SizedBox(height: 12),
          SectionHeader(
            title: 'Recent Symptoms',
            icon: Icons.psychology,
            color: AppColors.dentist,
          ),
          if (_symptoms.isEmpty)
            const AppCard(
              child: Text('No symptom checks found.',
                  style: TextStyle(color: AppColors.textLight)),
            )
          else
            ..._symptoms.take(2).map((s) => _buildSymptomCard(s)),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildScansTab() {
    return _scans.isEmpty
        ? const Center(
            child: Text('No scan records.',
                style: TextStyle(color: AppColors.textLight)))
        : ListView(
            padding: const EdgeInsets.all(16),
            children: _scans.map((s) => _buildScanCard(s)).toList(),
          );
  }

  Widget _buildPrescriptionsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _showAddPrescriptionSheet,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.dentist,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add Note / Prescription',
                  style: TextStyle(color: Colors.white)),
            ),
          ),
        ),
        Expanded(
          child: _prescriptions.isEmpty
              ? const Center(
                  child: Text('No prescriptions yet.',
                      style: TextStyle(color: AppColors.textLight)))
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: _prescriptions
                      .map((rx) => _buildPrescriptionCard(rx))
                      .toList(),
                ),
        ),
      ],
    );
  }

  // ── CARDS ─────────────────────────────────────────────────────────────────────
  Widget _statCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.grey.withValues(alpha: 0.08),
                blurRadius: 8)
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.dentist, size: 20),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppColors.textDark)),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textLight)),
          ],
        ),
      ),
    );
  }

  Widget _buildScanCard(Map<String, dynamic> scan) {
    final disease = HealthUtils.diseaseFromScan(scan);
    final risk = HealthUtils.riskFromDisease(disease);
    final date =
        scan['scanned_at']?.toString().substring(0, 10) ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        onTap: () => _showScanDetail(scan),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.camera_alt, color: _riskColor(risk)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(disease,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold)),
                  Text('$date · Risk: $risk',
                      style: TextStyle(
                          fontSize: 11, color: _riskColor(risk))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.textLight, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSymptomCard(Map<String, dynamic> sym) {
    final disease = HealthUtils.diseaseFromSymptom(sym);
    final risk = HealthUtils.riskFromDisease(disease);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        onTap: () => _showSymptomDetail(sym),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.psychology, color: _riskColor(risk)),
            const SizedBox(width: 12),
            Expanded(
              child: Text('$disease · Risk: $risk',
                  style:
                      const TextStyle(fontWeight: FontWeight.w600)),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.textLight, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildPrescriptionCard(Map<String, dynamic> rx) {
    final medicines = (rx['medicines'] as List<dynamic>?) ?? [];
    final date =
        rx['created_at']?.toString().substring(0, 10) ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.medical_services,
                    color: AppColors.dentist, size: 18),
                const SizedBox(width: 8),
                Text('Dr. ${rx['dentist_name'] ?? 'Unknown'}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(date,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textLight)),
              ],
            ),
            if ((rx['note'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(rx['note'],
                  style: const TextStyle(
                      color: AppColors.textLight, fontSize: 13)),
            ],
            if (medicines.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...medicines.map((m) {
                final med = m as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.dentistSurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '• ${med['name']} ${med['dosage']} — ${med['frequency']} for ${med['duration']}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final name = _patient['full_name'] ?? 'Patient';

    return Scaffold(
      backgroundColor: AppColors.dentistBg,
      appBar: AppBar(
        backgroundColor: AppColors.dentistDark,
        title: Text(
          _isLoading ? 'Patient Detail' : name,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.person_outline), text: 'Overview'),
            Tab(icon: Icon(Icons.camera_alt), text: 'Scans'),
            Tab(
                icon: Icon(Icons.medical_services),
                text: 'Prescriptions'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.dentist))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: AppColors.error),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.dentist),
                        child: const Text('Retry',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildScansTab(),
                    _buildPrescriptionsTab(),
                  ],
                ),
    );
  }
}