import 'dart:io';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../utils/colors.dart';
import '../utils/health_utils.dart';
import '../widgets/app_card.dart';
import '../widgets/circular_score.dart';
import '../widgets/section_header.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  final _supabase = Supabase.instance.client;
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final PageController _tipPageController = PageController();
  int _currentTipIndex = 0;

  bool _isLoading = true;
  bool _isGeneratingPdf = false;
  String _email = '';
  String _gender = 'male';
  List<Map<String, dynamic>> _scans = [];
  List<Map<String, dynamic>> _symptoms = [];
  List<Map<String, dynamic>> _prescriptions = [];
  List<Map<String, dynamic>> _chatHistory = [];
  String? _error;

  // Tips use 'faIcon' key for FontAwesome icons, 'icon' key for regular Icons
  static const _tips = [
    {
      'faIcon': true,
      'title': 'Brush twice daily',
      'desc': 'Keep your teeth clean and healthy by brushing at least twice a day.',
      'color': Color(0xFF7C3AED),
    },
    {
      'icon': Icons.water_drop,
      'title': 'Stay Hydrated',
      'desc': 'Drinking water helps wash away food particles and bacteria.',
      'color': Color(0xFF0EA5E9),
    },
    {
      'icon': Icons.no_food,
      'title': 'Limit Sugar Intake',
      'desc': 'Sugar feeds bacteria that cause cavities. Rinse after sugary foods.',
      'color': Color(0xFFEC4899),
    },
    {
      'icon': Icons.medical_services,
      'title': 'Visit Dentist Regularly',
      'desc': 'Schedule a checkup every 6 months for optimal oral health.',
      'color': Color(0xFFF59E0B),
    },
    {
      'icon': Icons.self_improvement,
      'title': 'Reduce Stress',
      'desc': 'Stress can cause teeth grinding. Practice relaxation techniques daily.',
      'color': Color(0xFF059669),
    },
    {
      'icon': Icons.no_drinks,
      'title': 'Avoid Tobacco',
      'desc': 'Tobacco causes gum disease, tooth decay and oral cancer.',
      'color': Color(0xFFDC2626),
    },
  ];

  // Helper to build the correct icon widget for a tip
  Widget _tipIcon(Map tip, double size) {
    if (tip['faIcon'] == true) {
      return FaIcon(FontAwesomeIcons.tooth, color: Colors.white, size: size);
    }
    return Icon(tip['icon'] as IconData, color: Colors.white, size: size);
  }

  double? get _healthScore => HealthUtils.computeOralHealthScore(
      scans: _scans, symptoms: _symptoms);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _tipPageController.dispose();
    super.dispose();
  }

  String _normalizeGender(dynamic value) {
    const genders = ['male', 'female', 'other'];
    final g = (value ?? 'male').toString().toLowerCase();
    return genders.contains(g) ? g : 'male';
  }

  String get _displayGender => HealthUtils.formatGender(_gender);

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _error = null; });
    final user = _supabase.auth.currentUser;
    if (user == null) {
      setState(() { _error = 'Session expired.'; _isLoading = false; });
      return;
    }
    var profile = <String, dynamic>{'full_name': '', 'gender': 'male', 'age': 0};
    try {
      final row = await _supabase.from('profiles').select('full_name, age, gender').eq('id', user.id).maybeSingle();
      if (row != null) profile = Map<String, dynamic>.from(row);
    } catch (_) {}

    var scans = <Map<String, dynamic>>[];
    var symptoms = <Map<String, dynamic>>[];
    var prescriptions = <Map<String, dynamic>>[];
    var chatHistory = <Map<String, dynamic>>[];

    try {
      final rows = await _supabase.from('scan_history').select().eq('user_id', user.id).order('scanned_at', ascending: false).limit(20);
      scans = List<Map<String, dynamic>>.from(rows);
    } catch (_) {}
    try {
      final rows = await _supabase.from('symptom_history').select().eq('user_id', user.id).order('checked_at', ascending: false).limit(20);
      symptoms = List<Map<String, dynamic>>.from(rows);
    } catch (_) {}
    try {
      final rows = await _supabase.from('prescriptions').select().eq('patient_id', user.id).order('created_at', ascending: false);
      prescriptions = List<Map<String, dynamic>>.from(rows);
    } catch (_) {}
    try {
      final rows = await _supabase.from('chatbot_history').select().eq('user_id', user.id).order('sent_at', ascending: false).limit(20);
      chatHistory = List<Map<String, dynamic>>.from(rows);
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _nameController.text = profile['full_name']?.toString() ?? '';
      _ageController.text = profile['age']?.toString() ?? '';
      _email = user.email ?? '';
      _gender = _normalizeGender(profile['gender']);
      _scans = scans;
      _symptoms = symptoms;
      _prescriptions = prescriptions;
      _chatHistory = chatHistory;
      _isLoading = false;
    });
  }

  Future<void> _generateReport() async {
    setState(() => _isGeneratingPdf = true);
    try {
      final pdf = pw.Document();
      final score = _healthScore;
      final name = _nameController.text.isNotEmpty ? _nameController.text : 'Patient';
      final age = _ageController.text;
      final now = DateTime.now();
      final dateStr = '${now.day}/${now.month}/${now.year}';
      final aiChatMessages = _chatHistory.where((m) => m['role'] == 'assistant').toList();

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 12),
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromInt(0xFF0F6E56), width: 2))),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('OralVision', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF0F6E56))),
              pw.Text('Oral Health Report', style: pw.TextStyle(fontSize: 12, color: PdfColor.fromInt(0xFF546E7A))),
            ]),
            pw.Text('Generated: $dateStr', style: pw.TextStyle(fontSize: 10, color: PdfColor.fromInt(0xFF546E7A))),
          ]),
        ),
        build: (context) => [
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFF4FBF8), borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('Patient Information', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF0F6E56))),
              pw.SizedBox(height: 8),
              pw.Text('Name: $name'),
              pw.Text('Age: ${age.isNotEmpty ? '$age years' : 'N/A'}'),
              pw.Text('Gender: $_displayGender'),
              pw.Text('Email: $_email'),
            ]),
          ),
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFF4FBF8), borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('Oral Health Score', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF0F6E56))),
              pw.SizedBox(height: 8),
              pw.Text(score != null ? 'Score: ${score.toStringAsFixed(1)} / 100  |  Status: ${HealthUtils.riskFromScore(score)}' : 'No score data available yet.'),
            ]),
          ),
          pw.SizedBox(height: 16),
          pw.Text('Scan History', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF0F6E56))),
          pw.SizedBox(height: 8),
          if (_scans.isEmpty)
            pw.Text('No scan records found.', style: pw.TextStyle(color: PdfColor.fromInt(0xFF546E7A)))
          else
            ..._scans.map((scan) {
              final disease = HealthUtils.diseaseFromScan(scan);
              final risk = HealthUtils.riskFromDisease(disease);
              final date = scan['scanned_at']?.toString().substring(0, 10) ?? 'Unknown';
              final confidence = ((scan['confidence_score'] as num?)?.toDouble() ?? 0) * 100;
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 8),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColor.fromInt(0xFFE1F5EE)), borderRadius: pw.BorderRadius.circular(6)),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('Result: $disease', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('Date: $date  |  Risk: $risk  |  Confidence: ${confidence.toStringAsFixed(0)}%'),
                  pw.Text('AI Notes: ${HealthUtils.scanAiNotes(scan)}', style: pw.TextStyle(fontSize: 10, color: PdfColor.fromInt(0xFF546E7A))),
                ]),
              );
            }),
          pw.SizedBox(height: 16),
          pw.Text('Symptom Check History', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF0F6E56))),
          pw.SizedBox(height: 8),
          if (_symptoms.isEmpty)
            pw.Text('No symptom check records found.', style: pw.TextStyle(color: PdfColor.fromInt(0xFF546E7A)))
          else
            ..._symptoms.map((sym) {
              final disease = HealthUtils.diseaseFromSymptom(sym);
              final risk = HealthUtils.riskFromDisease(disease);
              final confidence = ((sym['confidence_score'] as num?)?.toDouble() ?? 0) * 100;
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 8),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColor.fromInt(0xFFE1F5EE)), borderRadius: pw.BorderRadius.circular(6)),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('Result: $disease', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('Risk: $risk  |  Confidence: ${confidence.toStringAsFixed(0)}%'),
                  pw.Text('AI Notes: ${HealthUtils.symptomAiNotes(sym)}', style: pw.TextStyle(fontSize: 10, color: PdfColor.fromInt(0xFF546E7A))),
                ]),
              );
            }),
          if (_prescriptions.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text('Dentist Prescriptions', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF0F6E56))),
            pw.SizedBox(height: 8),
            ..._prescriptions.map((rx) {
              final date = rx['created_at']?.toString().substring(0, 10) ?? 'Unknown';
              final medicines = (rx['medicines'] as List<dynamic>?) ?? [];
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColor.fromInt(0xFFE1F5EE)), borderRadius: pw.BorderRadius.circular(6)),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('Dr. ${rx['dentist_name'] ?? 'Unknown'}  |  $date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  if ((rx['note'] ?? '').toString().isNotEmpty) pw.Text('Note: ${rx['note']}'),
                  if (medicines.isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    pw.Text('Medicines:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    ...medicines.map((m) {
                      final med = m as Map<String, dynamic>;
                      return pw.Text('• ${med['name']} ${med['dosage']} — ${med['frequency']} for ${med['duration']}', style: pw.TextStyle(fontSize: 10));
                    }),
                  ],
                ]),
              );
            }),
          ],
          if (aiChatMessages.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text('AI Chatbot Advice', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF0F6E56))),
            pw.SizedBox(height: 8),
            ...aiChatMessages.take(10).map((msg) => pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 8),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFF0FAF5), border: pw.Border.all(color: PdfColor.fromInt(0xFFB2DFDB)), borderRadius: pw.BorderRadius.circular(6)),
              child: pw.Text(msg['message']?.toString() ?? '', style: pw.TextStyle(fontSize: 10)),
            )),
          ],
          pw.SizedBox(height: 24),
          pw.Divider(),
          pw.Text('Generated by OralVision. Consult your dentist for professional advice.', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF546E7A))),
        ],
      ));

      final bytes = await pdf.save();
      final dir = await getExternalStorageDirectory();
      final filePath = '${dir!.path}/OralVision_Report_${now.day}_${now.month}_${now.year}.pdf';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            const Expanded(child: Text('Report saved successfully!')),
            TextButton(
              onPressed: () => OpenFile.open(filePath),
              child: const Text('OPEN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ]),
          backgroundColor: AppColors.patient,
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  Color _riskColor(String risk) {
    switch (risk.toLowerCase()) {
      case 'high': return AppColors.riskHigh;
      case 'medium': return AppColors.riskMedium;
      default: return AppColors.riskLow;
    }
  }

  Widget _buildHeroHeader() {
    final score = _healthScore;
    final status = score != null ? HealthUtils.riskFromScore(score) : 'No data yet';
    final age = int.tryParse(_ageController.text) ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5B21B6), Color(0xFF7C3AED), Color(0xFFEC4899)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: const Color(0xFF7C3AED).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(children: [
        Row(children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8)],
            ),
            child: CircleAvatar(
              radius: 36,
              backgroundColor: Colors.white,
              child: Text(
                _nameController.text.isNotEmpty ? _nameController.text[0].toUpperCase() : 'P',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF5B21B6)),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Welcome back', style: TextStyle(color: Colors.white70, fontSize: 12)),
            Text(
              _nameController.text.isNotEmpty ? _nameController.text : 'Patient',
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              age > 0 ? '$age yrs · $_displayGender · $_email' : '$_displayGender · $_email',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ])),
          if (score != null) CircularScore(score: score, size: 70),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white38),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.favorite, color: Colors.white70, size: 14),
            const SizedBox(width: 6),
            Text('Health Status: $status',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildStatCards() {
    return Row(children: [
      _statCard('Scans', '${_scans.length}', Icons.camera_alt, const Color(0xFF7C3AED)),
      const SizedBox(width: 10),
      _statCard('Symptoms', '${_symptoms.length}', Icons.psychology, const Color(0xFFEC4899)),
      const SizedBox(width: 10),
      _statCard('Prescriptions', '${_prescriptions.length}', Icons.medical_services, const Color(0xFFF59E0B)),
    ]);
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
        ]),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Quick Actions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark)),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.4,
        children: [
          _actionTile(Icons.camera_alt, 'New Scan', '/scan', const Color(0xFF7C3AED)),
          _actionTile(Icons.psychology, 'Symptom Check', '/symptom-checker', const Color(0xFFEC4899)),
          _actionTile(Icons.search, 'Find Dentist', '/find-dentist', const Color(0xFF0EA5E9)),
          _actionTile(Icons.smart_toy, 'AI Chatbot', '/chatbot', const Color(0xFFF59E0B)),
        ],
      ),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: _isGeneratingPdf ? null : _generateReport,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5B21B6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 2,
          ),
          icon: _isGeneratingPdf
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.picture_as_pdf, color: Colors.white),
          label: Text(
            _isGeneratingPdf ? 'Generating...' : 'Generate Health Report',
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    ]);
  }

  Widget _actionTile(IconData icon, String label, String route, Color color) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Flexible(child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12))),
        ]),
      ),
    );
  }

  // ── Oral Health Tips ────────────────────────────────────────────────────────

  Widget _buildDentalTips() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Oral Health Tips',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark)),
        GestureDetector(
          onTap: _showAllTipsSheet,
          child: const Text('View All',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
        ),
      ]),
      const SizedBox(height: 12),
      Container(
        height: 170,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Stack(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: PageView.builder(
              controller: _tipPageController,
              itemCount: _tips.length,
              onPageChanged: (i) => setState(() => _currentTipIndex = i),
              itemBuilder: (ctx, i) {
                final tip = _tips[i];
                final color = tip['color'] as Color;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
                  child: Row(children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color, color.withOpacity(0.55)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: Center(child: _tipIcon(tip, 32)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(tip['title'] as String,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
                        const SizedBox(height: 6),
                        Text(tip['desc'] as String,
                            style: const TextStyle(fontSize: 12, color: AppColors.textLight, height: 1.4),
                            maxLines: 3, overflow: TextOverflow.ellipsis),
                      ],
                    )),
                  ]),
                );
              },
            ),
          ),
          // Left arrow
          Positioned(
            left: 6, top: 0, bottom: 28,
            child: Center(
              child: _currentTipIndex > 0
                  ? GestureDetector(
                      onTap: () => _tipPageController.previousPage(
                          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                      child: Container(
                        width: 28, height: 28,
                        decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                        child: const Icon(Icons.chevron_left, color: Colors.white, size: 20),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          // Right arrow
          Positioned(
            right: 6, top: 0, bottom: 28,
            child: Center(
              child: _currentTipIndex < _tips.length - 1
                  ? GestureDetector(
                      onTap: () => _tipPageController.nextPage(
                          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                      child: Container(
                        width: 28, height: 28,
                        decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                        child: const Icon(Icons.chevron_right, color: Colors.white, size: 20),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          // Dot indicators
          Positioned(
            bottom: 10, left: 0, right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_tips.length, (i) {
                final color = _tips[i]['color'] as Color;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _currentTipIndex ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _currentTipIndex ? color : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
        ]),
      ),
    ]);
  }

  void _showAllTipsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      backgroundColor: Colors.white,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, controller) => Column(children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('All Oral Health Tips', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textDark)),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: _tips.length,
              itemBuilder: (_, i) {
                final tip = _tips[i];
                final color = tip['color'] as Color;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withOpacity(0.25)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [color, color.withOpacity(0.6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        shape: BoxShape.circle,
                      ),
                      child: Center(child: _tipIcon(tip, 24)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(tip['title'] as String,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
                      const SizedBox(height: 4),
                      Text(tip['desc'] as String,
                          style: const TextStyle(fontSize: 12, color: AppColors.textLight, height: 1.4)),
                    ])),
                  ]),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  // ── Health Reminders ────────────────────────────────────────────────────────

  void _showRemindersSheet() {
    final score = _healthScore;
    final reminders = <Map<String, dynamic>>[];

    if (_scans.isEmpty) reminders.add({'icon': Icons.camera_alt, 'msg': 'No scans yet — take your first AI scan!', 'color': const Color(0xFF7C3AED), 'route': '/scan'});
    if (_symptoms.isEmpty) reminders.add({'icon': Icons.psychology, 'msg': 'Check your symptoms for early detection.', 'color': const Color(0xFF0EA5E9), 'route': '/symptom-checker'});
    if (_prescriptions.isEmpty) reminders.add({'icon': Icons.calendar_month, 'msg': 'Book your next dental appointment.', 'color': const Color(0xFFF59E0B), 'route': '/find-dentist'});
    if (score != null && score < 60) reminders.add({'icon': Icons.warning_amber, 'msg': 'Your health score is low. See a dentist soon.', 'color': AppColors.error, 'route': '/find-dentist'});
    if (reminders.isEmpty) reminders.add({'icon': Icons.verified, 'msg': 'Great job! Keep up your oral hygiene routine.', 'color': const Color(0xFF059669), 'route': null});

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      backgroundColor: Colors.white,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Row(children: [
            const Icon(Icons.notifications, color: Color(0xFF7C3AED), size: 22),
            const SizedBox(width: 8),
            const Text('Health Reminders', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
          ]),
          const SizedBox(height: 8),
          ...reminders.map((r) => GestureDetector(
            onTap: () {
              Navigator.pop(ctx);
              if (r['route'] != null) Navigator.pushNamed(context, r['route'] as String);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: (r['color'] as Color).withOpacity(0.2)),
                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.06), blurRadius: 8)],
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: (r['color'] as Color).withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                  child: Icon(r['icon'] as IconData, color: r['color'] as Color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(r['msg'] as String, style: const TextStyle(fontSize: 13, color: AppColors.textDark))),
                if (r['route'] != null) Icon(Icons.chevron_right, color: r['color'] as Color, size: 18),
              ]),
            ),
          )),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.patientBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF5B21B6),
        automaticallyImplyLeading: false,
        title: const Text('Home', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: _showRemindersSheet,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)))
          : _error != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                  const SizedBox(height: 12),
                  Text(_error!),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _loadData,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
                      child: const Text('Retry', style: TextStyle(color: Colors.white))),
                ]))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: const Color(0xFF7C3AED),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(children: [
                      _buildHeroHeader(),
                      const SizedBox(height: 16),
                      _buildStatCards(),
                      const SizedBox(height: 16),
                      _buildQuickActions(),
                      const SizedBox(height: 16),
                      _buildDentalTips(),
                      const SizedBox(height: 30),
                    ]),
                  ),
                ),
    );
  }
}
