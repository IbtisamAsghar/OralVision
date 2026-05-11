import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../core/theme/app_colors.dart';

class ImageScanState {
  final bool isXRay;
  final File? selectedImage;
  final bool isAnalyzing;
  final String? error;

  ImageScanState({
    this.isXRay = true,
    this.selectedImage,
    this.isAnalyzing = false,
    this.error,
  });

  ImageScanState copyWith({
    bool? isXRay,
    File? selectedImage,
    bool? isAnalyzing,
    String? error,
  }) {
    return ImageScanState(
      isXRay: isXRay ?? this.isXRay,
      selectedImage: selectedImage ?? this.selectedImage,
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      error: error, // Clear error if null is passed
    );
  }
}

class ImageScanViewModel extends Notifier<ImageScanState> {
  final ImagePicker _picker = ImagePicker();

  @override
  ImageScanState build() {
    return ImageScanState();
  }

  void toggleImageType(bool isXRay) {
    state = state.copyWith(isXRay: isXRay, error: null);
  }

  void clearImage() {
    state = state.copyWith(selectedImage: null, error: null);
  }

  Future<void> pickAndCropImage(ImageSource source) async {
    try {
      state = state.copyWith(error: null);

      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFile.path,
          compressFormat: ImageCompressFormat.jpg,
          compressQuality: 90,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Crop Image',
              toolbarColor: AppColors.primaryTeal,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.original,
              lockAspectRatio: false,
            ),
            IOSUiSettings(
              title: 'Crop Image',
            ),
          ],
        );

        if (croppedFile != null) {
          state = state.copyWith(selectedImage: File(croppedFile.path));
        }
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to pick image: ${e.toString()}');
    }
  }

  Future<void> runPrediction() async {
    if (state.selectedImage == null) {
      state = state.copyWith(error: 'Please select an image first.');
      return;
    }

    state = state.copyWith(isAnalyzing: true, error: null);

    try {
      // TODO: Mocking the API call for now (waiting for FastAPI module)
      await Future.delayed(const Duration(seconds: 3));
      
      state = state.copyWith(isAnalyzing: false);
      // Navigation will be handled in the view by listening to state changes
    } catch (e) {
      state = state.copyWith(
        isAnalyzing: false, 
        error: 'Prediction failed: ${e.toString()}',
      );
    }
  }
}

final imageScanViewModelProvider =
    NotifierProvider<ImageScanViewModel, ImageScanState>(() {
  return ImageScanViewModel();
});
