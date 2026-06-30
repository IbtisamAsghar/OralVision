import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/colors.dart';
import '../widgets/section_header.dart';
import '../utils/appointment_utils.dart';
import '../widgets/app_card.dart';

class DentistDetailScreen extends StatefulWidget {
  const DentistDetailScreen({super.key});

  @override
  State<DentistDetailScreen> createState() => _DentistDetailScreenState();
}

class _DentistDetailScreenState extends State<DentistDetailScreen> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _dentist;
  List<String> _availableSlots = [];
  bool _loadingSlots = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _dentist ??=
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    if (_dentist == null) return;

    setState(() => _loadingSlots = true);
    try {
      final today = DateTime.now();
      final dateStr = today.toIso8601String().substring(0, 10);

      final booked = await _supabase
          .from('appointments')
          .select('appointment_time')
          .eq('dentist_id', _dentist!['id'])
          .eq('appointment_date', dateStr)
          .neq('status', 'cancelled');

      final bookedSlots = (booked as List)
          .map((r) => r['appointment_time'] as String)
          .toSet();

      setState(() {
        _availableSlots = AppointmentUtils.availableSlots(
          selectedDate: today,
          bookedSlots: bookedSlots,
        );
      });
    } catch (_) {
      setState(() => _availableSlots = []);
    } finally {
      setState(() => _loadingSlots = false);
    }
  }

  Future<void> _callDentist(String? phone) async {
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number not available')),
      );
      return;
    }
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  Future<void> _openMaps() async {
    final query = Uri.encodeComponent(
      '${_dentist!['clinic_name']} ${_dentist!['city']}',
    );
    final url = Uri.parse('https://www.google.com/maps/search/$query');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dentist == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dentist Profile')),
        body: const Center(child: Text('Dentist not found')),
      );
    }

    final d = _dentist!;
    final isAvailable = _availableSlots.isNotEmpty;
    final rating = (d['rating'] as num?)?.toDouble() ?? 4.7;
    final services = (d['services'] as List?)?.cast<String>() ??
        ['Check-ups', 'Fillings', 'Cleaning'];
    final about = d['about']?.toString() ??
        'Experienced dental professional committed to quality oral care.';

    return Scaffold(
      backgroundColor: AppColors.patientBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: AppColors.patientDark,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.patientDark, AppColors.patientAccent],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                              ),
                              child: CircleAvatar(
                                radius: 40,
                                backgroundColor: Colors.white,
                                child: Text(
                                  (d['full_name'] as String)[0].toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.patientDark,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Dr. ${d['full_name']}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    d['specialization'],
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 14),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.star,
                                          color: Colors.amber, size: 18),
                                      Text(
                                        ' ${rating.toStringAsFixed(1)}',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(width: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.2),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.verified,
                                                color: Colors.white, size: 14),
                                            SizedBox(width: 4),
                                            Text('Verified',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isAvailable
                                ? Colors.green.withValues(alpha: 0.3)
                                : Colors.red.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isAvailable
                                ? '${_availableSlots.length} slots available today'
                                : 'Fully booked today — book a future date',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(
                          title: 'About Doctor',
                          icon: Icons.info_outline,
                          color: AppColors.patient,
                        ),
                        Text(about,
                            style: const TextStyle(
                                height: 1.5, color: AppColors.textDark)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(
                          title: 'Clinic Information',
                          icon: Icons.local_hospital,
                          color: AppColors.patient,
                        ),
                        _InfoRow(Icons.business, 'Clinic', d['clinic_name']),
                        _InfoRow(Icons.location_city, 'City', d['city']),
                        _InfoRow(Icons.work_history, 'Experience',
                            '${d['experience_years']} years'),
                        if ((d['license_number'] as String).isNotEmpty)
                          _InfoRow(
                              Icons.badge, 'License', d['license_number']),
                        if ((d['phone'] as String).isNotEmpty)
                          _InfoRow(Icons.phone, 'Phone', d['phone']),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(
                          title: 'Services Offered',
                          icon: Icons.medical_services,
                          color: AppColors.patient,
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: services
                              .map(
                                (s) => Chip(
                                  label: Text(s),
                                  backgroundColor: AppColors.patient
                                      .withValues(alpha: 0.1),
                                  labelStyle: const TextStyle(
                                      color: AppColors.patientDark,
                                      fontWeight: FontWeight.w600),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(
                          title: 'Available Time Slots Today',
                          icon: Icons.schedule,
                          color: AppColors.patient,
                        ),
                        if (_loadingSlots)
                          const Center(child: CircularProgressIndicator())
                        else if (_availableSlots.isEmpty)
                          const Text(
                            'No slots left today. Book for a future date.',
                            style: TextStyle(color: AppColors.textLight),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _availableSlots
                                .map(
                                  (slot) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppColors.patient
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: AppColors.patient
                                              .withValues(alpha: 0.3)),
                                    ),
                                    child: Text(slot,
                                        style: const TextStyle(
                                            color: AppColors.patientDark,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                )
                                .toList(),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(
                          title: 'Patient Reviews',
                          icon: Icons.rate_review,
                          color: AppColors.patient,
                        ),
                        _ReviewTile(
                            'Excellent care and very professional.',
                            rating),
                        _ReviewTile(
                            'Quick appointment and helpful advice.', rating - 0.2),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _openMaps,
                          icon: const Icon(Icons.map),
                          label: const Text('Directions'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.patient,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _callDentist(d['phone']),
                          icon: const Icon(Icons.phone),
                          label: const Text('Call Now'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.patientAccent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          '/book-appointment',
                          arguments: {'dentistId': d['id']},
                        );
                      },
                      icon: const Icon(Icons.calendar_month, color: Colors.white),
                      label: const Text(
                        'Book Appointment',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.patient,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textLight),
          const SizedBox(width: 10),
          Text('$label: ',
              style: const TextStyle(color: AppColors.textLight, fontSize: 13)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final String text;
  final double rating;

  const _ReviewTile(this.text, this.rating);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.patient.withValues(alpha: 0.15),
            child: const Icon(Icons.person, size: 18, color: AppColors.patient),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < rating.round() ? Icons.star : Icons.star_border,
                      size: 14,
                      color: Colors.amber,
                    ),
                  ),
                ),
                Text(text,
                    style: const TextStyle(fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

