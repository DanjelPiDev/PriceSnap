import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:path_provider/path_provider.dart';

import '../models/item.dart';

class CameraOCRScreen extends StatefulWidget {
  final void Function(Item) onItemDetected;

  const CameraOCRScreen({super.key, required this.onItemDetected});

  @override
  State<CameraOCRScreen> createState() => _CameraOCRScreenState();
}

class _CameraOCRScreenState extends State<CameraOCRScreen> {
  CameraController? _controller;
  late Future<void> _initializeControllerFuture;
  late List<CameraDescription> _cameras;

  @override
  void initState() {
    super.initState();
    _setupCamera();
  }

  Future<void> _setupCamera() async {
    _cameras = await availableCameras();
    final backCamera = _cameras.firstWhere(
          (cam) => cam.lensDirection == CameraLensDirection.back,
    );

    _controller = CameraController(backCamera, ResolutionPreset.high);
    _initializeControllerFuture = _controller!.initialize();
    setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _captureAndProcess() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    final tmpDir = await getTemporaryDirectory();
    final imagePath = '${tmpDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

    await _controller!.takePicture().then((file) => file.saveTo(imagePath));

    final inputImage = InputImage.fromFilePath(imagePath);
    final textRecognizer = GoogleMlKit.vision.textRecognizer();
    final recognized = await textRecognizer.processImage(inputImage);
    await textRecognizer.close();

    final lines = recognized.blocks
        .expand((b) => b.lines)
        .map((l) => l.text.trim())
        .toList();
    print("OCR LINES:");
    print(lines);

    List<String> nameBuffer = [];
    final weightRegEx = RegExp(r'\d+[.,]?\d*\s*(g|kg|ml|l)\b', caseSensitive: false);

    final ignorePatterns = [
      RegExp(r'^[=/]+$'),  // Lines with only symbols
      RegExp(r'^\d+[\s-]+\d+$'),  // Numbers with separators
    ];

    for (final line in lines) {
      final cleaned = line.replaceAll('€', '').replaceAll(',', '.').trim();
      if (ignorePatterns.any((p) => p.hasMatch(cleaned))) {
        continue;
      }

      // skip weights
      if (weightRegEx.hasMatch(cleaned) ||
          cleaned.contains('=') ||
          cleaned.toLowerCase().startsWith('kg')) {
        continue;
      }

      // exact decimal price
      final priceExact = RegExp(r'^\d+\.\d{1,2}$');
      if (priceExact.hasMatch(cleaned)) {
        final price = double.tryParse(cleaned);
        print("Exact price found: $cleaned -> $price");
        if (price != null && nameBuffer.isNotEmpty) {
          widget.onItemDetected(Item(name: nameBuffer.join(' '), price: price));
          Navigator.pop(context);
          return;
        }
        continue;
      }

      // integer fallback, e.g. 399 -> 3.99
      final onlyDigits = RegExp(r'^\d{3,}$');
      if (onlyDigits.hasMatch(cleaned)) {
        final integerValue = int.tryParse(cleaned);
        if (integerValue != null) {
          final price = integerValue / 100.0;
          print("Integer price found: $cleaned -> $price");
          if (nameBuffer.isNotEmpty) {
            widget.onItemDetected(Item(name: nameBuffer.join(' '), price: price));
            Navigator.pop(context);
            return;
          }
        }
        continue;
      }

      // accumulate name parts
      if (RegExp(r'[A-Za-zÄÖÜäöüß]').hasMatch(cleaned)) {
        nameBuffer.add(cleaned);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kamera Scan')),
      body: SafeArea(
        child: _controller == null
            ? const Center(child: CircularProgressIndicator())
            : FutureBuilder(
          future: _initializeControllerFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return Stack(
                children: [
                  CameraPreview(_controller!),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.camera_alt),
                        label: const Text("Foto & OCR"),
                        onPressed: _captureAndProcess,
                      ),
                    ),
                  ),
                ],
              );
            } else {
              return const Center(child: CircularProgressIndicator());
            }
          },
        ),
      ),
    );
  }
}