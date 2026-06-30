import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'dart:convert';
import '../utils/colors.dart';
import '../services/api_service.dart';
import '../services/pdf_service.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _picker = ImagePicker();
  final _apiService = ApiService();
  final _supabase = Supabase.instance.client;
  File? _image;
  bool _isLoading = false;
  Map<String, dynamic>? _result;
  String _scanType = 'oral';
  String? _annotatedImage;

  Future<bool> _requestCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) return true;
    if (status.isDenied) {
      final result = await Permission.camera.request();
      return result.isGranted;
    }
    if (status.isPermanentlyDenied) {
      if (!mounted) return false;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.camera_alt, color: AppColors.patient),
            SizedBox(width: 8),
            Text('Camera Permission', style: TextStyle(color: AppColors.patient)),
          ]),
          content: const Text('Camera permission is permanently denied.\n\nPlease go to Settings and enable camera permission for OralVision.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.patient),
              onPressed: () { Navigator.pop(ctx); openAppSettings(); },
              child: const Text('Open Settings', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return false;
    }
    return false;
  }

  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.photos.status;
      if (status.isGranted) return true;
      final result = await Permission.photos.request();
      if (result.isGranted) return true;
      if (result.isPermanentlyDenied) {
        if (!mounted) return false;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(children: [
              Icon(Icons.photo_library, color: AppColors.accent),
              SizedBox(width: 8),
              Text('Gallery Permission', style: TextStyle(color: AppColors.accent)),
            ]),
            content: const Text('Gallery permission is permanently denied.\n\nPlease go to Settings and enable photo access for OralVision.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                onPressed: () { Navigator.pop(ctx); openAppSettings(); },
                child: const Text('Open Settings', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        return false;
      }
      return false;
    }
    return true;
  }

  Future<void> _pickFromCamera() async {
    final hasPermission = await _requestCameraPermission();
    if (!hasPermission) return;
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (picked != null) {
      setState(() {
        _image = File(picked.path);
        _result = null;
        _annotatedImage = null;
      });
    }
  }

  Future<void> _pickFromGallery() async {
    final hasPermission = await _requestStoragePermission();
    if (!hasPermission) return;
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() {
        _image = File(picked.path);
        _result = null;
        _annotatedImage = null;
      });
    }
  }

  Future<void> _analyze() async {
    if (_image == null) return;
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      String? imageUrl;
      if (user != null) {
        try {
          final fileName = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
          await _supabase.storage.from('scan-images').upload(fileName, _image!);
          imageUrl = _supabase.storage.from('scan-images').getPublicUrl(fileName);
        } catch (_) {}
      }
      final result = _scanType == 'xray'
          ? await _apiService.predictXray(_image!)
          : await _apiService.predictOral(_image!);
      if (user != null) {
        await _supabase.from('scan_history').insert({
          'user_id': user.id,
          'disease_detected': result['disease'],
          'confidence_score': (result['confidence'] ?? 0) / 100,
          'scan_type': _scanType,
          'affected_area': result['affected_area'],
          'image_url': imageUrl,
          'ai_notes': result['recommendation'],
        });
      }
      setState(() {
        _result = result;
        _annotatedImage = result['annotated_image'] as String?;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: AppColors.error),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Color _riskColor(num confidence) {
    if (confidence >= 80) return AppColors.riskHigh;
    if (confidence >= 50) return AppColors.riskMedium;
    return AppColors.riskLow;
  }

  Future<String> _patientName() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return 'Patient';
    try {
      final row = await _supabase
          .from('profiles')
          .select('full_name')
          .eq('id', user.id)
          .maybeSingle();
      if (row != null && (row['full_name'] ?? '').toString().isNotEmpty) {
        return row['full_name'].toString();
      }
    } catch (_) {}
    return user.userMetadata?['full_name']?.toString() ?? 'Patient';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.patientBg,
      appBar: AppBar(
        backgroundColor: AppColors.patientDark,
        title: const Text('AI Scan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Scan type toggle
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.patient.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() { _scanType = 'oral'; _result = null; _annotatedImage = null; }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _scanType == 'oral' ? AppColors.patient : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('Oral Photo', textAlign: TextAlign.center,
                          style: TextStyle(color: _scanType == 'oral' ? Colors.white : AppColors.textLight, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() { _scanType = 'xray'; _result = null; _annotatedImage = null; }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _scanType == 'xray' ? AppColors.patient : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('X-Ray', textAlign: TextAlign.center,
                          style: TextStyle(color: _scanType == 'xray' ? Colors.white : AppColors.textLight, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Image display
            GestureDetector(
              onTap: _pickFromGallery,
              child: Container(
                width: double.infinity,
                height: 280,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _result != null ? AppColors.patient : AppColors.patient.withValues(alpha: 0.3),
                    width: _result != null ? 2.5 : 2,
                  ),
                  boxShadow: _result != null
                      ? [BoxShadow(color: AppColors.patient.withValues(alpha: 0.2), blurRadius: 12)]
                      : null,
                ),
                child: _image != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: _annotatedImage != null
                            ? Image.memory(
                                base64Decode(_annotatedImage!),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 280,
                              )
                            : Image.file(
                                _image!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 280,
                              ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_scanType == 'xray' ? Icons.document_scanner : Icons.add_photo_alternate,
                              size: 80, color: AppColors.patient.withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          Text(_scanType == 'xray' ? 'Tap to select X-Ray image' : 'Tap to select oral photo',
                              style: const TextStyle(color: AppColors.textLight, fontSize: 16)),
                          const SizedBox(height: 6),
                          Text('or use Camera / Gallery below',
                              style: TextStyle(color: AppColors.textLight.withValues(alpha: 0.6), fontSize: 12)),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.lightBlue, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _scanType == 'xray'
                        ? 'Upload a clear panoramic dental X-ray. AI will highlight detected regions.'
                        : 'Upload a clear, well-lit oral photo with the affected area visible.',
                    style: const TextStyle(color: AppColors.primary, fontSize: 12),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // Camera / Gallery buttons
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _pickFromCamera,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.patient,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.camera_alt, color: Colors.white),
                  label: const Text('Camera', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _pickFromGallery,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.photo_library, color: Colors.white),
                  label: const Text('Gallery', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            ]),
            const SizedBox(height: 16),

            // Run AI button
            if (_image != null)
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _analyze,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Run AI Prediction', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            const SizedBox(height: 20),

            // Result card
            if (_result != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: AppColors.patient.withValues(alpha: 0.15), blurRadius: 15)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppColors.patientSurface, borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.biotech, color: AppColors.patient, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text('AI Detection Result', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    ]),
                    const Divider(height: 24),

                    // Condition
                    Row(children: [
                      const Icon(Icons.medical_information, color: AppColors.patient, size: 20),
                      const SizedBox(width: 8),
                      const Text('Condition: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Text(_result!['disease'] ?? 'Unknown',
                            style: const TextStyle(color: AppColors.patient, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ]),
                    const SizedBox(height: 14),

                    // Confidence
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Confidence', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('${(_result!['confidence'] ?? 0).toStringAsFixed(1)}%',
                            style: TextStyle(color: _riskColor(_result!['confidence'] ?? 0), fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: (_result!['confidence'] ?? 0) / 100,
                        backgroundColor: AppColors.lightBlue,
                        color: _riskColor(_result!['confidence'] ?? 0),
                        minHeight: 10,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Affected area + Risk
                    Row(children: [
                      const Icon(Icons.area_chart, color: AppColors.accent, size: 20),
                      const SizedBox(width: 8),
                      const Text('Affected Area: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('${_result!['affected_area'] ?? 0}%',
                          style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 16)),
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.warning_amber, color: AppColors.riskHigh, size: 20),
                      const SizedBox(width: 8),
                      const Text('Risk Level: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        (_result!['risk_level'] ?? _riskLabel(_result!['confidence'] ?? 0)).toString(),
                        style: TextStyle(
                          color: _riskColor(_result!['confidence'] ?? 0),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 14),

                    // Description
                    if (_result!['description'] != null)
                      _infoCard(
                        title: 'About this Condition',
                        content: _result!['description'].toString(),
                        color: AppColors.patientSurface,
                        icon: Icons.info_outline,
                        iconColor: AppColors.patient,
                      ),

                    // Symptoms
                    if (_result!['symptoms'] != null)
                      _infoCard(
                        title: 'Symptoms',
                        content: _result!['symptoms'].toString(),
                        color: const Color(0xFFFFF3E0),
                        icon: Icons.sick,
                        iconColor: Colors.orange,
                      ),

                    // Treatment
                    if (_result!['treatment'] != null)
                      _infoCard(
                        title: 'Treatment',
                        content: _result!['treatment'].toString(),
                        color: const Color(0xFFE8F5E9),
                        icon: Icons.medical_services,
                        iconColor: Colors.green,
                      ),

                    // Urgency
                    if (_result!['urgency'] != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(children: [
                          const Icon(Icons.access_time, color: Colors.red, size: 16),
                          const SizedBox(width: 6),
                          const Text('Urgency: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Expanded(
                            child: Text(_result!['urgency'].toString(),
                                style: const TextStyle(fontSize: 13, color: Colors.red, fontWeight: FontWeight.w600)),
                          ),
                        ]),
                      ),

                    // Recommendation
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.lightBlue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Recommendation', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text(
                            (_result!['recommendation'] ?? 'Consult a qualified dentist for evaluation.').toString(),
                            style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textDark),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('⚠️ Please consult a dentist for proper diagnosis.',
                        style: TextStyle(color: AppColors.textLight, fontSize: 13)),
                    const SizedBox(height: 16),

                    // PDF / Print buttons
                    Row(children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final name = await _patientName();
                              if (!mounted) return;
                              await PdfService.generateScanReport(
                                context: context,
                                result: _result!,
                                scanType: _scanType,
                                patientName: name,
                                imageFile: _image,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.download, color: Colors.white),
                            label: const Text('Download PDF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final name = await _patientName();
                              if (!mounted) return;
                              await PdfService.printScanReport(
                                result: _result!,
                                scanType: _scanType,
                                patientName: name,
                                imageFile: _image,
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.patient,
                              side: const BorderSide(color: AppColors.patient),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.print),
                            label: const Text('Print'),
                          ),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _infoCard({
    required String title,
    required String content,
    required Color color,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: iconColor, size: 16),
            const SizedBox(width: 6),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ]),
          const SizedBox(height: 6),
          Text(content, style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textDark)),
        ],
      ),
    );
  }

  String _riskLabel(num confidence) {
    if (confidence >= 80) return 'High';
    if (confidence >= 50) return 'Medium';
    return 'Low';
  }
}