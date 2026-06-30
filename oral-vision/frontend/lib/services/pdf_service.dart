import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/material.dart';
import '../utils/prescription_utils.dart';

class PdfService {
  static String _riskLevel(Map<String, dynamic> result) {
    if (result['risk_level'] != null) return result['risk_level'].toString();
    final c = (result['confidence'] ?? 0) as num;
    if (c >= 80) return 'High';
    if (c >= 50) return 'Medium';
    return 'Low';
  }

  static PdfColor _riskPdfColor(String risk) {
    switch (risk.toLowerCase()) {
      case 'high':
      case 'critical':
        return PdfColors.red;
      case 'medium':
        return PdfColors.orange;
      default:
        return PdfColors.green;
    }
  }

  static String _recommendation(Map<String, dynamic> result, String disease) {
    if (result['recommendation'] != null) {
      return result['recommendation'].toString();
    }
    final d = disease.toLowerCase();
    if (d.contains('caries') || d.contains('cavity')) {
      return 'Schedule a dental appointment for filling evaluation. Avoid sugary foods.';
    }
    if (d.contains('healthy')) {
      return 'No immediate treatment required. Continue regular checkups every 6 months.';
    }
    return 'Consult a qualified dentist for proper diagnosis and treatment planning.';
  }

  static Future<pw.Document> _buildScanPdf({
    required Map<String, dynamic> result,
    required String scanType,
    required String patientName,
    File? imageFile,
  }) async {
    final pdf = pw.Document();
    final date = DateTime.now();
    final dateStr = '${date.day}/${date.month}/${date.year}';
    final timeStr = '${date.hour}:${date.minute.toString().padLeft(2, '0')}';

    final disease = result['disease'] ?? 'Unknown';
    final confidence = (result['confidence'] ?? 0).toStringAsFixed(1);
    final affectedArea = (result['affected_area'] ?? 0).toStringAsFixed(1);
    final bboxes = result['bboxes'] as List? ?? [];
    final risk = _riskLevel(result);
    final recommendation = _recommendation(result, disease);

    pw.MemoryImage? scanImage;
    if (imageFile != null && await imageFile.exists()) {
      final bytes = await imageFile.readAsBytes();
      scanImage = pw.MemoryImage(bytes);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (ctx) => [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: PdfColors.teal700,
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('OralVision AI Scan Report',
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold)),
                pw.Text('Generated $dateStr at $timeStr',
                    style: const pw.TextStyle(color: PdfColors.white, fontSize: 11)),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Patient: $patientName',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(scanType == 'xray' ? 'Dental X-Ray' : 'Oral Photo'),
            ],
          ),
          pw.SizedBox(height: 16),
          if (scanImage != null) ...[
            pw.Text('Scan Image', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Container(
                height: 200,
                child: pw.Image(scanImage, fit: pw.BoxFit.contain),
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              'Red overlay on app shows affected-area grid. X-ray scans may include bounding boxes.',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 16),
          ],
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.teal200),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Detected Condition',
                    style: pw.TextStyle(color: PdfColors.grey600, fontSize: 10)),
                pw.Text(disease,
                    style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.teal700)),
                pw.SizedBox(height: 12),
                pw.Row(
                  children: [
                    pw.Expanded(child: pw.Text('Confidence: $confidence%')),
                    pw.Expanded(child: pw.Text('Affected Area: $affectedArea%')),
                    pw.Expanded(
                      child: pw.Text('Risk: $risk',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              color: _riskPdfColor(risk))),
                    ),
                  ],
                ),
                if (scanType == 'xray' && bboxes.isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 8),
                    child: pw.Text('Detection regions: ${bboxes.length}'),
                  ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text('Recommendation', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue50,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text(recommendation, style: const pw.TextStyle(fontSize: 12)),
          ),
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.orange50,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text(
              'DISCLAIMER: AI-generated report for informational purposes only. Not a substitute for professional dental diagnosis.',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.orange900),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text('Report ID: OV-${date.millisecondsSinceEpoch}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        ],
      ),
    );
    return pdf;
  }

  static Future<void> generateScanReport({
    required BuildContext context,
    required Map<String, dynamic> result,
    required String scanType,
    required String patientName,
    File? imageFile,
  }) async {
    final pdf = await _buildScanPdf(
      result: result,
      scanType: scanType,
      patientName: patientName,
      imageFile: imageFile,
    );
    final dateStr = '${DateTime.now().day}_${DateTime.now().month}_${DateTime.now().year}';
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'OralVision_Scan_$dateStr.pdf',
    );
  }

  static Future<void> printScanReport({
    required Map<String, dynamic> result,
    required String scanType,
    required String patientName,
    File? imageFile,
  }) async {
    final pdf = await _buildScanPdf(
      result: result,
      scanType: scanType,
      patientName: patientName,
      imageFile: imageFile,
    );
    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  static Future<void> generatePrescriptionReport({
    required Map<String, dynamic> prescription,
    required String patientName,
  }) async {
    final pdf = pw.Document();
    final date = DateTime.now();
    final meds = PrescriptionUtils.medicines(prescription);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('OralVision Prescription',
                style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.teal700)),
            pw.SizedBox(height: 8),
            pw.Text('Patient: $patientName'),
            pw.Text('Dentist: ${PrescriptionUtils.dentistName(prescription)}'),
            pw.Text('Date: ${prescription['created_at']?.toString().substring(0, 10) ?? date.toString().substring(0, 10)}'),
            if (PrescriptionUtils.diagnosis(prescription).isNotEmpty) ...[
              pw.SizedBox(height: 8),
              pw.Text('Diagnosis: ${PrescriptionUtils.diagnosis(prescription)}'),
            ],
            pw.SizedBox(height: 16),
            pw.Text('Medications', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
            pw.SizedBox(height: 8),
            ...meds.map((m) => pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 8),
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(m['name']?.toString() ?? '',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      if ((m['dosage'] ?? '').toString().isNotEmpty)
                        pw.Text('Dosage: ${m['dosage']}'),
                      if ((m['frequency'] ?? '').toString().isNotEmpty)
                        pw.Text('Frequency: ${m['frequency']}'),
                      if ((m['duration'] ?? '').toString().isNotEmpty)
                        pw.Text('Duration: ${m['duration']}'),
                      if ((m['instructions'] ?? '').toString().isNotEmpty)
                        pw.Text('Instructions: ${m['instructions']}'),
                    ],
                  ),
                )),
            if (PrescriptionUtils.doctorNote(prescription).isNotEmpty) ...[
              pw.SizedBox(height: 12),
              pw.Text('Doctor Notes', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(PrescriptionUtils.doctorNote(prescription)),
            ],
            pw.Spacer(),
            pw.Text(
              'Follow your dentist instructions. Contact your clinic if symptoms worsen.',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
          ],
        ),
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'OralVision_Prescription_${date.millisecondsSinceEpoch}.pdf',
    );
  }
}
