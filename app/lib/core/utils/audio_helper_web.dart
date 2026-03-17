import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// Singleton AudioContext — created during a user gesture so the browser
/// never blocks playback, no matter how long the API call takes.
web.AudioContext? _audioCtx;

/// Call this during a user gesture (mic button tap) to unlock Web Audio API.
void unlockWebAudio() {
  if (_audioCtx == null) {
    _audioCtx = web.AudioContext();
  } else if (_audioCtx!.state == 'suspended') {
    _audioCtx!.resume();
  }
}

Future<Uint8List> fetchAudioBytes(String blobUrl) async {
  final response = await web.window.fetch(blobUrl.toJS).toDart;
  final buffer   = await response.arrayBuffer().toDart;
  return buffer.toDart.asUint8List();
}

Future<void> playAudioBytesOnWeb(Uint8List bytes) async {
  // Use the pre-unlocked AudioContext — immune to autoplay policy
  final ctx = _audioCtx ?? web.AudioContext();
  _audioCtx = ctx;

  if (ctx.state == 'suspended') {
    await ctx.resume().toDart;
  }

  // Ensure we have a contiguous copy before converting to JSArrayBuffer
  final copy     = Uint8List.fromList(bytes);
  final jsBuffer = copy.buffer.toJS;

  // Decode MP3/WAV → AudioBuffer → play
  final audioBuffer = await ctx.decodeAudioData(jsBuffer).toDart;
  final source      = ctx.createBufferSource();
  source.buffer     = audioBuffer;
  source.connect(ctx.destination);
  source.start();
}
