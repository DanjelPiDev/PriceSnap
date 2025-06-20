import 'package:google_ml_kit/google_ml_kit.dart';

class OcrService {
  final _textRecognizer = GoogleMlKit.vision.textRecognizer();

  Future<List<String>> extractLines(InputImage img) async {
    final result = await _textRecognizer.processImage(img);
    await _textRecognizer.close();
    return result.blocks
        .expand((b) => b.lines)
        .map((l) => l.text.trim())
        .toList();
  }
}
