class HealthUtils {
  static String formatGender(dynamic value, {String fallback = 'male'}) {
    final g = (value ?? fallback).toString().trim().toLowerCase();
    if (g.isEmpty) return fallback[0].toUpperCase() + fallback.substring(1);
    return g[0].toUpperCase() + g.substring(1);
  }

  /// Returns null when the patient has no scan or symptom history yet.
  static double? computeOralHealthScore({
    required List<Map<String, dynamic>> scans,
    required List<Map<String, dynamic>> symptoms,
  }) {
    if (scans.isEmpty && symptoms.isEmpty) return null;
    double score = 100.0;
    for (final scan in scans.take(5)) {
      final confidence = (scan['confidence_score'] as num?)?.toDouble() ?? 0.5;
      score -= confidence * 10;
    }
    for (final symptom in symptoms.take(5)) {
      final confidence = (symptom['confidence_score'] as num?)?.toDouble() ?? 0.3;
      score -= confidence * 8;
    }
    return score.clamp(0.0, 100.0);
  }

  static String diseaseFromScan(Map<String, dynamic> scan) {
    return (scan['disease_detected'] ??
            scan['predicted_disease'] ??
            scan['disease'] ??
            'Scan Result')
        .toString();
  }

  static String diseaseFromSymptom(Map<String, dynamic> symptom) {
    return (symptom['predicted_disease'] ?? 'Unknown').toString();
  }

  static String scanAiNotes(Map<String, dynamic> scan) {
    final stored = scan['ai_notes'] ?? scan['notes'];
    if (stored != null && stored.toString().trim().isNotEmpty) {
      return stored.toString().trim();
    }
    final disease = diseaseFromScan(scan);
    final conf =
        ((scan['confidence_score'] as num?)?.toDouble() ?? 0) * 100;
    final risk = riskFromDisease(disease);
    return 'AI detected $disease (${conf.toStringAsFixed(0)}% confidence). '
        'Risk level: $risk. This is a preliminary result — please consult a '
        'dentist for a confirmed diagnosis.';
  }

  static String symptomAiNotes(Map<String, dynamic> symptom) {
    final stored = symptom['ai_notes'] ?? symptom['notes'];
    if (stored != null && stored.toString().trim().isNotEmpty) {
      return stored.toString().trim();
    }
    final disease = diseaseFromSymptom(symptom);
    final conf =
        ((symptom['confidence_score'] as num?)?.toDouble() ?? 0) * 100;
    final risk = riskFromDisease(disease);
    return 'Symptom analysis suggests $disease (${conf.toStringAsFixed(0)}% '
        'confidence). Risk level: $risk. Seek professional care if symptoms '
        'persist or worsen.';
  }

  static int countScansInMonth(
    List<Map<String, dynamic>> scans,
    DateTime month,
  ) {
    return scans.where((s) {
      final d = DateTime.tryParse(
        s['scanned_at']?.toString() ?? s['created_at']?.toString() ?? '',
      );
      return d != null && d.year == month.year && d.month == month.month;
    }).length;
  }

  static String monthlyProgressLabel({
    required List<Map<String, dynamic>> scans,
    required double? healthScore,
  }) {
    final now = DateTime.now();
    final thisMonth = countScansInMonth(scans, now);
    final lastMonth = countScansInMonth(
      scans,
      DateTime(now.year, now.month - 1),
    );
    if (thisMonth == 0 && lastMonth == 0) {
      return healthScore != null
          ? 'No scans this month — score based on your history'
          : 'Complete your first scan to track monthly progress';
    }
    if (lastMonth == 0) {
      return '$thisMonth scan${thisMonth == 1 ? '' : 's'} this month (new activity)';
    }
    final delta = thisMonth - lastMonth;
    final trend = delta >= 0 ? '+$delta' : '$delta';
    return '$thisMonth scan${thisMonth == 1 ? '' : 's'} this month ($trend vs last month)';
  }

  static double monthlyProgressValue({
    required List<Map<String, dynamic>> scans,
    required double? healthScore,
  }) {
    final now = DateTime.now();
    final thisMonth = countScansInMonth(scans, now);
    final lastMonth = countScansInMonth(
      scans,
      DateTime(now.year, now.month - 1),
    );
    if (thisMonth == 0 && lastMonth == 0) {
      return healthScore != null ? (healthScore / 100).clamp(0.1, 1.0) : 0.05;
    }
    if (lastMonth == 0) return (thisMonth / 4).clamp(0.15, 1.0);
    return (thisMonth / (lastMonth * 1.5)).clamp(0.1, 1.0);
  }

  static String riskFromScore(double score) {
    if (score >= 80) return 'Healthy';
    if (score >= 50) return 'Moderate';
    return 'At Risk';
  }

  static String riskFromDisease(String disease) {
    final d = disease.toLowerCase();
    if (d.contains('abscess') || d.contains('cancer') || d.contains('periodontitis')) return 'High';
    if (d.contains('caries') || d.contains('gingivitis') || d.contains('cavity')) return 'Medium';
    return 'Low';
  }

  static String dailyTip() {
    final tips = [
      'Brush your teeth twice a day for 2 minutes each time.',
      'Floss daily to remove plaque between teeth.',
      'Drink more water — it helps wash away food particles.',
      'Limit sugary drinks and snacks to protect enamel.',
      'Replace your toothbrush every 3 months.',
      'Visit your dentist every 6 months for a check-up.',
      'Use fluoride toothpaste to strengthen enamel.',
    ];
    final index = DateTime.now().day % tips.length;
    return tips[index];
  }
}
