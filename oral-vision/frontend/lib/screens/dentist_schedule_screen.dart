import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/colors.dart';
import '../widgets/app_card.dart';
import '../widgets/section_header.dart';

class DentistScheduleScreen extends StatefulWidget {
  const DentistScheduleScreen({super.key});
  @override
  State<DentistScheduleScreen> createState() => _DentistScheduleScreenState();
}

class _DentistScheduleScreenState extends State<DentistScheduleScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _appointments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final rows = await _supabase
          .from('appointments')
          .select()
          .eq('dentist_id', user.id)
          .gte('appointment_date', today)
          .order('appointment_date')
          .order('appointment_time');
      setState(() {
        _appointments = List<Map<String, dynamic>>.from(rows);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _todayAppts {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return _appointments.where((a) => a['appointment_date']?.toString().startsWith(today) == true).toList();
  }

  List<Map<String, dynamic>> get _upcomingAppts {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return _appointments.where((a) => !(a['appointment_date']?.toString().startsWith(today) == true)).toList();
  }

  int get _pendingCount =>
      _appointments.where((a) => (a['status'] ?? 'pending') == 'pending').length;

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed': return Colors.green;
      case 'completed': return AppColors.dentist;
      case 'cancelled': return AppColors.error;
      default: return Colors.orange;
    }
  }

  Future<void> _updateStatus(String apptId, String status) async {
    try {
      await _supabase.from('appointments').update({'status': status}).eq('id', apptId);
      _loadAppointments();
    } catch (_) {}
  }

  void _showApptOptions(Map<String, dynamic> a) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Appointment Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text('${a['appointment_date']?.toString().substring(0, 10)} at ${a['appointment_time'] ?? ''}',
              style: const TextStyle(color: AppColors.textLight, fontSize: 13)),
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(Icons.check_circle, color: Colors.green),
            title: const Text('Mark as Confirmed'),
            onTap: () { Navigator.pop(ctx); _updateStatus(a['id'].toString(), 'confirmed'); },
          ),
          ListTile(
            leading: const Icon(Icons.task_alt, color: AppColors.dentist),
            title: const Text('Mark as Completed'),
            onTap: () { Navigator.pop(ctx); _updateStatus(a['id'].toString(), 'completed'); },
          ),
          ListTile(
            leading: const Icon(Icons.cancel, color: AppColors.error),
            title: const Text('Cancel Appointment'),
            onTap: () { Navigator.pop(ctx); _updateStatus(a['id'].toString(), 'cancelled'); },
          ),
          ListTile(
            leading: const Icon(Icons.medication, color: AppColors.dentistAccent),
            title: const Text('Write Prescription'),
            onTap: () { Navigator.pop(ctx); Navigator.pushNamed(context, '/prescription'); },
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = _pendingCount;
    return Scaffold(
      backgroundColor: AppColors.dentistBg,
      appBar: AppBar(
        backgroundColor: AppColors.dentistDark,
        automaticallyImplyLeading: false,
        title: const Text('My Schedule', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          if (pending > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Stack(alignment: Alignment.topRight, children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                  onPressed: () {},
                  tooltip: '$pending pending',
                ),
                Positioned(
                  right: 8, top: 8,
                  child: Container(
                    width: 18, height: 18,
                    decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                    child: Center(
                      child: Text('$pending',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ]),
            ),
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _loadAppointments),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.dentist))
          : RefreshIndicator(
              onRefresh: _loadAppointments,
              color: AppColors.dentist,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Summary banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.dentistDark, AppColors.dentistAccent]),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(children: [
                      const Icon(Icons.today, color: Colors.white, size: 32),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Today', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        Text('${_todayAppts.length} appointment${_todayAppts.length != 1 ? 's' : ''}',
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                        Text(DateTime.now().toString().substring(0, 10),
                            style: const TextStyle(color: Colors.white60, fontSize: 12)),
                      ])),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('${_upcomingAppts.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                        const Text('Upcoming', style: TextStyle(color: Colors.white60, fontSize: 11)),
                        if (pending > 0) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(10)),
                            child: Text('$pending pending',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 20),

                  // Pending approvals alert
                  if (pending > 0)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.orange.withOpacity(0.4)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.pending_actions, color: Colors.orange),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('$pending Appointment${pending > 1 ? 's' : ''} Pending Approval',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                          const Text('Tap an appointment to confirm or update status',
                              style: TextStyle(fontSize: 12, color: AppColors.textLight)),
                        ])),
                      ]),
                    ),

                  // Today
                  const SectionHeader(title: "Today's Appointments", icon: Icons.schedule, color: AppColors.dentist),
                  if (_todayAppts.isEmpty)
                    AppCard(child: Row(children: [
                      const Icon(Icons.event_available, color: AppColors.textLight),
                      const SizedBox(width: 12),
                      const Text('No appointments today — enjoy your day!',
                          style: TextStyle(color: AppColors.textLight)),
                    ]))
                  else
                    ..._todayAppts.map((a) => _buildApptCard(a, isToday: true)),

                  const SizedBox(height: 20),

                  // Upcoming
                  const SectionHeader(title: 'Upcoming Appointments', icon: Icons.calendar_month, color: AppColors.dentist),
                  if (_upcomingAppts.isEmpty)
                    AppCard(child: Row(children: [
                      const Icon(Icons.calendar_today, color: AppColors.textLight),
                      const SizedBox(width: 12),
                      const Text('No upcoming appointments', style: TextStyle(color: AppColors.textLight)),
                    ]))
                  else
                    ..._upcomingAppts.map((a) => _buildApptCard(a, isToday: false)),

                  const SizedBox(height: 80),
                ]),
              ),
            ),
    );
  }

  Widget _buildApptCard(Map<String, dynamic> a, {required bool isToday}) {
    final status = (a['status'] ?? 'pending').toString();
    final sColor = _statusColor(status);
    final date = a['appointment_date']?.toString().substring(0, 10) ?? '';
    final time = a['appointment_time']?.toString() ?? '';
    final patientName = a['patient_name'] ?? 'Patient';
    final notes = a['notes'] ?? a['reason'] ?? '';
    final isPending = status == 'pending';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: () => _showApptOptions(a),
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 4, height: 56,
            decoration: BoxDecoration(
              color: isPending ? Colors.orange : (isToday ? AppColors.dentist : Colors.grey.shade400),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(patientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.calendar_today, size: 12, color: AppColors.textLight),
              const SizedBox(width: 4),
              Text('$date at $time', style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
            ]),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(notes, style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ])),
          Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: sColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(status, style: TextStyle(color: sColor, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 4),
            const Icon(Icons.more_vert, color: AppColors.textLight, size: 18),
          ]),
        ]),
      ),
    );
  }
}