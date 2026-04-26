import 'dart:typed_data';

Future<String> writeBytesToTempFile(Uint8List bytes, String filename) {
  return Future<String>.error(
    UnsupportedError('Temporary file writing is not supported on this platform.'),
  );
}
