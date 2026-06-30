import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../utils/colors.dart';
import '../services/api_service.dart';

class SymptomScreen extends StatefulWidget {
  const SymptomScreen({super.key});
  @override
  State<SymptomScreen> createState() => _SymptomScreenState();
}

class _SymptomScreenState extends State<SymptomScreen> with SingleTickerProviderStateMixin {
  final _apiService = ApiService();
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  bool _isGeneratingPdf = false;
  Map<String, dynamic>? _result;
  late AnimationController _cardAnimController;
  late Animation<Offset> _slideAnim;

  // Step 1: 8 primary symptoms
  static const _step1Keys = [
    'toothache', 'bleeding_gums', 'mouth_ulcers', 'swollen_gums',
    'white_patches', 'dry_mouth', 'bad_breath', 'loose_tooth',
  ];

  // Step 2: follow-up map based on step1 answers
  static const Map<String, List<String>> _followUps = {
    'toothache': ['hot_sensitivity', 'cold_sensitivity', 'sweet_sensitivity', 'sharp_pain_biting', 'pain_when_chewing', 'fever', 'pus_around_tooth'],
    'bleeding_gums': ['red_gums', 'swollen_gums', 'receding_gums', 'gum_pain', 'pus_from_gums', 'bad_breath'],
    'mouth_ulcers': ['non_healing_ulcer', 'burning_sensation', 'fever', 'tongue_pain', 'persistent_mouth_pain', 'unexplained_bleeding'],
    'swollen_gums': ['swollen_gum_around_tooth', 'jaw_swelling', 'facial_swelling', 'fever', 'pus_around_tooth', 'enlarged_lymph_nodes'],
    'white_patches': ['red_patches', 'non_healing_ulcer', 'burning_sensation', 'difficulty_opening_mouth', 'lump_in_mouth', 'numbness_in_mouth'],
    'dry_mouth': ['thick_saliva', 'change_in_taste', 'loss_of_taste', 'difficulty_swallowing', 'burning_sensation'],
    'bad_breath': ['food_stuck', 'pus_from_gums', 'receding_gums', 'tooth_discoloration', 'excessive_saliva'],
    'loose_tooth': ['tooth_mobility', 'receding_gums', 'pus_from_gums', 'jaw_swelling', 'tooth_grinding'],
  };

  // Extra symptoms always shown in step 2 (general)
  static const _generalFollowUps = [
    'cracked_tooth', 'tooth_discoloration', 'tooth_grinding', 'headache',
    'ear_pain', 'fatigue', 'hoarseness', 'weight_loss',
    'lump_in_neck', 'persistent_sore_throat', 'difficulty_swallowing',
    'tongue_swelling', 'difficulty_opening_mouth',
  ];

  static const _labels = {
    'toothache': 'Toothache',
    'hot_sensitivity': 'Hot Sensitivity',
    'cold_sensitivity': 'Cold Sensitivity',
    'sweet_sensitivity': 'Sweet Sensitivity',
    'pain_when_chewing': 'Pain When Chewing',
    'loose_tooth': 'Loose Tooth',
    'cracked_tooth': 'Cracked Tooth',
    'tooth_discoloration': 'Tooth Discoloration',
    'tooth_mobility': 'Tooth Mobility',
    'tooth_grinding': 'Tooth Grinding (Bruxism)',
    'sharp_pain_biting': 'Sharp Pain When Biting',
    'food_stuck': 'Food Getting Stuck',
    'pus_around_tooth': 'Pus Around Tooth',
    'swollen_gum_around_tooth': 'Swollen Gum Around Tooth',
    'bleeding_gums': 'Bleeding Gums',
    'red_gums': 'Red Gums',
    'swollen_gums': 'Swollen Gums',
    'receding_gums': 'Receding Gums',
    'gum_pain': 'Gum Pain',
    'bad_breath': 'Bad Breath (Halitosis)',
    'pus_from_gums': 'Pus From Gums',
    'mouth_ulcers': 'Mouth Ulcers',
    'white_patches': 'White Patches in Mouth',
    'red_patches': 'Red Patches in Mouth',
    'burning_sensation': 'Burning Sensation',
    'dry_mouth': 'Dry Mouth',
    'difficulty_swallowing': 'Difficulty Swallowing',
    'tongue_pain': 'Tongue Pain',
    'tongue_swelling': 'Tongue Swelling',
    'change_in_taste': 'Change in Taste',
    'loss_of_taste': 'Loss of Taste',
    'thick_saliva': 'Thick Saliva',
    'excessive_saliva': 'Excessive Saliva',
    'fever': 'Fever',
    'jaw_swelling': 'Jaw Swelling',
    'facial_swelling': 'Facial Swelling',
    'enlarged_lymph_nodes': 'Enlarged Lymph Nodes',
    'fatigue': 'Fatigue',
    'ear_pain': 'Ear Pain',
    'headache': 'Headache',
    'non_healing_ulcer': 'Non-Healing Ulcer (>2 weeks)',
    'lump_in_mouth': 'Lump in Mouth',
    'lump_in_neck': 'Lump in Neck',
    'persistent_mouth_pain': 'Persistent Mouth Pain',
    'difficulty_opening_mouth': 'Difficulty Opening Mouth',
    'unexplained_bleeding': 'Unexplained Bleeding',
    'numbness_in_mouth': 'Numbness in Mouth',
    'hoarseness': 'Hoarseness of Voice',
    'weight_loss': 'Unexplained Weight Loss',
    'persistent_sore_throat': 'Persistent Sore Throat',
  };

  static const _icons = {
    'toothache': Icons.sentiment_dissatisfied,
    'hot_sensitivity': Icons.local_fire_department,
    'cold_sensitivity': Icons.ac_unit,
    'sweet_sensitivity': Icons.cake,
    'pain_when_chewing': Icons.restaurant,
    'loose_tooth': Icons.medical_services,
    'cracked_tooth': Icons.broken_image_outlined,
    'tooth_discoloration': Icons.color_lens_outlined,
    'tooth_mobility': Icons.swap_horiz,
    'tooth_grinding': Icons.graphic_eq,
    'sharp_pain_biting': Icons.flash_on,
    'food_stuck': Icons.dinner_dining,
    'pus_around_tooth': Icons.warning_amber,
    'swollen_gum_around_tooth': Icons.healing,
    'bleeding_gums': Icons.bloodtype,
    'red_gums': Icons.favorite,
    'swollen_gums': Icons.healing,
    'receding_gums': Icons.trending_down,
    'gum_pain': Icons.sentiment_very_dissatisfied,
    'bad_breath': Icons.air,
    'pus_from_gums': Icons.warning,
    'mouth_ulcers': Icons.coronavirus_outlined,
    'white_patches': Icons.texture,
    'red_patches': Icons.blur_circular,
    'burning_sensation': Icons.whatshot,
    'dry_mouth': Icons.water_drop_outlined,
    'difficulty_swallowing': Icons.no_food,
    'tongue_pain': Icons.sick,
    'tongue_swelling': Icons.face,
    'change_in_taste': Icons.no_meals,
    'loss_of_taste': Icons.not_interested,
    'thick_saliva': Icons.opacity,
    'excessive_saliva': Icons.water,
    'fever': Icons.thermostat,
    'jaw_swelling': Icons.face_retouching_natural,
    'facial_swelling': Icons.face_retouching_off,
    'enlarged_lymph_nodes': Icons.bubble_chart,
    'fatigue': Icons.battery_0_bar,
    'ear_pain': Icons.hearing_disabled,
    'headache': Icons.psychology,
    'non_healing_ulcer': Icons.dangerous,
    'lump_in_mouth': Icons.circle,
    'lump_in_neck': Icons.radio_button_checked,
    'persistent_mouth_pain': Icons.report_problem,
    'difficulty_opening_mouth': Icons.do_not_touch,
    'unexplained_bleeding': Icons.bloodtype,
    'numbness_in_mouth': Icons.do_disturb,
    'hoarseness': Icons.record_voice_over,
    'weight_loss': Icons.monitor_weight,
    'persistent_sore_throat': Icons.sick,
  };

  static const _descriptions = {
    'toothache': 'Do you have pain or aching in or around a tooth?',
    'bleeding_gums': 'Do your gums bleed when brushing or flossing?',
    'mouth_ulcers': 'Do you have sores or painful spots in your mouth?',
    'swollen_gums': 'Are your gums swollen or puffy?',
    'white_patches': 'Do you notice white patches inside your mouth?',
    'dry_mouth': 'Does your mouth frequently feel dry?',
    'bad_breath': 'Do you have persistent bad breath?',
    'loose_tooth': 'Do any of your teeth feel loose?',
    'hot_sensitivity': 'Do your teeth hurt with hot food or drinks?',
    'cold_sensitivity': 'Do your teeth hurt with cold food or drinks?',
    'sweet_sensitivity': 'Do you feel pain when eating sweet foods?',
    'sharp_pain_biting': 'Do you feel a sharp pain when biting down?',
    'pain_when_chewing': 'Do you feel pain or discomfort when chewing?',
    'fever': 'Do you currently have a fever?',
    'pus_around_tooth': 'Is there pus or discharge around a tooth?',
    'red_gums': 'Are your gums red or inflamed?',
    'receding_gums': 'Have your gums pulled back from your teeth?',
    'gum_pain': 'Do you have pain specifically in your gums?',
    'pus_from_gums': 'Is there pus coming from your gums?',
    'non_healing_ulcer': 'Do you have an ulcer that has not healed in over 2 weeks?',
    'burning_sensation': 'Do you feel a burning sensation in your mouth?',
    'tongue_pain': 'Do you have pain in your tongue?',
    'persistent_mouth_pain': 'Do you have persistent pain in your mouth?',
    'unexplained_bleeding': 'Do you have unexplained bleeding in your mouth?',
    'swollen_gum_around_tooth': 'Is the gum around a specific tooth swollen?',
    'jaw_swelling': 'Is there swelling around your jaw?',
    'facial_swelling': 'Is there swelling on your face?',
    'enlarged_lymph_nodes': 'Do you have swollen glands in your neck?',
    'red_patches': 'Do you notice red patches inside your mouth?',
    'lump_in_mouth': 'Do you feel a lump or thickening inside your mouth?',
    'numbness_in_mouth': 'Do you have numbness inside your mouth?',
    'difficulty_opening_mouth': 'Do you have difficulty fully opening your mouth?',
    'thick_saliva': 'Does your saliva feel thick or ropy?',
    'change_in_taste': 'Have you noticed a change in your sense of taste?',
    'loss_of_taste': 'Have you lost your sense of taste?',
    'difficulty_swallowing': 'Do you have difficulty swallowing food or liquids?',
    'cracked_tooth': 'Do you feel or know you have a cracked tooth?',
    'tooth_discoloration': 'Have your teeth changed color?',
    'tooth_grinding': 'Do you grind your teeth, especially at night?',
    'headache': 'Do you have frequent headaches?',
    'ear_pain': 'Do you have ear pain?',
    'fatigue': 'Are you feeling unusually fatigued?',
    'hoarseness': 'Has your voice become hoarse?',
    'weight_loss': 'Have you had unexplained weight loss?',
    'lump_in_neck': 'Do you feel a lump in your neck?',
    'persistent_sore_throat': 'Do you have a persistent sore throat?',
    'tongue_swelling': 'Is your tongue swollen?',
    'tooth_mobility': 'Do your teeth feel like they are shifting?',
    'food_stuck': 'Does food frequently get stuck between your teeth?',
    'excessive_saliva': 'Do you produce excessive saliva?',
  };

  // State
  int _step = 1; // 1 = primary, 2 = followup, 3 = result
  int _currentCard = 0;
  bool _isAnimating = false;
  List<String> _step2Keys = [];

  final Map<String, bool> _answers = {
    for (final k in _labels.keys) k: false,
  };

  List<String> get _currentDeck =>
      _step == 1 ? _step1Keys : _step2Keys;

  bool get _deckDone => _currentCard >= _currentDeck.length;

  int get _selectedCount => _answers.values.where((v) => v).length;

  @override
  void initState() {
    super.initState();
    _cardAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _slideAnim = Tween<Offset>(begin: Offset.zero, end: Offset.zero).animate(_cardAnimController);
  }

  @override
  void dispose() {
    _cardAnimController.dispose();
    super.dispose();
  }

  void _buildStep2Keys() {
    final Set<String> keys = {};
    for (final k in _step1Keys) {
      if (_answers[k] == true) {
        keys.addAll(_followUps[k] ?? []);
      }
    }
    // Remove step1 keys already answered
    keys.removeAll(_step1Keys);
    // Add general follow-ups
    keys.addAll(_generalFollowUps);
    keys.removeAll(_step1Keys);
    _step2Keys = keys.toList();
  }

  void _answer(bool yes) async {
    if (_isAnimating || _deckDone) return;
    _isAnimating = true;
    final key = _currentDeck[_currentCard];
    final endOffset = yes ? const Offset(1.5, 0) : const Offset(-1.5, 0);
    _slideAnim = Tween<Offset>(begin: Offset.zero, end: endOffset)
        .animate(CurvedAnimation(parent: _cardAnimController, curve: Curves.easeIn));
    await _cardAnimController.forward();
    setState(() {
      _answers[key] = yes;
      _currentCard++;
    });
    _cardAnimController.reset();
    _isAnimating = false;

    if (_deckDone) {
      if (_step == 1) {
        final anyYes = _step1Keys.any((k) => _answers[k] == true);
        if (!anyYes) {
          await Future.delayed(const Duration(milliseconds: 300));
          _analyzeSymptoms();
          setState(() => _step = 3);
          return;
        }
        await Future.delayed(const Duration(milliseconds: 200));
        _buildStep2Keys();
        setState(() { _step = 2; _currentCard = 0; });
      } else {
        await Future.delayed(const Duration(milliseconds: 300));
        _analyzeSymptoms();
        setState(() => _step = 3);
      }
    }
  }

  void _goBack() {
    if (_currentCard == 0 && _step == 1) return;
    if (_isAnimating) return;
    setState(() {
      if (_currentCard > 0) {
        _currentCard--;
        _answers[_currentDeck[_currentCard]] = false;
      } else if (_step == 2) {
        _step = 1;
        _currentCard = _step1Keys.length - 1;
      }
    });
  }

  void _restart() {
    setState(() {
      _step = 1;
      _currentCard = 0;
      _result = null;
      _answers.updateAll((k, v) => false);
      _step2Keys = [];
    });
  }

  Future<void> _analyzeSymptoms() async {
    setState(() { _isLoading = true; _result = null; });
    try {
      final data = _answers.map((key, value) => MapEntry(key, value ? 1 : 0));
      Map<String, dynamic> result;
      try {
        result = await _apiService.checkSymptoms(data);
      } catch (_) {
        result = _localDiagnosis(data);
        result['source'] = 'local';
      }
      final user = _supabase.auth.currentUser;
      if (user != null) {
        try {
          await _supabase.from('symptom_history').insert({
            'user_id': user.id,
            'symptoms_input': data,
            'predicted_disease': result['predicted_disease'],
            'confidence_score': result['confidence'],
          });
        } catch (_) {}
      }
      setState(() => _result = result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Analysis failed: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _localDiagnosis(Map<String, dynamic> data) {
    final s = data;
    final count = s.values.fold(0, (a, b) => a + (b as int));
    String disease = 'Healthy'; double confidence = 0.95; String risk = 'Low';

    if (s['non_healing_ulcer'] == 1 || s['lump_in_mouth'] == 1 || s['lump_in_neck'] == 1) {
      disease = 'Oral Cancer'; confidence = 0.91; risk = 'Critical';
    } else if (s['difficulty_opening_mouth'] == 1 && s['white_patches'] == 1) {
      disease = 'Oral Submucous Fibrosis'; confidence = 0.88; risk = 'High';
    } else if (s['fever'] == 1 && (s['jaw_swelling'] == 1 || s['pus_around_tooth'] == 1)) {
      disease = 'Tooth Abscess'; confidence = 0.93; risk = 'High';
    } else if (s['white_patches'] == 1 && s['non_healing_ulcer'] == 1) {
      disease = 'Leukoplakia'; confidence = 0.89; risk = 'High';
    } else if (s['white_patches'] == 1 && s['burning_sensation'] == 1) {
      disease = 'Oral Thrush'; confidence = 0.86; risk = 'Medium';
    } else if (s['white_patches'] == 1 && s['red_patches'] == 1) {
      disease = 'Oral Lichen Planus'; confidence = 0.84; risk = 'Medium';
    } else if (s['cracked_tooth'] == 1 && s['sharp_pain_biting'] == 1) {
      disease = 'Cracked Tooth Syndrome'; confidence = 0.88; risk = 'High';
    } else if (s['loose_tooth'] == 1 && (s['receding_gums'] == 1 || s['pus_from_gums'] == 1)) {
      disease = 'Periodontitis'; confidence = 0.87; risk = 'High';
    } else if (s['toothache'] == 1 && s['hot_sensitivity'] == 1 && s['sharp_pain_biting'] == 1) {
      disease = 'Pulpitis'; confidence = 0.86; risk = 'High';
    } else if (s['tooth_grinding'] == 1 && s['headache'] == 1) {
      disease = 'Bruxism'; confidence = 0.83; risk = 'Medium';
    } else if (s['dry_mouth'] == 1 && s['thick_saliva'] == 1) {
      disease = 'Xerostomia'; confidence = 0.82; risk = 'Low';
    } else if (s['bleeding_gums'] == 1 && s['swollen_gums'] == 1) {
      disease = 'Gingivitis'; confidence = 0.82; risk = 'Medium';
    } else if (s['mouth_ulcers'] == 1 && s['fever'] == 1) {
      disease = 'Herpes Simplex (Oral)'; confidence = 0.80; risk = 'Medium';
    } else if (s['mouth_ulcers'] == 1) {
      disease = 'Aphthous Ulcer'; confidence = 0.78; risk = 'Low';
    } else if (s['toothache'] == 1 || s['cold_sensitivity'] == 1) {
      disease = 'Dental Caries'; confidence = 0.80; risk = 'Medium';
    } else if (count == 0) {
      disease = 'Healthy'; confidence = 0.97; risk = 'Low';
    }

    const recs = {
      'Oral Cancer': 'URGENT: Non-healing ulcers/lumps need immediate biopsy. See an oral surgeon today.',
      'Oral Submucous Fibrosis': 'Stop tobacco/betel nut use immediately. Requires specialist evaluation.',
      'Tooth Abscess': 'URGENT: Seek emergency dental care immediately.',
      'Leukoplakia': 'IMPORTANT: White patches need biopsy. See a dentist immediately.',
      'Oral Thrush': 'Antifungal medication required. Consult a dentist or physician.',
      'Oral Lichen Planus': 'Consult a specialist. Oral lichen planus requires monitoring.',
      'Cracked Tooth Syndrome': 'Avoid hard foods. See a dentist immediately.',
      'Periodontitis': 'Seek immediate periodontal care. Advanced gum disease can lead to tooth loss.',
      'Pulpitis': 'See a dentist immediately. You may need root canal treatment.',
      'Bruxism': 'Use a night guard. Consult your dentist about bite correction.',
      'Xerostomia': 'Stay hydrated, chew sugar-free gum, use alcohol-free mouthwash.',
      'Gingivitis': 'Improve oral hygiene and visit a dentist for professional cleaning.',
      'Herpes Simplex (Oral)': 'Antiviral medication can help. Avoid contact during active outbreak.',
      'Aphthous Ulcer': 'Use antiseptic mouthwash. See a dentist if ulcer persists beyond 2 weeks.',
      'Dental Caries': 'Avoid sugary foods and schedule a dental filling immediately.',
      'Healthy': 'Great oral health! Maintain regular brushing and dental check-ups.',
    };
    return {
      'predicted_disease': disease,
      'confidence': confidence,
      'risk_level': risk,
      'recommendation': recs[disease] ?? 'Please consult a certified dentist.',
    };
  }

  Future<void> _downloadReport() async {
    if (_result == null) return;
    setState(() => _isGeneratingPdf = true);
    try {
      final pdf = pw.Document();
      final disease = _result!['predicted_disease'] ?? 'Unknown';
      final confidence = ((_result!['confidence'] as num?)?.toDouble() ?? 0) * 100;
      final risk = _result!['risk_level'] ?? 'Low';
      final recommendation = _result!['recommendation'] ?? '';
      final reported = _answers.entries.where((e) => e.value).map((e) => _labels[e.key]!).toList();
      final now = DateTime.now();
      final dateStr = '${now.day}/${now.month}/${now.year}';

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 12),
            decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromInt(0xFF0F6E56), width: 2))),
            child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('OralVision', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF0F6E56))),
                pw.Text('Symptom Analysis Report', style: pw.TextStyle(fontSize: 12, color: PdfColor.fromInt(0xFF546E7A))),
              ]),
              pw.Text('Date: $dateStr', style: pw.TextStyle(fontSize: 10, color: PdfColor.fromInt(0xFF546E7A))),
            ]),
          ),
          pw.SizedBox(height: 20),
          pw.Text('Symptoms Reported (${reported.length})', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF0F6E56))),
          pw.SizedBox(height: 8),
          ...reported.map((s) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Row(children: [
              pw.Text('• ', style: pw.TextStyle(color: PdfColor.fromInt(0xFF0F6E56))),
              pw.Text(s),
            ]),
          )),
          pw.SizedBox(height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFF4FBF8), borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('AI Diagnosis', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF0F6E56))),
              pw.SizedBox(height: 8),
              pw.Text('Predicted Condition: $disease', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('Confidence: ${confidence.toStringAsFixed(1)}%'),
              pw.Text('Risk Level: $risk'),
            ]),
          ),
          pw.SizedBox(height: 16),
          pw.Text('Recommendation', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF0F6E56))),
          pw.SizedBox(height: 8),
          pw.Text(recommendation, style: pw.TextStyle(fontSize: 12, lineSpacing: 4)),
          pw.SizedBox(height: 24),
          pw.Divider(),
          pw.SizedBox(height: 8),
          pw.Text('OralVision AI — For informational purposes only. Consult a qualified dentist for proper diagnosis.',
              style: pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF546E7A))),
        ]),
      ));
      await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: 'OralVision_Symptom_$dateStr.pdf');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF failed: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  Color _riskColor(String? risk) {
    switch (risk?.toLowerCase()) {
      case 'critical': return const Color(0xFF6A0000);
      case 'high': return AppColors.error;
      case 'medium': return Colors.orange;
      default: return AppColors.patient;
    }
  }

  double get _progress {
    if (_step == 1) return _currentCard / (_step1Keys.length + (_step2Keys.isEmpty ? 20 : _step2Keys.length));
    if (_step == 2) return (_step1Keys.length + _currentCard) / (_step1Keys.length + _step2Keys.length);
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF0D47A1), Color(0xFF00838F), Color(0xFFE0F7FA)],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(children: [
            _buildTopBar(),
            Expanded(
              child: _step == 3
                  ? _buildResultView()
                  : _buildFlashcardView(),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
      child: Column(children: [
        Row(children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                _step == 1 ? 'Primary Symptoms' : _step == 2 ? 'Follow-up Questions' : 'AI Analysis',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                _step == 1
                    ? 'Step 1 of 2 — ${_step1Keys.length} questions'
                    : _step == 2
                        ? 'Step 2 of 2 — ${_step2Keys.length} follow-ups'
                        : 'Complete',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ]),
          ),
          if (_step < 3)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _step == 1
                    ? '${_currentCard}/${_step1Keys.length}'
                    : '${_currentCard}/${_step2Keys.length}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
        ]),
        const SizedBox(height: 8),
        // Step indicators
        Row(children: [
          _StepDot(label: '1', active: _step >= 1, done: _step > 1),
          Expanded(child: Container(height: 2, color: _step > 1 ? Colors.white : Colors.white24)),
          _StepDot(label: '2', active: _step >= 2, done: _step > 2),
          Expanded(child: Container(height: 2, color: _step > 2 ? Colors.white : Colors.white24)),
          _StepDot(label: '✓', active: _step == 3, done: _step == 3),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: _progress,
            minHeight: 5,
            backgroundColor: Colors.white24,
            color: Colors.white,
          ),
        ),
      ]),
    );
  }

  Widget _buildFlashcardView() {
    if (_deckDone) {
      return const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text('Preparing next step...', style: TextStyle(color: Colors.white)),
        ]),
      );
    }

    final key = _currentDeck[_currentCard];
    final label = _labels[key] ?? key;
    final desc = _descriptions[key] ?? 'Do you experience this symptom?';
    final icon = _icons[key] ?? Icons.help_outline;
    final hasNext = _currentCard + 1 < _currentDeck.length;

    // Category color
    Color cardAccent = AppColors.patient;
    if (_step == 1) {
      cardAccent = const Color(0xFF0D5C4E);
    } else {
      if (['non_healing_ulcer','lump_in_mouth','lump_in_neck','difficulty_opening_mouth'].contains(key)) {
        cardAccent = AppColors.error;
      } else if (['fever','jaw_swelling','facial_swelling','enlarged_lymph_nodes'].contains(key)) {
        cardAccent = Colors.orange.shade800;
      } else {
        cardAccent = const Color(0xFF00838F);
      }
    }

    return Column(children: [
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Stack(alignment: Alignment.center, children: [
            if (hasNext)
              Positioned(
                top: 20,
                child: Container(
                  width: MediaQuery.of(context).size.width - 72,
                  height: 300,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
              ),
            SlideTransition(
              position: _slideAnim,
              child: GestureDetector(
                onHorizontalDragEnd: (details) {
                  final v = details.primaryVelocity ?? 0;
                  if (v > 200) {
                    _answer(true);
                  } else if (v < -200) {
                    _answer(false);
                  }
                },
                child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 24, offset: const Offset(0, 12))],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // Step badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: cardAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: cardAccent.withOpacity(0.3)),
                    ),
                    child: Text(
                      _step == 1 ? 'Primary Check' : 'Follow-up',
                      style: TextStyle(color: cardAccent, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [cardAccent, cardAccent.withOpacity(0.7)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Icon(icon, color: Colors.white, size: 44),
                  ),
                  const SizedBox(height: 20),
                  Text(label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                  const SizedBox(height: 10),
                  Text(desc,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.5)),
                ]),
              ),
            ),
            ),
          ]),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.arrow_back, color: Colors.white54, size: 13),
          const SizedBox(width: 4),
          const Text('No', style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(width: 20),
          const Text('Tap buttons or swipe', style: TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(width: 20),
          const Text('Yes', style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(width: 4),
          Icon(Icons.arrow_forward, color: Colors.white54, size: 13),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Row(children: [
          if (_currentCard > 0 || _step == 2)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: _goBack,
                child: Container(
                  width: 52, height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.undo, color: Colors.white, size: 22),
                ),
              ),
            ),
          Expanded(
            child: GestureDetector(
              onTap: () => _answer(false),
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.error.withOpacity(0.4), width: 2),
                  boxShadow: [BoxShadow(color: AppColors.error.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.close, color: AppColors.error, size: 22),
                  const SizedBox(width: 8),
                  Text('No', style: TextStyle(color: AppColors.error, fontSize: 18, fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => _answer(true),
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [cardAccent, cardAccent.withOpacity(0.8)]),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(color: cardAccent.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.check, color: Colors.white, size: 22),
                  SizedBox(width: 8),
                  Text('Yes', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _buildResultView() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFFF4F7FB),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: _isLoading
          ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              CircularProgressIndicator(color: AppColors.patient),
              SizedBox(height: 16),
              Text('AI analyzing your symptoms...', style: TextStyle(color: AppColors.textLight)),
            ]))
          : _result == null
              ? const Center(child: CircularProgressIndicator(color: AppColors.patient))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    // Symptoms summary chips
                    if (_selectedCount > 0)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('$_selectedCount symptom${_selectedCount > 1 ? 's' : ''} reported',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6, runSpacing: 6,
                            children: _answers.entries.where((e) => e.value).map((e) =>
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.patient.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppColors.patient.withOpacity(0.3)),
                                ),
                                child: Text(_labels[e.key] ?? e.key,
                                    style: const TextStyle(fontSize: 11, color: AppColors.patient, fontWeight: FontWeight.w600)),
                              ),
                            ).toList(),
                          ),
                        ]),
                      ),
                    _buildResultCard(),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity, height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _restart,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.patient),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.refresh, color: AppColors.patient),
                        label: const Text('Start New Check', style: TextStyle(color: AppColors.patient, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ]),
                ),
    );
  }

  Widget _buildResultCard() {
    final disease = _result!['predicted_disease'] ?? 'Unknown';
    final confidence = (_result!['confidence'] as num?)?.toDouble() ?? 0.0;
    final risk = _result!['risk_level'] ?? 'Low';
    final recommendation = _result!['recommendation'] ?? '';
    final riskColor = _riskColor(risk);
    final isCritical = risk.toLowerCase() == 'critical';
    final isHighRisk = risk.toLowerCase() == 'high' || isCritical;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: riskColor.withOpacity(0.4), width: isHighRisk ? 2 : 1),
        boxShadow: [BoxShadow(color: riskColor.withOpacity(0.12), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (isCritical)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: const Color(0xFF6A0000), borderRadius: BorderRadius.circular(12)),
            child: const Row(children: [
              Icon(Icons.crisis_alert, color: Colors.white, size: 24),
              SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('⚠ CRITICAL — Immediate Medical Attention',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                Text('Please see an oral surgeon or oncologist TODAY',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ])),
            ]),
          )
        else if (isHighRisk)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(12)),
            child: const Row(children: [
              Icon(Icons.emergency, color: Colors.white, size: 22),
              SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('URGENT — High Risk Detected',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                Text('Please see a dentist immediately',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ])),
            ]),
          ),
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.patient.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.biotech, color: AppColors.patient),
          ),
          const SizedBox(width: 12),
          const Text('AI Diagnostic Report',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
        ]),
        const SizedBox(height: 18),
        const Text('Predicted Condition', style: TextStyle(color: AppColors.textLight, fontSize: 12)),
        const SizedBox(height: 4),
        Text(disease, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: riskColor)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _MetricTile(label: 'Confidence', value: '${(confidence * 100).toStringAsFixed(1)}%',
              color: AppColors.accent, icon: Icons.speed)),
          const SizedBox(width: 12),
          Expanded(child: _MetricTile(label: 'Risk Level', value: risk, color: riskColor, icon: Icons.warning_amber_rounded)),
        ]),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: confidence, minHeight: 8,
              backgroundColor: AppColors.lightBlue, color: riskColor),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity, padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.tips_and_updates, color: AppColors.accent, size: 18),
              SizedBox(width: 8),
              Text('AI Recommendation', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
            ]),
            const SizedBox(height: 8),
            Text(recommendation, style: const TextStyle(color: AppColors.textDark, fontSize: 13, height: 1.4)),
          ]),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity, height: 46,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/find-dentist'),
            style: ElevatedButton.styleFrom(
              backgroundColor: riskColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.calendar_month, color: Colors.white, size: 18),
            label: const Text('Book Dentist Appointment',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity, height: 46,
          child: OutlinedButton.icon(
            onPressed: _isGeneratingPdf ? null : _downloadReport,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: riskColor),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: _isGeneratingPdf
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.picture_as_pdf, color: riskColor, size: 18),
            label: Text(_isGeneratingPdf ? 'Generating...' : 'Download PDF Report',
                style: TextStyle(color: riskColor, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: const Row(children: [
            Icon(Icons.medical_information_outlined, color: Colors.orange, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text(
              'AI-assisted assessment only. Consult a certified dentist for proper diagnosis.',
              style: TextStyle(color: Colors.orange, fontSize: 12),
            )),
          ]),
        ),
      ]),
    );
  }
}

class _StepDot extends StatelessWidget {
  final String label;
  final bool active;
  final bool done;
  const _StepDot({required this.label, required this.active, required this.done});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: active ? Colors.white : Colors.white24,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(label,
            style: TextStyle(
              color: active ? const Color(0xFF0D47A1) : Colors.white54,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            )),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _MetricTile({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: AppColors.textLight, fontSize: 11)),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
      ]),
    );
  }
}