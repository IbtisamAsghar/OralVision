import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../viewmodels/image_scan_viewmodel.dart';

class ImageScanView extends ConsumerWidget {
  const ImageScanView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(imageScanViewModelProvider);
    final viewModel = ref.read(imageScanViewModelProvider.notifier);

    // Listen for errors
    ref.listen<ImageScanState>(imageScanViewModelProvider, (previous, next) {
      if (next.error != null &&
          next.error!.isNotEmpty &&
          next.error != previous?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(next.error!)),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textSecondary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Back',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
        ),
        titleSpacing: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(
                    Icons.camera_alt,
                    color: AppColors.textPrimary,
                    size: 28,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Image-Based Detection',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Upload a dental image for AI-powered analysis.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),

              const Text(
                'Type of Image',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              // Image Type Toggle
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => viewModel.toggleImageType(true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: state.isXRay
                              ? AppColors.primaryTeal.withOpacity(0.1)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: state.isXRay
                                ? AppColors.primaryTeal
                                : Colors.grey.shade300,
                            width: state.isXRay ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.accessibility_new_outlined,
                              color: state.isXRay
                                  ? AppColors.primaryTeal
                                  : Colors.grey.shade400,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'X-ray Image',
                              style: TextStyle(
                                color: state.isXRay
                                    ? AppColors.primaryTeal
                                    : AppColors.textSecondary,
                                fontWeight: state.isXRay
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => viewModel.toggleImageType(false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: !state.isXRay
                              ? AppColors.primaryTeal.withOpacity(0.1)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: !state.isXRay
                                ? AppColors.primaryTeal
                                : Colors.grey.shade300,
                            width: !state.isXRay ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_front,
                              color: !state.isXRay
                                  ? AppColors.primaryTeal
                                  : Colors.grey.shade400,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Intraoral Image',
                              style: TextStyle(
                                color: !state.isXRay
                                    ? AppColors.primaryTeal
                                    : AppColors.textSecondary,
                                fontWeight: !state.isXRay
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Upload / Preview Area
              GestureDetector(
                onTap: () => _showPickerOptions(context, viewModel),
                child: Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: state.selectedImage != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.file(
                                state.selectedImage!,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: viewModel.clearImage,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.primaryTeal.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.file_upload_outlined,
                                color: AppColors.primaryTeal,
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Tap to upload or capture',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'PNG, JPG — max 10MB',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // Info Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primaryTeal.withOpacity(0.2),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.primaryTeal,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'For best results, upload a clear, well-lit image. Ensure the affected area is visible.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // Action Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: state.isAnalyzing
                      ? null
                      : () => viewModel.runPrediction(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: state.selectedImage != null
                        ? AppColors.primaryTeal
                        : AppColors.primaryTeal.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: state.isAnalyzing
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Run AI Prediction',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showPickerOptions(BuildContext context, ImageScanViewModel viewModel) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 24.0,
              horizontal: 16.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text(
                  'Choose Image Source',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                ListTile(
                  leading: const Icon(
                    Icons.photo_camera,
                    color: AppColors.primaryTeal,
                  ),
                  title: const Text('Take a Photo'),
                  onTap: () {
                    Navigator.pop(context);
                    viewModel.pickAndCropImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library,
                    color: AppColors.primaryTeal,
                  ),
                  title: const Text('Upload from Gallery'),
                  onTap: () {
                    Navigator.pop(context);
                    viewModel.pickAndCropImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
