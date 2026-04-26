import 'dart:io';
import 'dart:typed_data';

Future<String> writeBytesToTempFile(Uint8List bytes, String filename) async {
  final Directory tempDir = Directory.systemTemp;
  final File file = File('${tempDir.path}/$filename');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
