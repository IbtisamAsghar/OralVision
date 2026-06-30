import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/colors.dart';
import '../utils/health_utils.dart';
import '../utils/prescription_utils.dart';
import '../services/pdf_service.dart';
import '../widgets/app_card.dart';
import '../widgets/section_header.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  List<Map<String, dynamic>> _scans = [];
  List<Map<String, dynamic>> _symptoms = [];
  List<Map<String, dynamic>> _prescriptions = [];
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final user = _supabase.auth.currentUser;
    if (user == null) { setState(() => _isLoading = false); return; }

    var scans = <Map<String, dynamic>>[];
    var symptoms = <Map<String, dynamic>>[];
    var prescriptions = <Map<String, dynamic>>[];

    try {
      final rows = await _supabase.from('scan_history').select().eq('user_id', user.id).order('scanned_at', ascending: false).limit(50);
      scans = List<Map<String, dynamic>>.from(rows);
    } catch (_) {}
    try {
      final rows = await _supabase.from('symptom_history').select().eq('user_id', user.id).order('checked_at', ascending: false).limit(50);
      symptoms = List<Map<String, dynamic>>.from(rows);
    } catch (_) {}
    try {
      final rows = await _supabase.from('prescriptions').select().eq('patient_id', user.id).order('created_at', ascending: false);
      prescriptions = List<Map<String, dynamic>>.from(rows);
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _scans = scans;
      _symptoms = symptoms;
      _prescriptions = prescriptions;
      _isLoading = false;
    });
  }

  Color _riskColor(String risk) {
    switch (risk.toLowerCase()) {
      case 'high': return AppColors.riskHigh;
      case 'medium': return AppColors.riskMedium;
      default: return AppColors.riskLow;
    }
  }

  void _showScanDetail(Map<String, dynamic> scan) {
    final disease = HealthUtils.diseaseFromScan(scan);
    final risk = HealthUtils.riskFromDisease(disease);
    final imageUrl = scan['image_url']?.toString();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.9,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          children: [
            Row(children: [
              const Icon(Icons.camera_alt, color: AppColors.patient),
              const SizedBox(width: 8),
              const Text('Scan Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 16),
            if (imageUrl != null && imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(imageUrl: imageUrl, height: 160, width: double.infinity, fit: BoxFit.cover),
              ),
            const SizedBox(height: 12),
            Text('Date: ${scan['scanned_at']?.toString().substring(0, 10) ?? 'Unknown'}'),
            Text('Type: ${scan['scan_type'] ?? 'oral'}'),
            Text('Result: $disease'),
            Text('Confidence: ${((scan['confidence_score'] as num?)?.toDouble() ?? 0) * 100}%'),
            if (scan['affected_area'] != null) Text('Affected Area: ${scan['affected_area']}%'),
            Text('Risk: $risk'),
            const SizedBox(height: 8),
            Text(HealthUtils.scanAiNotes(scan), style: const TextStyle(color: AppColors.textLight, fontSize: 13)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final user = _supabase.auth.currentUser;
                  var name = 'Patient';
                  if (user != null) {
                    final p = await _supabase.from('profiles').select('full_name').eq('id', user.id).maybeSingle();
                    name = p?['full_name']?.toString() ?? name;
                  }
                  await PdfService.generateScanReport(
                    context: context,
                    result: {
                      'disease': disease,
                      'confidence': ((scan['confidence_score'] as num?)?.toDouble() ?? 0) * 100,
                      'affected_area': scan['affected_area'] ?? 0,
                      'recommendation': scan['ai_notes'] ?? HealthUtils.scanAiNotes(scan),
                      'risk_level': risk,
                    },
                    scanType: scan['scan_type']?.toString() ?? 'oral',
                    patientName: name,
                  );
                },
                icon: const Icon(Icons.download),
                label: const Text('Download Report PDF'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSymptomDetail(Map<String, dynamic> sym) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.psychology, color: AppColors.patient), const SizedBox(width: 8), const Text('Symptom Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
          const SizedBox(height: 16),
          Text('Result: ${HealthUtils.diseaseFromSymptom(sym)}'),
          Text('Confidence: ${((sym['confidence_score'] as num?)?.toDouble() ?? 0) * 100}%'),
          const SizedBox(height: 8),
          Text('AI Notes: ${HealthUtils.symptomAiNotes(sym)}', style: const TextStyle(color: AppColors.textLight, fontSize: 13)),
        ]),
      ),
    );
  }

  void _showPrescriptionDetail(Map<String, dynamic> rx) {
    final medicines = PrescriptionUtils.medicines(rx);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        maxChildSize: 0.85,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          children: [
            Row(children: [const Icon(Icons.medical_services, color: AppColors.patient), const SizedBox(width: 8), const Text('Prescription Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
            const SizedBox(height: 12),
            Text('Dr. ${PrescriptionUtils.dentistName(rx)}  •  ${rx['created_at']?.toString().substring(0, 10) ?? ''}'),
            if (PrescriptionUtils.diagnosis(rx).isNotEmpty)
              Text('Diagnosis: ${PrescriptionUtils.diagnosis(rx)}'),
            if (PrescriptionUtils.doctorNote(rx).isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Doctor note: ${PrescriptionUtils.doctorNote(rx)}', style: const TextStyle(color: AppColors.textLight)),
            ],
            if (medicines.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Medicines', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...medicines.map((m) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.patientSurface, borderRadius: BorderRadius.circular(10)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(m['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('${m['dosage']} ${m['frequency']} ${m['duration']}'.trim()),
                      if ((m['instructions'] ?? '').toString().isNotEmpty)
                        Text(m['instructions'].toString(), style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
                    ]),
                  )),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final user = _supabase.auth.currentUser;
                  var name = 'Patient';
                  if (user != null) {
                    final p = await _supabase.from('profiles').select('full_name').eq('id', user.id).maybeSingle();
                    name = p?['full_name']?.toString() ?? name;
                  }
                  await PdfService.generatePrescriptionReport(prescription: rx, patientName: name);
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.patient),
                icon: const Icon(Icons.download, color: Colors.white),
                label: const Text('Download Prescription PDF', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanCard(Map<String, dynamic> scan) {
    final disease = HealthUtils.diseaseFromScan(scan);
    final risk = HealthUtils.riskFromDisease(disease);
    final date = scan['scanned_at']?.toString().substring(0, 10) ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        onTap: () => _showScanDetail(scan),
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Icon(Icons.camera_alt, color: _riskColor(risk)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(disease, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('$date · Risk: $risk', style: TextStyle(fontSize: 11, color: _riskColor(risk))),
          ])),
          const Icon(Icons.chevron_right, color: AppColors.textLight, size: 18),
        ]),
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
        child: Row(children: [
          Icon(Icons.psychology, color: _riskColor(risk)),
          const SizedBox(width: 12),
          Expanded(child: Text('$disease · Risk: $risk', style: const TextStyle(fontWeight: FontWeight.w600))),
          const Icon(Icons.chevron_right, color: AppColors.textLight, size: 18),
        ]),
      ),
    );
  }

  Widget _buildPrescriptionCard(Map<String, dynamic> rx) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        onTap: () => _showPrescriptionDetail(rx),
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          const Icon(Icons.medical_services, color: AppColors.patient),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Dr. ${PrescriptionUtils.dentistName(rx)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('${PrescriptionUtils.medicineCount(rx)} medicine(s) · ${rx['created_at']?.toString().substring(0, 10) ?? ''}',
                style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
          ])),
          const Icon(Icons.chevron_right, color: AppColors.textLight, size: 18),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filters = ['All', 'Scans', 'Symptoms', 'Prescriptions'];
    List<Widget> items = [];

    if (_filter == 'All' || _filter == 'Scans') {
      if (_scans.isNotEmpty) {
        items.add(SectionHeader(title: 'Scans', icon: Icons.camera_alt, color: AppColors.patient));
        items.addAll(_scans.map((s) => _buildScanCard(s)));
      }
    }
    if (_filter == 'All' || _filter == 'Symptoms') {
      if (_symptoms.isNotEmpty) {
        items.add(SectionHeader(title: 'Symptom Checks', icon: Icons.psychology, color: AppColors.patient));
        items.addAll(_symptoms.map((s) => _buildSymptomCard(s)));
      }
    }
    if (_filter == 'All' || _filter == 'Prescriptions') {
      if (_prescriptions.isNotEmpty) {
        items.add(SectionHeader(title: 'Dentist Prescriptions', icon: Icons.medical_services, color: AppColors.patient));
        items.addAll(_prescriptions.map((rx) => _buildPrescriptionCard(rx)));
      }
    }

    return Scaffold(
      backgroundColor: AppColors.patientBg,
      appBar: AppBar(
        backgroundColor: AppColors.patientDark,
        automaticallyImplyLeading: false,
        title: const Text('History', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.patient))
          : Column(children: [
              Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: filters.map((f) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(f),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                      selectedColor: AppColors.patientSurface,
                      checkmarkColor: AppColors.patient,
                      labelStyle: TextStyle(
                        color: _filter == f ? AppColors.patient : AppColors.textLight,
                        fontWeight: _filter == f ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  )).toList(),
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? const Center(child: Text('No records found.', style: TextStyle(color: AppColors.textLight)))
                    : RefreshIndicator(
                        onRefresh: _loadHistory,
                        color: AppColors.patient,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: items,
                        ),
                      ),
              ),
            ]),
    );
  }
}