import 'package:camera/camera.dart';
import 'package:price_snap/services/ocr/rewe_capture_processor.dart';

import '../../models/product.dart';
import '../../utils/store_utils.dart';
import 'generic_capture_processor.dart';

abstract class CaptureProcessor {
  Future<Product?> captureAndProcess(
      CameraController controller,
      void Function(Product) onItemDetected,
      );
}

class CaptureProcessorFactory {
  static CaptureProcessor forStore(Store store) {
    switch (store) {
      case Store.rewe:
        return ReweCaptureProcessor();
      default:
        return GenericCaptureProcessor();
    }
  }
}