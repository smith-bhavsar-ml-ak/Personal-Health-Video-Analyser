import 'dart:io';
import 'dart:typed_data';

Future<Uint8List> fetchAudioBytes(String path) => File(path).readAsBytes();

/// No-op on native — audio unlock only needed on web.
void unlockWebAudio() {}

Future<void> playAudioBytesOnWeb(Uint8List bytes) async {
  throw UnsupportedError('Web audio not supported on this platform');
}
