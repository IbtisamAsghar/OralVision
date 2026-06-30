import 'package:flutter/material.dart';
import '../utils/colors.dart';
import '../utils/navigation_utils.dart';
import 'patient_home_screen.dart';
import 'history_screen.dart';
import 'patient_appointments_screen.dart';
import 'patient_profile_screen.dart';

class PatientShell extends StatefulWidget {
  const PatientShell({super.key});
  @override
  State<PatientShell> createState() => _PatientShellState();
}

class _PatientShellState extends State<PatientShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return authShell(
      child: Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          PatientHomeScreen(),
          HistoryScreen(),
          PatientAppointmentsScreen(),
          _ProfileSettingsWrapper(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home', index: 0, currentIndex: _currentIndex, color: AppColors.patient, onTap: () => setState(() => _currentIndex = 0)),
                _NavItem(icon: Icons.history_outlined, activeIcon: Icons.history, label: 'History', index: 1, currentIndex: _currentIndex, color: AppColors.patient, onTap: () => setState(() => _currentIndex = 1)),
                _NavItem(icon: Icons.calendar_month_outlined, activeIcon: Icons.calendar_month, label: 'Appointments', index: 2, currentIndex: _currentIndex, color: AppColors.patient, onTap: () => setState(() => _currentIndex = 2)),
                _NavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile', index: 3, currentIndex: _currentIndex, color: AppColors.patient, onTap: () => setState(() => _currentIndex = 3)),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _ProfileSettingsWrapper extends StatelessWidget {
  const _ProfileSettingsWrapper();

  @override
  Widget build(BuildContext context) {
    return const PatientProfileScreen();
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int currentIndex;
  final Color color;
  final VoidCallback onTap;

  const _NavItem({required this.icon, required this.activeIcon, required this.label, required this.index, required this.currentIndex, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isActive = index == currentIndex;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isActive ? activeIcon : icon, color: isActive ? color : Colors.grey, size: 24),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: isActive ? FontWeight.bold : FontWeight.normal, color: isActive ? color : Colors.grey)),
          ],
        ),
      ),
    );
  }
}
