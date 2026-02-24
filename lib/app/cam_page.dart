import 'dart:io';

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import 'camera_controller.dart' as ocr;

class CamPage extends StatefulWidget {
  const CamPage({super.key});

  @override
  State<CamPage> createState() => _CamPageState();
}

class _CamPageState extends State<CamPage> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isProcessing = false;
  final ImagePicker _picker = ImagePicker();
  String? _extractedText;
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    if (_cameras == null || _cameras!.isEmpty) return;
    _controller = CameraController(
      _cameras!.first,
      ResolutionPreset.high,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _saveFileToUserStorage(String text) async {
    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save OCR Text',
      fileName: 'document.txt',
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );

    if (outputPath != null) {
      final file = File(outputPath);
      await file.writeAsString(text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved at: $outputPath')),
        );
      }
    }
  }

  Future<File?> _pickFromGallery() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );

    if (pickedFile == null) return null;

    return File(pickedFile.path);
  }

  Future<File> _takePicture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      throw StateError('Camera not ready');
    }
    final image = await controller.takePicture();
    return File(image.path);
  }

  Future<File> _preprocessImage(File file) async {
    final original = await img.decodeImageFile(file.path);
    if (original == null) throw StateError('Failed to decode image');

    final grayscale = img.grayscale(original);
    final contrast = img.adjustColor(
      grayscale,
      contrast: 1.5,
    );
    final thresholded = img.luminanceThreshold(
      contrast,
      threshold: 140 / 255,
    );

    final processedBytes = img.encodeJpg(thresholded);
    final processedFile = File('${file.path}_processed.jpg');
    await processedFile.writeAsBytes(processedBytes);

    return processedFile;
  }

  Future<void> _processImage() async {
    if (_isProcessing) return;
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera not ready')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final rawImage = await _takePicture();
      final processedImage = await _preprocessImage(rawImage);
      final text = await ocr.extractText(processedImage);

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _extractedText = text;
          _textController.text = text;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _processGalleryImage() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final imageFile = await _pickFromGallery();

      if (imageFile == null) {
        if (mounted) setState(() => _isProcessing = false);
        return;
      }

      final processedImage = await _preprocessImage(imageFile);
      final text = await ocr.extractText(processedImage);

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _extractedText = text;
          _textController.text = text;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_extractedText != null) {
      return _buildTextEditor();
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(controller),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: _isProcessing
                ? const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: _processImage,
                          child: const Text('Scan with Camera'),
                        ),
                        ElevatedButton(
                          onPressed: _processGalleryImage,
                          child: const Text('Select from Gallery'),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextEditor() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OCR Result'),
        actions: [
          TextButton(
            onPressed: () async {
              await _saveFileToUserStorage(_textController.text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _textController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: 'Edit extracted text...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  setState(() => _extractedText = null);
                },
                child: const Text('Scan Again'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
