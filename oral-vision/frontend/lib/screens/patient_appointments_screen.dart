import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/colors.dart';
import '../widgets/app_card.dart';

class PatientAppointmentsScreen extends StatefulWidget {
  const PatientAppointmentsScreen({super.key});

  @override
  State<PatientAppointmentsScreen> createState() =>
      _PatientAppointmentsScreenState();
}

class _PatientAppointmentsScreenState extends State<PatientAppointmentsScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _upcoming = [];
  List<Map<String, dynamic>> _past = [];
  bool _isLoading = true;
  String? _error;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAppointments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAppointments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          _error = 'Please log in to view appointments.';
          _isLoading = false;
        });
        return;
      }

      List rows;
      try {
        rows = await _supabase
            .from('appointments')
            .select('*, profiles!appointments_dentist_id_fkey(full_name, phone)')
            .eq('patient_id', user.id)
            .order('appointment_date', ascending: true);
      } catch (_) {
        rows = await _supabase
            .from('appointments')
            .select()
            .eq('patient_id', user.id)
            .order('appointment_date', ascending: true);
      }

      final dentistIds = (rows as List)
          .map((r) => r['dentist_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();

      final dentistProfileMap = <String, Map<String, dynamic>>{};
      if (dentistIds.isNotEmpty) {
        try {
          final profiles = await _supabase
              .from('profiles')
              .select('id, full_name, phone')
              .inFilter('id', dentistIds);
          for (final p in profiles as List) {
            dentistProfileMap[p['id'] as String] =
                Map<String, dynamic>.from(p);
          }
        } catch (_) {}

        try {
          final dpRows = await _supabase
              .from('dentist_profiles')
              .select('user_id, clinic_name, specialization')
              .inFilter('user_id', dentistIds);
          for (final dp in dpRows as List) {
            final id = dp['user_id'] as String;
            dentistProfileMap.putIfAbsent(id, () => {});
            dentistProfileMap[id]!.addAll(Map<String, dynamic>.from(dp));
          }
        } catch (_) {}
      }

      final today = DateTime.now();
      final upcoming = <Map<String, dynamic>>[];
      final past = <Map<String, dynamic>>[];

      for (final row in rows) {
        final map = Map<String, dynamic>.from(row);
        final dentistId = map['dentist_id'] as String?;
        if (dentistId != null && dentistProfileMap.containsKey(dentistId)) {
          map['_dentist'] = dentistProfileMap[dentistId];
        }
        final dateStr = map['appointment_date']?.toString() ?? '';
        final timeStr = map['appointment_time']?.toString() ?? '';
        final dt = _parseAppointmentDateTime(dateStr, timeStr);
        if (dt != null && dt.isBefore(today) && map['status'] != 'pending') {
          past.add(map);
        } else if (map['status'] == 'cancelled') {
          past.add(map);
        } else {
          upcoming.add(map);
        }
      }

      upcoming.sort((a, b) {
        final da = _parseAppointmentDateTime(
          a['appointment_date']?.toString() ?? '',
          a['appointment_time']?.toString() ?? '',
        );
        final db = _parseAppointmentDateTime(
          b['appointment_date']?.toString() ?? '',
          b['appointment_time']?.toString() ?? '',
        );
        if (da == null || db == null) return 0;
        return da.compareTo(db);
      });

      past.sort((a, b) {
        final da = _parseAppointmentDateTime(
          a['appointment_date']?.toString() ?? '',
          a['appointment_time']?.toString() ?? '',
        );
        final db = _parseAppointmentDateTime(
          b['appointment_date']?.toString() ?? '',
          b['appointment_time']?.toString() ?? '',
        );
        if (da == null || db == null) return 0;
        return db.compareTo(da);
      });

      setState(() {
        _upcoming = upcoming;
        _past = past;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load appointments. Pull to refresh.';
        _isLoading = false;
      });
    }
  }

  DateTime? _parseAppointmentDateTime(String dateStr, String timeStr) {
    if (dateStr.length < 10 || timeStr.isEmpty) return null;
    final dateParts = dateStr.substring(0, 10).split('-');
    if (dateParts.length != 3) return null;
    final parts = timeStr.split(' ');
    if (parts.length != 2) return null;
    final timeParts = parts[0].split(':');
    if (timeParts.length != 2) return null;
    var hour = int.tryParse(timeParts[0]) ?? 0;
    final minute = int.tryParse(timeParts[1]) ?? 0;
    final period = parts[1].toUpperCase();
    if (period == 'PM' && hour != 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
    return DateTime(
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      int.parse(dateParts[2]),
      hour,
      minute,
    );
  }

  Future<void> _cancelAppointment(String id) async {
    try {
      await _supabase
          .from('appointments')
          .update({'status': 'cancelled'})
          .eq('id', id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appointment cancelled'),
          backgroundColor: AppColors.patient,
        ),
      );
      _loadAppointments();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  String _dentistName(Map<String, dynamic> apt) {
    final profile = apt['profiles'];
    if (profile is Map && profile['full_name'] != null) {
      return profile['full_name'].toString();
    }
    final cached = apt['_dentist'];
    if (cached is Map && cached['full_name'] != null) {
      return cached['full_name'].toString();
    }
    return 'Dentist';
  }

  String _clinicName(Map<String, dynamic> apt) {
    final cached = apt['_dentist'];
    if (cached is Map && cached['clinic_name'] != null) {
      return cached['clinic_name'].toString();
    }
    return 'Dental Clinic';
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'confirmed':
        return AppColors.patient;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.patientBg,
      appBar: AppBar(
        backgroundColor: AppColors.patientDark,
        elevation: 0,
        title: const Text(
          'My Appointments',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(text: 'Upcoming (${_upcoming.length})'),
            Tab(text: 'Past (${_past.length})'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.patient,
        onPressed: () =>
            Navigator.pushNamed(context, '/book-appointment').then((_) {
          _loadAppointments();
        }),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Book New', style: TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.patient))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: AppColors.error),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadAppointments,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.patient,
                          ),
                          child: const Text('Retry',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAppointments,
                  color: AppColors.patient,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildList(_upcoming, upcoming: true),
                      _buildList(_past, upcoming: false),
                    ],
                  ),
                ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> items, {required bool upcoming}) {
    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.4,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    upcoming ? Icons.event_available : Icons.history,
                    size: 48,
                    color: AppColors.textLight,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    upcoming
                        ? 'No upcoming appointments'
                        : 'No past appointments',
                    style: const TextStyle(color: AppColors.textLight),
                  ),
                  if (upcoming) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        '/book-appointment',
                      ).then((_) => _loadAppointments()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.patient,
                      ),
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text('Book Appointment',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final apt = items[i];
        final status = apt['status']?.toString() ?? 'pending';
        final date = apt['appointment_date']?.toString().substring(0, 10) ?? '';
        final time = apt['appointment_time']?.toString() ?? '';
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor:
                          AppColors.patient.withValues(alpha: 0.15),
                      child: const Icon(Icons.person, color: AppColors.patient),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dr. ${_dentistName(apt)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            _clinicName(apt),
                            style: const TextStyle(
                              color: AppColors.textLight,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor(status).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status[0].toUpperCase() + status.substring(1),
                        style: TextStyle(
                          color: _statusColor(status),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        size: 16, color: AppColors.patient),
                    const SizedBox(width: 6),
                    Text('$date · $time',
                        style: const TextStyle(fontSize: 13)),
                  ],
                ),
                if (apt['notes'] != null &&
                    apt['notes'].toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    apt['notes'].toString(),
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (upcoming &&
                    status != 'cancelled' &&
                    status != 'completed') ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _confirmCancel(apt['id'].toString()),
                      icon: const Icon(Icons.cancel_outlined,
                          color: AppColors.error, size: 18),
                      label: const Text('Cancel',
                          style: TextStyle(color: AppColors.error)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmCancel(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Appointment?'),
        content: const Text(
          'Are you sure you want to cancel this appointment?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(ctx);
              _cancelAppointment(id);
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
