import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/colors.dart';
import '../utils/appointment_utils.dart';

class AppointmentBookingScreen extends StatefulWidget {
  const AppointmentBookingScreen({super.key});

  @override
  State<AppointmentBookingScreen> createState() => _AppointmentBookingScreenState();
}

class _AppointmentBookingScreenState extends State<AppointmentBookingScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _dentists = [];
  Map<String, dynamic>? _selectedDentist;
  DateTime? _selectedDate;
  String? _selectedTime;
  final _notesController = TextEditingController();
  bool _isLoading = true;
  bool _isBooking = false;
  bool _loadingSlots = false;
  Set<String> _bookedSlots = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDentists());
  }

  Future<void> _loadDentists() async {
    try {
      final dentistProfiles = await _supabase
          .from('dentist_profiles')
          .select('user_id, clinic_name, specialization, city, experience_years');

      List profiles = [];
      try {
        profiles = await _supabase
            .from('profiles')
            .select('id, full_name, phone, role')
            .eq('role', 'dentist');
      } catch (_) {
        profiles = await _supabase
            .from('profiles')
            .select('id, full_name, phone');
      }

      final profileMap = <String, Map<String, dynamic>>{};
      for (final p in profiles) {
        profileMap[p['id'] as String] = Map<String, dynamic>.from(p);
      }

      final merged = (dentistProfiles as List).map((dp) {
        final userId = dp['user_id'] as String;
        final profile = profileMap[userId] ?? {};
        return {
          'id': userId,
          'full_name': profile['full_name'] ?? 'Dentist',
          'phone': profile['phone'] ?? '',
          'clinic_name': dp['clinic_name'] ?? 'General Clinic',
          'specialization': dp['specialization'] ?? 'General Dentistry',
          'city': dp['city'] ?? '',
          'experience_years': dp['experience_years'] ?? 0,
        };
      }).toList();

      final args = mounted
          ? ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?
          : null;
      final preselectedId = args?['dentistId'] as String?;

      Map<String, dynamic>? preselected;
      if (preselectedId != null) {
        preselected = merged.cast<Map<String, dynamic>?>().firstWhere(
          (d) => d!['id'] == preselectedId,
          orElse: () => null,
        );
      }

      setState(() {
        _dentists = List<Map<String, dynamic>>.from(merged);
        _selectedDentist = preselected ?? (_dentists.length == 1 ? _dentists.first : null);
        _isLoading = false;
      });

      if (_selectedDentist != null && _selectedDate != null) {
        await _loadBookedSlots();
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadBookedSlots() async {
    if (_selectedDentist == null || _selectedDate == null) {
      setState(() => _bookedSlots = {});
      return;
    }
    setState(() => _loadingSlots = true);
    try {
      final dateStr = _selectedDate!.toIso8601String().substring(0, 10);
      final booked = await _supabase
          .from('appointments')
          .select('appointment_time, status')
          .eq('dentist_id', _selectedDentist!['id'])
          .eq('appointment_date', dateStr)
          .neq('status', 'cancelled');

      setState(() {
        _bookedSlots = (booked as List)
            .map((r) => r['appointment_time'] as String?)
            .whereType<String>()
            .toSet();
        if (_selectedTime != null && _bookedSlots.contains(_selectedTime)) {
          _selectedTime = null;
        }
      });
    } catch (_) {
      setState(() => _bookedSlots = {});
    } finally {
      setState(() => _loadingSlots = false);
    }
  }

  List<Map<String, dynamic>> get _allSlots =>
      AppointmentUtils.allSlotsWithStatus(
        selectedDate: _selectedDate,
        bookedSlots: _bookedSlots,
      );

  Future<void> _bookAppointment() async {
    if (_selectedDentist == null || _selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select dentist, date and time slot'),
        backgroundColor: AppColors.error,
      ));
      return;
    }
    setState(() => _isBooking = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      await _supabase.from('appointments').insert({
        'patient_id': user.id,
        'dentist_id': _selectedDentist!['id'],
        'appointment_date': _selectedDate!.toIso8601String().substring(0, 10),
        'appointment_time': _selectedTime,
        'notes': _notesController.text,
        'status': 'pending',
      });
      if (!mounted) return;
      _showSuccessDialog();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed: $e'),
        backgroundColor: AppColors.error,
      ));
    } finally {
      setState(() => _isBooking = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.patient.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: AppColors.patient, size: 48),
            ),
            const SizedBox(height: 16),
            const Text('Request Submitted!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Your appointment request with Dr. ${_selectedDentist!['full_name']} on '
              '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year} '
              'at $_selectedTime is pending. The dentist will confirm shortly.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textLight, fontSize: 13),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.patient,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Done', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: AppColors.patient,
        elevation: 0,
        title: const Text('Book Appointment',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.patient))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.patientDark, AppColors.patientAccent],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.patient.withOpacity(0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.event_available, color: Colors.white, size: 34),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Schedule Your Visit',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              Text('Only future slots shown. Booked slots are marked.',
                                  style: TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Step 1: Select Dentist
                  _sectionTitle('Step 1: Select a Dentist', Icons.person_search),
                  const SizedBox(height: 12),
                  _dentists.isEmpty
                      ? _emptyState('No dentists available')
                      : Column(
                          children: _dentists.map((dentist) {
                            final isSelected = _selectedDentist?['id'] == dentist['id'];
                            return GestureDetector(
                              onTap: () async {
                                setState(() {
                                  _selectedDentist = dentist;
                                  _selectedTime = null;
                                });
                                await _loadBookedSlots();
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.patient.withOpacity(0.08)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.patient
                                        : Colors.grey.shade200,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: isSelected
                                          ? AppColors.patient
                                          : AppColors.patient.withOpacity(0.1),
                                      child: Text(
                                        (dentist['full_name'] as String)[0].toUpperCase(),
                                        style: TextStyle(
                                          color: isSelected ? Colors.white : AppColors.patient,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Dr. ${dentist['full_name']}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: isSelected
                                                    ? AppColors.patient
                                                    : AppColors.textDark,
                                              )),
                                          Text(dentist['clinic_name'],
                                              style: const TextStyle(
                                                  color: AppColors.textLight, fontSize: 12)),
                                          Text(dentist['specialization'],
                                              style: const TextStyle(
                                                  color: AppColors.accent, fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(Icons.check_circle, color: AppColors.patient),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                  const SizedBox(height: 24),

                  // Step 2: Select Date
                  _sectionTitle('Step 2: Select Date', Icons.calendar_month),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 60)),
                        builder: (context, child) => Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(
                                primary: AppColors.patient),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        setState(() {
                          _selectedDate = picked;
                          _selectedTime = null;
                        });
                        await _loadBookedSlots();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _selectedDate != null
                              ? AppColors.patient
                              : Colors.grey.shade200,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: AppColors.patient),
                          const SizedBox(width: 12),
                          Text(
                            _selectedDate == null
                                ? 'Tap to select a date'
                                : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year} (${_weekday(_selectedDate!)})',
                            style: TextStyle(
                              color: _selectedDate == null
                                  ? AppColors.textLight
                                  : AppColors.textDark,
                              fontWeight: _selectedDate != null
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          const Spacer(),
                          const Icon(Icons.arrow_drop_down, color: AppColors.textLight),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Step 3: Time Slots
                  _sectionTitle('Step 3: Select Time Slot', Icons.access_time),
                  const SizedBox(height: 8),
                  if (_selectedDate == null)
                    _emptyState('Select a date to see available slots')
                  else if (_loadingSlots)
                    const Center(
                        child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(color: AppColors.patient)))
                  else if (_allSlots.isEmpty)
                    _emptyState('No slots available for this date. Try another day.')
                  else ...[
                    // Legend
                    Row(
                      children: [
                        _LegendChip(color: AppColors.patient, label: 'Available'),
                        const SizedBox(width: 10),
                        _LegendChip(color: Colors.grey, label: 'Booked'),
                        const SizedBox(width: 10),
                        _LegendChip(color: AppColors.patientDark, label: 'Selected', border: true),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _allSlots.map((slot) {
                        final time = slot['time'] as String;
                        final isBooked = slot['booked'] as bool;
                        final isSelected = _selectedTime == time;
                        return GestureDetector(
                          onTap: isBooked ? null : () => setState(() => _selectedTime = time),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isBooked
                                  ? Colors.grey.shade100
                                  : isSelected
                                      ? AppColors.patient
                                      : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isBooked
                                    ? Colors.grey.shade300
                                    : isSelected
                                        ? AppColors.patient
                                        : AppColors.patient.withOpacity(0.3),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  time,
                                  style: TextStyle(
                                    color: isBooked
                                        ? Colors.grey
                                        : isSelected
                                            ? Colors.white
                                            : AppColors.textDark,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                ),
                                if (isBooked)
                                  const Text('Booked',
                                      style: TextStyle(
                                          fontSize: 9,
                                          color: Colors.grey,
                                          fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Step 4: Notes
                  _sectionTitle('Step 4: Notes (Optional)', Icons.notes),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Describe your concern or symptoms...',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.patient),
                      ),
                    ),
                  ),

                  // Summary
                  if (_selectedDentist != null && _selectedDate != null && _selectedTime != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.patient.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.patient.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Appointment Summary',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.patientDark)),
                          const SizedBox(height: 10),
                          _SummaryRow(Icons.person, 'Dr. ${_selectedDentist!['full_name']}'),
                          _SummaryRow(Icons.local_hospital, _selectedDentist!['clinic_name']),
                          _SummaryRow(Icons.calendar_today,
                              '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'),
                          _SummaryRow(Icons.access_time, _selectedTime!),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 30),

                  // Confirm button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.patient,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 4,
                      ),
                      onPressed: _isBooking ? null : _bookAppointment,
                      child: _isBooking
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_outline, color: Colors.white),
                                SizedBox(width: 10),
                                Text('Confirm Appointment',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  String _weekday(DateTime d) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[d.weekday - 1];
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.patient, size: 20),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark)),
      ],
    );
  }

  Widget _emptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Center(
          child: Text(message,
              style: const TextStyle(color: AppColors.textLight))),
    );
  }
}

class _LegendChip extends StatelessWidget {
  final Color color;
  final String label;
  final bool border;
  const _LegendChip({required this.color, required this.label, this.border = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: border ? Colors.white : color,
            border: Border.all(color: color, width: border ? 2 : 0),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _SummaryRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.patient),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textDark)),
        ],
      ),
    );
  }
}




