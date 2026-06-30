/// Normalizes prescription rows from Supabase (flat or structured schema).
class PrescriptionUtils {
  static String dentistName(Map<String, dynamic> rx) {
    return (rx['dentist_name'] ?? 'Unknown Dentist').toString();
  }

  static String patientName(Map<String, dynamic> rx) {
    return (rx['patient_name'] ?? 'Patient').toString();
  }

  static String diagnosis(Map<String, dynamic> rx) {
    return (rx['diagnosis'] ?? rx['note'] ?? '').toString();
  }

  static String doctorNote(Map<String, dynamic> rx) {
    return (rx['note'] ?? rx['instructions'] ?? rx['notes'] ?? '').toString();
  }

  static List<Map<String, dynamic>> medicines(Map<String, dynamic> rx) {
    final raw = rx['medicines'];
    if (raw is List && raw.isNotEmpty) {
      return raw.map((m) => Map<String, dynamic>.from(m as Map)).toList();
    }
    final meds = (rx['medications'] ?? '').toString().trim();
    if (meds.isEmpty) return [];
    return [
      {
        'name': meds,
        'dosage': (rx['dosage'] ?? '').toString(),
        'frequency': '',
        'duration': '',
        'instructions': (rx['instructions'] ?? '').toString(),
      },
    ];
  }

  static int medicineCount(Map<String, dynamic> rx) => medicines(rx).length;
}
