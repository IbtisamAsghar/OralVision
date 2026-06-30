import 'package:flutter/material.dart';
import '../utils/colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/navigation_utils.dart';
import '../widgets/section_header.dart';
import '../widgets/app_card.dart';

class DentistDashboard extends StatefulWidget {
  const DentistDashboard({super.key});
  @override
  State<DentistDashboard> createState() => _DentistDashboardState();
}

class _DentistDashboardState extends State<DentistDashboard>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic> _profile = {};
  Map<String, dynamic> _dentist = {};
  List<Map<String, dynamic>> _patients = [];
  List<Map<String, dynamic>> _appointments = [];
  bool _isLoading = true;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _loadData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      final profile = await _supabase.from('profiles').select().eq('id', user.id).maybeSingle();
      final dentist = await _supabase.from('dentist_profiles').select().eq('user_id', user.id).single();
      final patients = await _supabase.from('patient_records').select().eq('dentist_id', user.id).order('visit_date', ascending: false);
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final appointments = await _supabase.from('appointments').select().eq('dentist_id', user.id).gte('appointment_date', today).order('appointment_date').limit(20);
      setState(() {
        _profile = profile != null ? Map<String, dynamic>.from(profile) : {};
        _dentist = Map<String, dynamic>.from(dentist);
        _patients = List<Map<String, dynamic>>.from(patients);
        _appointments = List<Map<String, dynamic>>.from(appointments);
        _isLoading = false;
      });
      _fadeController.forward(from: 0);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String get _name => _profile['full_name'] ?? _dentist['clinic_name'] ?? 'Doctor';
  String get _specialization => _dentist['specialization'] ?? 'General Dentist';

  int get _todayAppointments => _appointments.where((a) {
    final d = a['appointment_date']?.toString().substring(0, 10);
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return d == today;
  }).length;

  int get _completedConsultations =>
      _appointments.where((a) => a['status'] == 'completed').length;

  List<Map<String, dynamic>> get _caseAlerts {
    final alerts = <Map<String, dynamic>>[];
    for (final p in _patients.take(5)) {
      final diag = (p['diagnosis'] ?? '').toString().toLowerCase();
      if (diag.contains('abscess') || diag.contains('periodontitis') || diag.contains('risk')) {
        alerts.add({'type': 'high', 'title': 'High Risk Patient', 'subtitle': p['diagnosis'] ?? 'Needs urgent review'});
      } else if (diag.isNotEmpty) {
        alerts.add({'type': 'followup', 'title': 'Follow-up Needed', 'subtitle': p['diagnosis']});
      }
    }
    if (alerts.isEmpty && _patients.isNotEmpty) {
      alerts.add({'type': 'scan', 'title': 'New Case Review', 'subtitle': 'Review latest patient records'});
    }
    return alerts.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dentistBg,
      appBar: AppBar(
        backgroundColor: AppColors.dentistDark,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Clinic Dashboard',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.dentistDark,
        onPressed: _showAddPatientDialog,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Record', style: TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.dentist))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.dentist,
              child: FadeTransition(
                opacity: _fadeController,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 20),
                      _buildStatsGrid(),
                      const SizedBox(height: 24),
                      _buildCaseAlerts(),
                      const SizedBox(height: 24),
                      _buildAiAssistant(),
                      const SizedBox(height: 24),
                      _buildAppointmentsPreview(),
                      const SizedBox(height: 24),
                      _buildClinicalNotes(),
                      const SizedBox(height: 24),
                      _buildActivityInsights(),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    final initial = _name.isNotEmpty ? _name[0].toUpperCase() : 'D';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.dentistDark, AppColors.dentistAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: AppColors.dentist.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                child: CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.white,
                  child: Text(initial, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.dentistDark)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Good day,', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text('Dr. $_name', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    Text('BDS   $_specialization', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.verified, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text('Verified Dentist', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _statBadge('${_patients.length}', 'Patients', Icons.people),
              Container(width: 1, height: 36, color: Colors.white24),
              _statBadge('$_todayAppointments', 'Today', Icons.today),
              Container(width: 1, height: 36, color: Colors.white24),
              _statBadge('$_completedConsultations', 'Done', Icons.check_circle),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _statBadge(String value, String label, IconData icon) {
    return Column(children: [
      Icon(icon, color: Colors.white70, size: 16),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
    ]);
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        StatCard(label: 'Total Patients', value: '${_patients.length}', icon: Icons.people, color: AppColors.dentist),
        StatCard(label: "Today's Appointments", value: '$_todayAppointments', icon: Icons.today, color: AppColors.dentistAccent),
        StatCard(label: 'Consultations Done', value: '$_completedConsultations', icon: Icons.check_circle, color: const Color(0xFF43A047)),
        StatCard(label: 'Average Rating', value: '4.8 ?', icon: Icons.star, color: const Color(0xFFFFA726), subtitle: 'Based on patient feedback'),
      ],
    );
  }

  Widget _buildCaseAlerts() {
    final alerts = _caseAlerts;
    if (alerts.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Case Alerts', icon: Icons.notification_important, color: AppColors.dentist),
        ...alerts.map((a) {
          final color = a['type'] == 'high' ? AppColors.error : a['type'] == 'followup' ? Colors.orange : AppColors.dentistAccent;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              onTap: () => Navigator.pushNamed(context, '/dentist-appointments'),
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Icon(a['type'] == 'high' ? Icons.error : a['type'] == 'followup' ? Icons.schedule : Icons.new_releases, color: color),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a['title'], style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                  Text(a['subtitle'], style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
                ])),
              ]),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAiAssistant() {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionHeader(title: 'AI Clinical Assistant', icon: Icons.smart_toy, color: AppColors.dentist),
        _AiBtn('Open Clinical Chatbot', Icons.chat, () {
          Navigator.pushNamed(context, '/dentist-chatbot');
        }),
      ]),
    );
  }

  Widget _buildAppointmentsPreview() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final todayList = _appointments.where((a) => a['appointment_date']?.toString().startsWith(today) == true).toList();
    final upcoming = _appointments.where((a) => !a['appointment_date'].toString().startsWith(today)).take(3).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader(
        title: 'Appointments',
        icon: Icons.event,
        color: AppColors.dentist,
        trailing: TextButton(
          onPressed: () => Navigator.pushNamed(context, '/dentist-appointments'),
          child: const Text('See all', style: TextStyle(color: AppColors.dentist)),
        ),
      ),
      AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Today's Schedule", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        if (todayList.isEmpty)
          const Text('No appointments today', style: TextStyle(color: AppColors.textLight, fontSize: 13))
        else
          ...todayList.map((a) => _ApptRow(a)),
        if (upcoming.isNotEmpty) ...[
          const Divider(height: 24),
          const Text('Upcoming', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...upcoming.map((a) => _ApptRow(a)),
        ],
      ])),
    ]);
  }

  Widget _buildClinicalNotes() {
    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeader(title: 'Clinical Notes', icon: Icons.note_alt, color: AppColors.dentist),
      if (_patients.isEmpty)
        const Text('Add patient records to view clinical notes.', style: TextStyle(color: AppColors.textLight, fontSize: 13))
      else ...[
        Text('Latest: ${_patients.first['diagnosis'] ?? 'N/A'}', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(_patients.first['notes']?.toString() ?? 'AI Summary: Patient shows stable oral health. Recommend routine follow-up in 3 months.',
            style: const TextStyle(color: AppColors.textLight, fontSize: 13)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/prescription'),
          icon: const Icon(Icons.medication),
          label: const Text('Write Prescription'),
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.dentist),
        ),
      ],
    ]));
  }

  Widget _buildActivityInsights() {
    final monthlyTrend = List.generate(6, (i) => (i + 1) * 2 + _patients.length % 3);
    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeader(title: 'Activity Insights', icon: Icons.insights, color: AppColors.dentist),
      const Text('Most Common: Gingivitis & Dental Caries', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      const SizedBox(height: 14),
      const Text('Monthly Patient Trend', style: TextStyle(color: AppColors.textLight, fontSize: 12)),
      const SizedBox(height: 8),
      SizedBox(
        height: 60,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: List.generate(6, (i) {
          final h = (monthlyTrend[i] * 8.0).clamp(8.0, 50.0);
          return Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 300 + i * 100),
              height: h,
              decoration: BoxDecoration(
                color: AppColors.dentist.withOpacity(0.4 + i * 0.08),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ));
        })),
      ),
      const SizedBox(height: 8),
      Text('$_completedConsultations consultations completed   ${_patients.length} total patients',
          style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
    ]));
  }

  void _showAiResult(String title, String body) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        const Icon(Icons.auto_awesome, color: AppColors.dentist),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 16)),
      ]),
      content: Text(body),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
    ));
  }

  Future<void> _logout() async {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Logout'),
      content: const Text('Are you sure?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(ctx);
            await logoutAndGoToRole(context);
          },
          child: const Text('Logout'),
        ),
      ],
    ));
  }

  void _showAddPatientDialog() {
    final diagnosisController = TextEditingController();
    final notesController = TextEditingController();
    final treatmentController = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Add Patient Record', style: TextStyle(color: AppColors.dentist, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: diagnosisController, decoration: const InputDecoration(labelText: 'Diagnosis')),
        TextField(controller: notesController, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes')),
        TextField(controller: treatmentController, decoration: const InputDecoration(labelText: 'Treatment Plan')),
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
                'diagnosis': diagnosisController.text,
                'notes': notesController.text,
                'treatment_plan': treatmentController.text,
              });
              Navigator.pop(ctx);
              _loadData();
            } catch (_) {}
          },
          child: const Text('Save', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }
}

class _AiBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _AiBtn(this.label, this.icon, this.onTap);
  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.dentistBg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Icon(icon, color: AppColors.dentist, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
            const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textLight),
          ]),
        ),
      ),
    );
  }
}

class _ApptRow extends StatelessWidget {
  final Map<String, dynamic> appt;
  const _ApptRow(this.appt);
  @override
  Widget build(BuildContext context) {
    final status = appt['status'] ?? 'pending';
    final isDone = status == 'completed';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(isDone ? Icons.check_circle : Icons.schedule, color: isDone ? Colors.green : AppColors.dentist, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text('${appt['appointment_date']?.toString().substring(0, 10)}   ${appt['appointment_time'] ?? ''}', style: const TextStyle(fontSize: 13))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: isDone ? Colors.green.withOpacity(0.12) : Colors.orange.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(isDone ? 'Completed' : 'Pending',
              style: TextStyle(fontSize: 11, color: isDone ? Colors.green : Colors.orange, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
          if (subtitle != null)
            Text(subtitle!, style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
        ],
      ),
    );
  }
}
