import 'dart:io';

import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image/image.dart' as img;

import '../../models/product.dart';
import '../../utils/file_utils.dart';
import '../../utils/store_utils.dart';
import 'capture_processor.dart';


class ReweCaptureProcessor implements CaptureProcessor {
  @override
  Future<Product?> captureAndProcess(
      CameraController controller,
      void Function(Product) onItemDetected,
      ) async {
    final recognized = await _captureText(controller);
    final product = detectReweProduct(recognized);
    onItemDetected(product);
    return product;
  }

  Future<RecognizedText> _captureText(CameraController controller) async {
    // identical to Generic, because I did the rewe detection first (other stores are planned)
    final tmpDir = await FileUtils.getTemporaryDirectory();
    final imagePath =
        '${tmpDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

    final XFile file = await controller.takePicture();
    await file.saveTo(imagePath);

    final bytes = await File(imagePath).readAsBytes();
    final original = img.decodeImage(bytes);
    late InputImage inputImage;

    if (original != null) {
      final gray = img.grayscale(original);
      final grayBytes = img.encodeJpg(gray);
      final grayPath = imagePath.replaceFirst('.jpg', '_gray.jpg');
      await File(grayPath).writeAsBytes(grayBytes);
      inputImage = InputImage.fromFilePath(grayPath);
    } else {
      inputImage = InputImage.fromFilePath(imagePath);
    }

    final recognizer = GoogleMlKit.vision.textRecognizer();
    final result = await recognizer.processImage(inputImage);
    await recognizer.close();
    return result;
  }

  Product detectReweProduct(RecognizedText recognized) {
    final allLines = recognized.blocks.expand((b) => b.lines).toList();
    allLines.sort((a, b) {
      final topCmp = a.boundingBox.top.compareTo(b.boundingBox.top);
      if (topCmp != 0) return topCmp;
      return a.boundingBox.left.compareTo(b.boundingBox.left);
    });

    final priceLines = allLines.where((l) {
      final digits = l.text.replaceAll(RegExp(r'\D'), '');
      return RegExp(r'^\d{3,4}\$').hasMatch(digits);
    }).toList();

    TextLine? bestCandidate;
    for (final line in priceLines) {
      if (bestCandidate == null) {
        bestCandidate = line;
      } else {
        final curr = line.boundingBox;
        final best = bestCandidate.boundingBox;
        if (curr.bottom > best.bottom ||
            (curr.bottom == best.bottom && curr.right > best.right)) {
          bestCandidate = line;
        }
      }
    }

    double price = 0.0;
    if (bestCandidate != null) {
      final digits = bestCandidate.text.replaceAll(RegExp(r'\D'), '');
      price = int.parse(digits) / 100.0;
    }

    String name = 'Unknown Name';
    if (allLines.isNotEmpty) {
      final topLeft = allLines.first;
      final nameTop = topLeft.boundingBox.top;
      final nameLeft = topLeft.boundingBox.left;
      const nameBoxHeight = 60;
      const nameBoxWidth = 350;

      final nameLines = allLines.where((l) {
        final dy = (l.boundingBox.top - nameTop).abs();
        final dx = (l.boundingBox.left - nameLeft).abs();
        return dy < nameBoxHeight && dx < nameBoxWidth &&
            l.text.trim().isNotEmpty &&
            !RegExp(r'^\d{8,}\$').hasMatch(l.text.trim());
      }).toList();

      if (nameLines.isNotEmpty) {
        name = nameLines.map((l) => l.text).join(' ');
      }
    }

    return Product(name: name, price: price, store: Store.rewe);
  }

}