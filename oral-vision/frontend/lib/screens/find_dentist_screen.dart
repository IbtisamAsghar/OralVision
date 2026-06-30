import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/colors.dart';
import '../utils/appointment_utils.dart';

class FindDentistScreen extends StatefulWidget {
  const FindDentistScreen({super.key});

  @override
  State<FindDentistScreen> createState() => _FindDentistScreenState();
}

class _FindDentistScreenState extends State<FindDentistScreen> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All';
  bool _isLoading = true;
  List<Map<String, dynamic>> _dentists = [];

  final List<String> _filters = [
    'All',
    'General Dentist',
    'Orthodontist',
    'Periodontist',
    'Endodontist',
    'Oral Surgeon',
    'Pediatric Dentist',
    'Prosthodontist',
  ];

  @override
  void initState() {
    super.initState();
    _loadDentists();
  }

  Future<void> _loadDentists() async {
    try {
      final dentistProfiles = await _supabase.from('dentist_profiles').select(
          'user_id, clinic_name, specialization, city, experience_years, license_number');

      List<dynamic> profiles = [];
      try {
        profiles = await _supabase
            .from('profiles')
            .select('id, full_name, phone, role')
            .eq('role', 'dentist');
      } catch (_) {
        profiles = await _supabase
            .from('profiles')
            .select('id, full_name, phone, role');
      }

      final today = DateTime.now().toIso8601String().substring(0, 10);
      final appointments = await _supabase
          .from('appointments')
          .select('dentist_id, appointment_time, status')
          .eq('appointment_date', today)
          .neq('status', 'cancelled');

      final bookedByDentist = <String, Set<String>>{};
      for (final row in appointments as List) {
        final id = row['dentist_id'] as String;
        bookedByDentist.putIfAbsent(id, () => {});
        bookedByDentist[id]!.add(row['appointment_time'] as String);
      }

      final profileMap = <String, Map<String, dynamic>>{};
      for (final p in profiles) {
        profileMap[p['id'] as String] = Map<String, dynamic>.from(p);
      }

      final now = DateTime.now();
      final merged = (dentistProfiles as List).map((extra) {
        final userId = extra['user_id'] as String;
        final profile = profileMap[userId] ?? {};

        final availableSlots = AppointmentUtils.availableSlots(
          selectedDate: now,
          bookedSlots: bookedByDentist[userId] ?? {},
          now: now,
        );

        return {
          'id': userId,
          'full_name': profile['full_name'] ?? 'Dentist',
          'phone': profile['phone'] ?? '',
          'clinic_name': extra['clinic_name'] ?? 'Dental Clinic',
          'specialization': extra['specialization'] ?? 'General Dentist',
          'city': extra['city'] ?? 'Not specified',
          'experience_years': extra['experience_years'] ?? 0,
          'license_number': extra['license_number'] ?? '',
          'available': availableSlots.isNotEmpty,
          'available_slots_today': availableSlots.length,
          'rating': 4.5 + (userId.hashCode.abs() % 5) / 10,
          'about':
              'Experienced ${extra['specialization'] ?? 'dental specialist'} with ${extra['experience_years'] ?? 0}+ years serving patients at ${extra['clinic_name'] ?? 'our clinic'}.',
          'services': _servicesFor(extra['specialization'] ?? 'General Dentist'),
        };
      }).toList();

      setState(() {
        _dentists = List<Map<String, dynamic>>.from(merged);
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Could not load dentists. Pull to refresh.';
      });
    }
  }

  List<String> _servicesFor(String spec) {
    switch (spec) {
      case 'Orthodontist':
        return ['Braces', 'Aligners', 'Bite Correction'];
      case 'Periodontist':
        return ['Gum Treatment', 'Deep Cleaning', 'Graft Surgery'];
      case 'Endodontist':
        return ['Root Canal', 'Pulp Therapy', 'Apicoectomy'];
      case 'Oral Surgeon':
        return ['Extractions', 'Implants', 'Jaw Surgery'];
      case 'Pediatric Dentist':
        return ['Child Check-ups', 'Fluoride Treatment', 'Sealants'];
      case 'Prosthodontist':
        return ['Crowns', 'Dentures', 'Bridges'];
      default:
        return ['Check-ups', 'Fillings', 'Cleaning', 'X-rays'];
    }
  }

  String? _error;

  List<Map<String, dynamic>> get _filteredDentists {
    return _dentists.where((d) {
      final spec = d['specialization'] as String;
      final matchesFilter = _selectedFilter == 'All' || spec == _selectedFilter;
      final q = _searchQuery.toLowerCase();
      final matchesSearch = q.isEmpty ||
          (d['full_name'] as String).toLowerCase().contains(q) ||
          spec.toLowerCase().contains(q) ||
          (d['city'] as String).toLowerCase().contains(q) ||
          (d['clinic_name'] as String).toLowerCase().contains(q);
      return matchesFilter && matchesSearch;
    }).toList();
  }

  void _openDetail(Map<String, dynamic> dentist) {
    Navigator.pushNamed(
      context,
      '/dentist-detail',
      arguments: dentist,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: AppColors.patient,
        elevation: 0,
        title: const Text(
          'Find Dental Specialists',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.patient,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: const InputDecoration(
                      hintText: 'Search by name, specialty or city...',
                      prefixIcon: Icon(Icons.search, color: AppColors.patient),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedFilter = filter),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.patient
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        filter,
                        style: TextStyle(
                          color:
                              isSelected ? Colors.white : AppColors.textLight,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Text(
                  '${_filteredDentists.length} specialists found',
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _loadDentists,
                  icon: const Icon(Icons.refresh, color: AppColors.patient),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredDentists.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off,
                                size: 60, color: AppColors.textLight),
                            const SizedBox(height: 12),
                            Text(
                              _error ?? 'No specialists found',
                              style: const TextStyle(color: AppColors.textLight),
                              textAlign: TextAlign.center,
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _loadDentists,
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.patient),
                                child: const Text('Retry',
                                    style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredDentists.length,
                        itemBuilder: (context, index) {
                          final d = _filteredDentists[index];
                          return _DentistCard(
                            dentist: d,
                            onTap: () => _openDetail(d),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _DentistCard extends StatelessWidget {
  final Map<String, dynamic> dentist;
  final VoidCallback onTap;

  const _DentistCard({required this.dentist, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isAvailable = dentist['available'] as bool;
    final slots = dentist['available_slots_today'] as int;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.patient.withValues(alpha: 0.15),
                          AppColors.accent.withValues(alpha: 0.15),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        (dentist['full_name'] as String)[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.patient,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Dr. ${dentist['full_name']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isAvailable
                                    ? AppColors.patient.withValues(alpha: 0.12)
                                    : AppColors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isAvailable ? 'Available' : 'Fully Booked',
                                style: TextStyle(
                                  color: isAvailable
                                      ? AppColors.patient
                                      : AppColors.error,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dentist['specialization'],
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dentist['clinic_name'],
                          style: const TextStyle(
                            color: AppColors.textLight,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          dentist['city'],
                          style: const TextStyle(
                            color: AppColors.textLight,
                            fontSize: 12,
                          ),
                        ),
                        if (isAvailable) ...[
                          const SizedBox(height: 6),
                          Text(
                            '$slots slot${slots == 1 ? '' : 's'} available today',
                            style: const TextStyle(
                              color: AppColors.patient,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onTap,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.patient,
                        side: const BorderSide(color: AppColors.patient),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('View Profile'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isAvailable
                          ? () {
                              Navigator.pushNamed(
                                context,
                                '/book-appointment',
                                arguments: {'dentistId': dentist['id']},
                              );
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.patient,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Book Now',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
