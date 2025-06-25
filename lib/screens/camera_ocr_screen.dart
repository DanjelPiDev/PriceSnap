import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

import '../models/product.dart';

class CameraOCRScreen extends StatefulWidget {
  final void Function(Product) onItemDetected;

  const CameraOCRScreen({super.key, required this.onItemDetected});

  @override
  State<CameraOCRScreen> createState() => _CameraOCRScreenState();
}

class _CameraOCRScreenState extends State<CameraOCRScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _controller;
  late Future<void> _initializeControllerFuture;
  late List<CameraDescription> _cameras;

  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _setupCamera();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulse = Tween(begin: 1.0, end: 1.1).animate(_ctrl);
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
    _ctrl.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _captureAndProcess() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    final tmpDir = await getTemporaryDirectory();
    final imagePath =
        '${tmpDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

    await _controller!.takePicture().then((file) => file.saveTo(imagePath));

    final originalBytes = await File(imagePath).readAsBytes();
    img.Image? originalImage = img.decodeImage(originalBytes);
    late InputImage inputImage;

    if (originalImage != null) {
      img.Image grayImage = img.grayscale(originalImage);
      final grayBytes = img.encodeJpg(grayImage);

      final grayPath = imagePath.replaceFirst('.jpg', '_gray.jpg');
      await File(grayPath).writeAsBytes(grayBytes);

      inputImage = InputImage.fromFilePath(grayPath);
    } else {
      // Fallback to original image if grayscale fails
      inputImage = InputImage.fromFilePath(imagePath);
    }

    final textRecognizer = GoogleMlKit.vision.textRecognizer();
    final recognized = await textRecognizer.processImage(inputImage);
    await textRecognizer.close();

    final allLines = recognized.blocks.expand((b) => b.lines).toList();

    allLines.sort((a, b) {
      final topCmp = a.boundingBox.top.compareTo(b.boundingBox.top);
      if (topCmp != 0) return topCmp;
      return a.boundingBox.left.compareTo(b.boundingBox.left);
    });

    final priceLines = recognized.blocks
        .expand((b) => b.lines)
        .where(
          (l) =>
          RegExp(
            r'^\d{3,4}$',
          ).hasMatch(l.text.replaceAll(RegExp(r'\D'), '')),
    )
        .toList();

    TextLine? bestCandidate;
    for (final line in priceLines) {
      if (bestCandidate == null) {
        bestCandidate = line;
      } else {
        final currBox = line.boundingBox;
        final bestBox = bestCandidate.boundingBox;

        if (currBox.bottom > bestBox.bottom ||
            (currBox.bottom == bestBox.bottom &&
                currBox.right > bestBox.right)) {
          bestCandidate = line;
        }
      }
    }
    if (bestCandidate != null) {
      final price =
          int.parse(bestCandidate.text.replaceAll(RegExp(r'\D'), '')) / 100.0;

      String name = "Unkown Name";

      final allLines = recognized.blocks.expand((b) => b.lines).toList();
      allLines.sort((a, b) {
        final topCmp = a.boundingBox.top.compareTo(b.boundingBox.top);
        if (topCmp != 0) return topCmp;
        return a.boundingBox.left.compareTo(b.boundingBox.left);
      });
      final topLeft = allLines.first;
      final nameTop = topLeft.boundingBox.top;
      final nameLeft = topLeft.boundingBox.left;
      const nameBoxHeight = 60;
      const nameBoxWidth = 350;

      final nameLines = allLines
          .where(
            (l) =>
        (l.boundingBox.top - nameTop).abs() < nameBoxHeight &&
            (l.boundingBox.left - nameLeft).abs() < nameBoxWidth &&
            l.text
                .trim()
                .isNotEmpty &&
            !RegExp(r'^\d{8,}$').hasMatch(l.text.trim()),
      )
          .toList();

      if (nameLines.isNotEmpty) {
        name = nameLines.map((l) => l.text).join(" ");
      }

      widget.onItemDetected(Product(name: name, price: price));
      //Navigator.pop(context);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Product')),
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
                          child: ScaleTransition(
                            scale: _pulse,
                            child: Padding(
                              padding: const EdgeInsets.all(50),
                              child: SizedBox.fromSize(
                                size: const Size(100, 100),
                                child: FloatingActionButton(
                                  backgroundColor: Colors.amberAccent,
                                  onPressed: _captureAndProcess,
                                  child: const Icon(Icons.camera_alt, size: 40),
                                ),
                              ),
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
