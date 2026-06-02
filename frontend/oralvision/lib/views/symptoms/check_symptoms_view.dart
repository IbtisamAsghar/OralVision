import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../viewmodels/symptoms_viewmodel.dart';

class CheckSymptomsView extends ConsumerStatefulWidget {
  const CheckSymptomsView({super.key});

  @override
  ConsumerState<CheckSymptomsView> createState() => _CheckSymptomsViewState();
}

class _CheckSymptomsViewState extends ConsumerState<CheckSymptomsView> {
  final List<String> _allSymptoms = [
    'toothache', 'hot_cold_sensitivity', 'swollen_gums', 'bleeding_gums',
    'bad_breath', 'white_patches', 'loose_teeth', 'fever', 'jaw_swelling',
    'pain_when_chewing', 'mouth_sores'
  ];

  final Map<String, int> _selectedSymptoms = {};

  @override
  void initState() {
    super.initState();
    for (var symptom in _allSymptoms) {
      _selectedSymptoms[symptom] = 0;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(symptomsViewModelProvider.notifier).clearResult();
    });
  }

  void _toggleSymptom(String symptom, bool value) {
    setState(() {
      _selectedSymptoms[symptom] = value ? 1 : 0;
    });
  }

  void _resetSymptoms() {
    setState(() {
      for (var symptom in _allSymptoms) {
        _selectedSymptoms[symptom] = 0;
      }
    });
  }

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open PDF')),
        );
      }
    }
  }

  String _formatSymptomName(String name) {
    return name.split('_').map((word) => word[0].toUpperCase() + word.substring(1)).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(symptomsViewModelProvider);
    final viewModel = ref.read(symptomsViewModelProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        title: const Text('Check via Symptoms', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: state.isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppColors.primaryTeal),
                    SizedBox(height: 16),
                    Text("AI is analyzing symptoms...", style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              )
            : state.predictionResult != null
                ? _buildResultsView(state.predictionResult!, viewModel)
                : _buildSymptomsSelectionView(viewModel, state.error),
      ),
    );
  }

  Widget _buildSymptomsSelectionView(SymptomsViewModel viewModel, String? error) {
    return Column(
      children: [
        if (error != null)
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.red.shade50,
            child: Text(error, style: const TextStyle(color: Colors.red)),
          ),
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            "Select all the symptoms you are currently experiencing:",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _allSymptoms.length,
            itemBuilder: (context, index) {
              final symptom = _allSymptoms[index];
              final isSelected = _selectedSymptoms[symptom] == 1;
              
              return Card(
                elevation: 0,
                color: isSelected ? AppColors.primaryTeal.withOpacity(0.1) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected ? AppColors.primaryTeal : Colors.grey.shade200,
                  ),
                ),
                child: CheckboxListTile(
                  title: Text(
                    _formatSymptomName(symptom),
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  value: isSelected,
                  activeColor: AppColors.primaryTeal,
                  onChanged: (bool? value) {
                    _toggleSymptom(symptom, value ?? false);
                  },
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                viewModel.runPrediction(_selectedSymptoms);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryTeal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Run AI Prediction',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsView(Map<String, dynamic> results, SymptomsViewModel viewModel) {
    final severityColor = results['severity'] == 'High' || results['severity'] == 'Extreme'
        ? Colors.red
        : results['severity'] == 'Moderate' ? Colors.orange : Colors.green;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Icon(Icons.check_circle, color: AppColors.primaryTeal, size: 64),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              "Assessment Complete",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 32),
          
          _buildResultRow("Predicted Condition", results['disease'], AppColors.textPrimary),
          const Divider(height: 32),
          _buildResultRow("Confidence Score", "${(results['confidence'] * 100).toStringAsFixed(1)}%", AppColors.primaryTeal),
          const Divider(height: 32),
          _buildResultRow("Severity Level", results['severity'], severityColor),
          
          const SizedBox(height: 32),
          const Text("AI Medical Report", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Text(
              results['ai_report'] ?? "No report generated.",
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
            ),
          ),
          
          const SizedBox(height: 32),
          if (results['pdf_url'] != null && results['pdf_url'].toString().isNotEmpty)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                onPressed: () => _launchUrl(results['pdf_url']),
                icon: const Icon(Icons.picture_as_pdf, color: AppColors.primaryTeal),
                label: const Text(
                  'Download PDF Report',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryTeal),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primaryTeal, width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                viewModel.clearResult();
                _resetSymptoms();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryTeal,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Start New Assessment', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String title, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, color: AppColors.textSecondary)),
        Flexible(
          child: Text(
            value, 
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: valueColor),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
