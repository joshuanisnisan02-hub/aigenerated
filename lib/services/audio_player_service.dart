import 'dart:async';
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';

class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<ProcessingState>? _completionSubscription;

  AudioPlayerService() {
    _completionSubscription = _player.processingStateStream.listen((state) async {
      // just_audio can keep `playing == true` after the audio reaches the end.
      // Explicitly stopping here guarantees the UI receives `playing == false`,
      // so Lakbay's speaking animation stops with the voice.
      if (state == ProcessingState.completed) {
        await _player.stop();
      }
    });
  }

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  Future<void> playBytes(Uint8List bytes) async {
    await _player.stop();
    await _player.setAudioSource(_BytesAudioSource(bytes));
    await _player.play();
  }

  Future<void> stop() => _player.stop();

  Future<void> dispose() async {
    await _completionSubscription?.cancel();
    await _player.dispose();
  }
}

class _BytesAudioSource extends StreamAudioSource {
  _BytesAudioSource(this.bytes);
  final Uint8List bytes;

  String get _contentType {
    // Gemini TTS fallback is wrapped as a standard RIFF/WAV file, while
    // ElevenLabs returns MP3. Detect the container instead of forcing MP3.
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x41 &&
        bytes[10] == 0x56 &&
        bytes[11] == 0x45) {
      return 'audio/wav';
    }
    return 'audio/mpeg';
  }

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= bytes.length;
    return StreamAudioResponse(
      sourceLength: bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(bytes.sublist(start, end)),
      contentType: _contentType,
    );
  }
}
