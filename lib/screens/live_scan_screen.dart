import 'dart:convert';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:http/http.dart' as http;

import '../models/item.dart';
import '../services/rewe/rewe_product_match.dart';

class LiveScanScreen extends StatefulWidget {
  final Function(Item) onItemConfirmed;

  const LiveScanScreen({required this.onItemConfirmed, super.key});

  @override
  State<LiveScanScreen> createState() => _LiveScanScreenState();
}

class _LiveScanScreenState extends State<LiveScanScreen> {
  CameraController? _cameraController;

  Item? _detectedItem;
  bool _isDetecting = false;
  String _recognizedText = '';
  List<Rect> _rects = [];
  int _frameCounter = 0;

  final TextRecognizer _textRecognizer = GoogleMlKit.vision.textRecognizer();
  final BarcodeScanner _barcodeScanner = GoogleMlKit.vision.barcodeScanner();

  final ReweService _rewe = ReweService();

  @override
  void initState() {
    super.initState();
    initCamera();
  }

  void initCamera() async {
    final cameras = await availableCameras();
    final camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
    );
    _cameraController = CameraController(camera, ResolutionPreset.medium);
    await _cameraController!.initialize();

    await _cameraController!.setFocusMode(FocusMode.auto);
    await _cameraController!.setExposureMode(ExposureMode.auto);

    setState(() {});

    final rotation = InputImageRotationValue.fromRawValue(
      _cameraController!.description.sensorOrientation,
    )!;

    _cameraController!.startImageStream((image) async {
      if (_isDetecting) return;
      _isDetecting = true;

      if (++_frameCounter % 2 != 0) {
        _isDetecting = false;
        return;
      }

      try {
        Uint8List allBytes = Uint8List.fromList(
          image.planes.expand((plane) => plane.bytes).toList(),
        );
        final inputImage = InputImage.fromBytes(
          bytes: allBytes,
          metadata: InputImageMetadata(
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: rotation,
            format: InputImageFormat.nv21,
            bytesPerRow: image.planes[0].bytesPerRow,
          ),
        );

        // OCR
        final recognized = await _textRecognizer.processImage(inputImage);
        final allText = recognized.blocks
            .expand((block) => block.lines)
            .map((line) => line.text.trim())
            .where((line) => line.isNotEmpty)
            .join(' ');

        final barcodes = await _barcodeScanner.processImage(inputImage);
        String? barcodeValue = barcodes.isNotEmpty
            ? barcodes.first.rawValue
            : null;

        // Barcode prio is higher than OCR
        if (barcodeValue != null) {
          // GET https://world.openfoodfacts.org/api/v0/product/xxxxxxxxxxx.json
          final apiUrl = 'https://world.openfoodfacts.org/api/v0/product';
          try {
            final resp = await http.get(
              Uri.parse('$apiUrl/$barcodeValue.json'),
            );
            if (resp.statusCode == 200) {
              final data = jsonDecode(resp.body);
              final name = data['product_name'] ?? barcodeValue;
              final image = data['selected_images']['front']['display']['de'];
              setState(() {
                _recognizedText = name;
                _rects = barcodes.map((b) => b.boundingBox).toList();
                _detectedItem = Item(name: name, price: 0, imageUrl: image);
              });

              widget.onItemConfirmed(
                Item(name: name, price: 0, imageUrl: image),
              );
              Navigator.pop(context);
              return;
            }
          } catch (e) {
            print("Barcode-API Error: $e");
          }
        }

        // Fallback: OCR
        setState(() {
          _recognizedText = allText;
          _rects = recognized.blocks.map((e) => e.boundingBox).toList();
          _detectedItem = Item(name: allText, price: 0);
        });
      } catch (e) {
        if (kDebugMode) {
          print('Live MLKit error: $e');
        }
      }

      _isDetecting = false;
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _textRecognizer.close();
    _barcodeScanner.close();
    super.dispose();
  }

  List<Widget> _itemPreviewChildren() {
    return [
      _detectedItem!.imageUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                _detectedItem!.imageUrl!,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
              ),
            )
          : const Icon(Icons.image, size: 50, color: Colors.white54),
      const SizedBox(width: 12, height: 12),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Text(
              _detectedItem!.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          Flexible(
            child: Text(
              '${_detectedItem!.price.toStringAsFixed(2)} €',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final previewSize = _cameraController!.value.previewSize!;
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    final cameraSize = Size(
      isPortrait ? previewSize.height : previewSize.width,
      isPortrait ? previewSize.width : previewSize.height,
    );

    return Scaffold(
      appBar: AppBar(title: const Text("Live Scan")),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final widgetSize = Size(constraints.maxWidth, constraints.maxHeight);

          return Stack(
            children: [
              CameraPreview(_cameraController!),
              Positioned.fill(
                child: CustomPaint(
                  painter: BoxPainter(
                    _rects,
                    imageSize: cameraSize,
                    widgetSize: widgetSize,
                  ),
                ),
              ),
              if (_detectedItem != null)
                Align(
                  alignment: isPortrait
                      ? Alignment.topCenter
                      : Alignment.centerRight,
                  child: RotatedBox(
                    quarterTurns: isPortrait ? 0 : 1,
                    child: Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.all(12),
                      constraints: BoxConstraints(
                        maxWidth: isPortrait ? widgetSize.width * 0.7 : widgetSize.height * 0.7,
                        maxHeight: isPortrait ? widgetSize.height * 0.3 : widgetSize.width * 0.3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: isPortrait
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: _itemPreviewChildren(),
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: _itemPreviewChildren(),
                            ),
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  minimum: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    color: Colors.black54,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.check,
                            color: Colors.green,
                            size: 48,
                          ),
                          onPressed: () async {
                            if (_recognizedText.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("No Text!")),
                              );
                              return;
                            }
                            final match = await _rewe.matchProduct(
                              _recognizedText,
                            );
                            if (match != null) {
                              widget.onItemConfirmed(
                                Item(
                                  name: match.name,
                                  price: match.price ?? 0,
                                  imageUrl: match.imageUrl,
                                ),
                              );
                            } else {
                              widget.onItemConfirmed(
                                Item(name: _recognizedText, price: 0),
                              );
                            }
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class BoxPainter extends CustomPainter {
  final List<Rect> rects;
  final Size imageSize;
  final Size widgetSize;

  BoxPainter(this.rects, {required this.imageSize, required this.widgetSize});

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = widgetSize.width / imageSize.width;
    final scaleY = widgetSize.height / imageSize.height;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.yellowAccent;

    for (var rect in rects) {
      final scaledRect = Rect.fromLTRB(
        rect.left * scaleX,
        rect.top * scaleY,
        rect.right * scaleX,
        rect.bottom * scaleY,
      );
      canvas.drawRect(scaledRect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
