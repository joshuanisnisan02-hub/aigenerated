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

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= bytes.length;
    return StreamAudioResponse(
      sourceLength: bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(bytes.sublist(start, end)),
      contentType: 'audio/mpeg',
    );
  }
}
