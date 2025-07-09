import 'dart:io';
import 'package:path_provider/path_provider.dart' as pp;

class FileUtils {

  static Future<Directory> getTemporaryDirectory() async {
    return await pp.getTemporaryDirectory();
  }

  static Future<String> getTemporaryDirectoryPath() async {
    final dir = await getTemporaryDirectory();
    return dir.path;
  }
}
