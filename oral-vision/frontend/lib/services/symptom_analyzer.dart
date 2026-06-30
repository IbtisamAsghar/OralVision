/// Local rule-based symptom analysis fallback when ML API is unavailable.
class SymptomAnalyzer {
  static const _recommendations = {
    'Dental Caries (Cavity)':
        'Avoid sugary foods, brush twice daily with fluoride toothpaste, and schedule a dental filling as soon as possible.',
    'Gingivitis':
        'Improve oral hygiene, use antiseptic mouthwash, and visit a dentist for professional cleaning.',
    'Periodontitis':
        'Seek immediate periodontal care. Advanced gum disease can lead to tooth loss if untreated.',
    'Oral Candidiasis (Thrush)':
        'Consult a dentist or physician. Antifungal treatment may be required.',
    'Tooth Abscess':
        'Urgent dental care needed. An abscess can spread infection — contact a dentist immediately.',
    'Mouth Ulcers (Canker Sores)':
        'Use a soft-bristled brush, avoid spicy foods, and monitor for persistent ulcers beyond 2 weeks.',
    'Healthy':
        'Maintain good oral hygiene and schedule regular dental check-ups every 6 months.',
  };

  static Map<String, dynamic> analyze(Map<String, dynamic> symptoms) {
    final s = symptoms.map((k, v) => MapEntry(k, (v as num).toInt()));
    final count = s.values.where((v) => v == 1).length;

    if (count == 0) {
      return {
        'predicted_disease': 'Healthy',
        'confidence': 0.5,
        'risk_level': 'Low',
        'recommendation': _recommendations['Healthy']!,
        'symptoms_reported': 0,
        'source': 'local',
      };
    }

    String disease;
    double confidence;

    if (s['fever'] == 1 && (s['jaw_swelling'] == 1 || s['toothache'] == 1)) {
      disease = 'Tooth Abscess';
      confidence = 0.88;
    } else if (s['white_patches'] == 1) {
      disease = 'Oral Candidiasis (Thrush)';
      confidence = 0.82;
    } else if (s['loose_teeth'] == 1 &&
        (s['bleeding_gums'] == 1 || s['swollen_gums'] == 1)) {
      disease = 'Periodontitis';
      confidence = 0.85;
    } else if (s['bleeding_gums'] == 1 || s['swollen_gums'] == 1) {
      disease = 'Gingivitis';
      confidence = 0.78;
    } else if (s['mouth_sores'] == 1 && count <= 2) {
      disease = 'Mouth Ulcers (Canker Sores)';
      confidence = 0.72;
    } else if (s['toothache'] == 1 ||
        s['hot_cold_sensitivity'] == 1 ||
        s['pain_when_chewing'] == 1) {
      disease = 'Dental Caries (Cavity)';
      confidence = 0.80;
    } else if (s['bad_breath'] == 1 && count == 1) {
      disease = 'Gingivitis';
      confidence = 0.65;
    } else if (count <= 1) {
      disease = 'Healthy';
      confidence = 0.60;
    } else {
      disease = 'Gingivitis';
      confidence = 0.70;
    }

    final risk = _riskLevel(confidence, count, disease);
    return {
      'predicted_disease': disease,
      'confidence': confidence,
      'risk_level': risk,
      'recommendation': _recommendations[disease] ??
          'Please consult a certified dentist for a proper clinical examination.',
      'symptoms_reported': count,
      'source': 'local',
    };
  }

  static String _riskLevel(double confidence, int count, String disease) {
    if (disease == 'Healthy') return 'Low';
    if (confidence >= 0.85 || count >= 4) return 'High';
    if (confidence >= 0.65 || count >= 2) return 'Medium';
    return 'Low';
  }
}
