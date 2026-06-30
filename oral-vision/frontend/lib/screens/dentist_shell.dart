import 'package:flutter/material.dart';
import '../utils/colors.dart';
import '../utils/navigation_utils.dart';
import 'dentist_dashboard.dart';
import 'dentist_schedule_screen.dart';
import 'dentist_patients_screen.dart';
import 'dentist_profile_screen.dart';

class DentistShell extends StatefulWidget {
  const DentistShell({super.key});
  @override
  State<DentistShell> createState() => _DentistShellState();
}

class _DentistShellState extends State<DentistShell> {
  int _currentIndex = 0;

  final _pages = const [
    DentistDashboard(),
    DentistScheduleScreen(),
    DentistPatientsScreen(),
    DentistProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return authShell(
      child: Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.dentist,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: 'Schedule',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Patients',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
      ),
    );
  }
}