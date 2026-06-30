import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/colors.dart';
import '../widgets/app_card.dart';
import '../widgets/section_header.dart';
import 'prescription_screen.dart';

class DentistPatientsScreen extends StatefulWidget {
  const DentistPatientsScreen({super.key});
  @override
  State<DentistPatientsScreen> createState() => _DentistPatientsScreenState();
}

class _DentistPatientsScreenState extends State<DentistPatientsScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _patients = [];
  List<Map<String, dynamic>> _scanHistory = [];
  List<Map<String, dynamic>> _symptomHistory = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filterRisk = 'All';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final patients = await _supabase
          .from('patient_records')
          .select()
          .eq('dentist_id', user.id)
          .order('visit_date', ascending: false);

      var scans = <Map<String, dynamic>>[];
      var symptoms = <Map<String, dynamic>>[];
      try {
        final s = await _supabase.from('scan_history').select().order('scanned_at', ascending: false).limit(50);
        scans = List<Map<String, dynamic>>.from(s);
      } catch (_) {}
      try {
        final s = await _supabase.from('symptom_history').select().order('checked_at', ascending: false).limit(50);
        symptoms = List<Map<String, dynamic>>.from(s);
      } catch (_) {}

      setState(() {
        _patients = List<Map<String, dynamic>>.from(patients);
        _scanHistory = scans;
        _symptomHistory = symptoms;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _patients.where((p) {
      final name = (p['patient_name'] ?? p['full_name'] ?? p['diagnosis'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();
    if (_filterRisk != 'All') {
      list = list.where((p) {
        final risk = (p['risk_level'] ?? '').toString().toLowerCase();
        return risk == _filterRisk.toLowerCase();
      }).toList();
    }
    return list;
  }

  Color _riskColor(String risk) {
    switch (risk.toLowerCase()) {
      case 'high': return AppColors.riskHigh;
      case 'medium': return AppColors.riskMedium;
      default: return AppColors.riskLow;
    }
  }

  void _showPatientReport(Map<String, dynamic> p) {
    final patientId = p['patient_id'] ?? p['id'];
    final patientScans = _scanHistory.where((s) => s['user_id'] == patientId).toList();
    final patientSymptoms = _symptomHistory.where((s) => s['user_id'] == patientId).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF4F7FB),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.dentistDark, AppColors.dentistAccent]),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 24,
                  child: Text(
                    (p['patient_name'] ?? p['full_name'] ?? 'P').toString().isNotEmpty
                        ? (p['patient_name'] ?? p['full_name'] ?? 'P')[0].toUpperCase()
                        : 'P',
                    style: const TextStyle(color: AppColors.dentistDark, fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p['patient_name'] ?? p['full_name'] ?? 'Patient',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('Diagnosis: ${p['diagnosis'] ?? 'General Check-up'}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  if (p['visit_date'] != null)
                    Text('Last visit: ${p['visit_date'].toString().substring(0, 10)}',
                        style: const TextStyle(color: Colors.white60, fontSize: 11)),
                ])),
              ]),
            ),
            Expanded(child: ListView(
              controller: controller,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _reportSection('Patient Record', Icons.folder_open, [
                  _reportRow('Diagnosis', p['diagnosis'] ?? 'N/A'),
                  _reportRow('Treatment Plan', p['treatment_plan'] ?? 'N/A'),
                  _reportRow('Notes', p['notes'] ?? 'N/A'),
                  _reportRow('Risk Level', (p['risk_level'] ?? 'Low').toString().toUpperCase()),
                ]),
                const SizedBox(height: 12),
                _reportSection(
                  'AI Scan Reports (${patientScans.length})',
                  Icons.camera_alt,
                  patientScans.isEmpty
                      ? [const Text('No scan history found.', style: TextStyle(color: AppColors.textLight, fontSize: 13))]
                      : patientScans.take(5).map((s) => _scanRow(s)).toList(),
                ),
                const SizedBox(height: 12),
                _reportSection(
                  'Symptom Checks (${patientSymptoms.length})',
                  Icons.psychology,
                  patientSymptoms.isEmpty
                      ? [const Text('No symptom history found.', style: TextStyle(color: AppColors.textLight, fontSize: 13))]
                      : patientSymptoms.take(5).map((s) => _symptomRow(s)).toList(),
                ),
                const SizedBox(height: 24),
                // ── FIXED: passes patient_id and patient_name to PrescriptionScreen ──
                SizedBox(
                  width: double.infinity, height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PrescriptionScreen(
                            patientId: p['patient_id']?.toString() ?? p['id']?.toString(),
                            patientName: p['patient_name']?.toString() ?? p['full_name']?.toString(),
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.dentist,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.medication, color: Colors.white),
                    label: const Text('Write Prescription', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            )),
          ]),
        ),
      ),
    );
  }

  Widget _reportSection(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: AppColors.dentist, size: 18),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark, fontSize: 14)),
        ]),
        const SizedBox(height: 12),
        ...children,
      ]),
    );
  }

  Widget _reportRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 110, child: Text(label, style: const TextStyle(color: AppColors.textLight, fontSize: 12))),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
      ]),
    );
  }

  Widget _scanRow(Map<String, dynamic> s) {
    final disease = s['predicted_disease'] ?? s['result'] ?? 'Unknown';
    final confidence = ((s['confidence_score'] as num?)?.toDouble() ?? 0) * 100;
    final date = s['scanned_at']?.toString().substring(0, 10) ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.dentistBg, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        const Icon(Icons.camera_alt_outlined, color: AppColors.dentist, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(disease, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Text('$date · ${confidence.toStringAsFixed(0)}% confidence',
              style: const TextStyle(color: AppColors.textLight, fontSize: 11)),
        ])),
      ]),
    );
  }

  Widget _symptomRow(Map<String, dynamic> s) {
    final disease = s['predicted_disease'] ?? 'Unknown';
    final confidence = ((s['confidence_score'] as num?)?.toDouble() ?? 0) * 100;
    final date = s['checked_at']?.toString().substring(0, 10) ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.dentistBg, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        const Icon(Icons.psychology_outlined, color: AppColors.dentistAccent, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(disease, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Text('$date · ${confidence.toStringAsFixed(0)}% confidence',
              style: const TextStyle(color: AppColors.textLight, fontSize: 11)),
        ])),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: AppColors.dentistBg,
      appBar: AppBar(
        backgroundColor: AppColors.dentistDark,
        automaticallyImplyLeading: false,
        title: const Text('My Patients', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.dentist))
          : Column(children: [
              Container(
                color: AppColors.dentistDark,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(children: [
                  TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search patients...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(Icons.search, color: Colors.white60),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.15),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(children: ['All', 'High', 'Medium', 'Low'].map((r) {
                    final selected = _filterRisk == r;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _filterRisk = r),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: selected ? Colors.white : Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(r, style: TextStyle(
                            color: selected ? AppColors.dentistDark : Colors.white,
                            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          )),
                        ),
                      ),
                    );
                  }).toList()),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: Colors.white,
                child: Row(children: [
                  const Icon(Icons.people, color: AppColors.dentist, size: 16),
                  const SizedBox(width: 8),
                  Text('${filtered.length} patient${filtered.length != 1 ? 's' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark)),
                  const Spacer(),
                  Text('Tap to view full report', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ]),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        const Text('No patients found', style: TextStyle(color: AppColors.textLight)),
                      ]))
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        color: AppColors.dentist,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, i) {
                            final p = filtered[i];
                            final name = p['patient_name'] ?? p['full_name'] ?? 'Unknown Patient';
                            final risk = (p['risk_level'] ?? 'low').toString();
                            final diag = p['diagnosis'] ?? 'General Check-up';
                            final lastVisit = p['visit_date']?.toString().substring(0, 10) ?? p['created_at']?.toString().substring(0, 10) ?? '';
                            final rColor = _riskColor(risk);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: AppCard(
                                onTap: () => _showPatientReport(p),
                                padding: const EdgeInsets.all(14),
                                child: Row(children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: AppColors.dentistSurface,
                                    child: Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : 'P',
                                      style: const TextStyle(color: AppColors.dentistDark, fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    Text(diag, style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
                                    if (lastVisit.isNotEmpty)
                                      Text('Last visit: $lastVisit', style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
                                  ])),
                                  Column(children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: rColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(risk.toUpperCase(),
                                          style: TextStyle(color: rColor, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(height: 4),
                                    const Icon(Icons.chevron_right, color: AppColors.textLight, size: 18),
                                  ]),
                                ]),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ]),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.dentistDark,
        onPressed: () {
          final dc = TextEditingController();
          final nc = TextEditingController();
          final tc = TextEditingController();
          showDialog(context: context, builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Add Patient Record', style: TextStyle(color: AppColors.dentist, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: dc, decoration: const InputDecoration(labelText: 'Diagnosis')),
              TextField(controller: nc, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes')),
              TextField(controller: tc, decoration: const InputDecoration(labelText: 'Treatment Plan')),
            ])),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.dentist),
                onPressed: () async {
                  try {
                    final user = _supabase.auth.currentUser;
                    await _supabase.from('patient_records').insert({
                      'dentist_id': user!.id,
                      'diagnosis': dc.text,
                      'notes': nc.text,
                      'treatment_plan': tc.text,
                    });
                    Navigator.pop(ctx);
                    _loadData();
                  } catch (_) {}
                },
                child: const Text('Save', style: TextStyle(color: Colors.white)),
              ),
            ],
          ));
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}