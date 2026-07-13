import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';

import 'roleplay_realtime_audio.dart';

RoleplayRealtimeAudio createRoleplayRealtimeAudio() =>
    RoleplayRealtimeAudioNative();

class RoleplayRealtimeAudioNative implements RoleplayRealtimeAudio {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<Uint8List>? _micSubscription;
  final List<Future<void>> _playbackQueue = [];
  bool _playing = false;

  @override
  Future<void> startMicrophone(void Function(List<int> pcmChunk) onChunk) async {
    if (!await _recorder.hasPermission()) {
      throw Exception('Permesso microfono negato.');
    }

    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 24000,
        numChannels: 1,
      ),
    );

    await _micSubscription?.cancel();
    _micSubscription = stream.listen((chunk) => onChunk(chunk));
  }

  @override
  Future<void> stopMicrophone() async {
    await _micSubscription?.cancel();
    _micSubscription = null;
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
  }

  @override
  Future<void> playPcm16Base64Delta(String base64Delta) async {
    final pcm = base64Decode(base64Delta);
    if (pcm.isEmpty) return;
    final wav = _pcm16ToWav(pcm, sampleRate: 24000);
    _playbackQueue.add(_enqueuePlayback(wav));
    if (!_playing) {
      _playing = true;
      unawaited(_drainPlaybackQueue());
    }
  }

  Future<void> _enqueuePlayback(Uint8List wav) async {
    await _player.stop();
    await _player.play(BytesSource(wav));
    await _player.onPlayerComplete.first;
  }

  Future<void> _drainPlaybackQueue() async {
    while (_playbackQueue.isNotEmpty) {
      final pending = _playbackQueue.removeAt(0);
      await pending;
    }
    _playing = false;
  }

  @override
  Future<void> stopPlayback() async {
    _playbackQueue.clear();
    _playing = false;
    await _player.stop();
  }

  @override
  Future<void> dispose() async {
    await stopMicrophone();
    await stopPlayback();
    await _recorder.dispose();
    await _player.dispose();
  }

  Uint8List _pcm16ToWav(Uint8List pcm, {required int sampleRate}) {
    const channels = 1;
    const bitsPerSample = 16;
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;
    final dataSize = pcm.length;
    final fileSize = 36 + dataSize;

    final header = ByteData(44);
    header.setUint8(0, 0x52); // R
    header.setUint8(1, 0x49); // I
    header.setUint8(2, 0x46); // F
    header.setUint8(3, 0x46); // F
    header.setUint32(4, fileSize, Endian.little);
    header.setUint8(8, 0x57); // W
    header.setUint8(9, 0x41); // A
    header.setUint8(10, 0x56); // V
    header.setUint8(11, 0x45); // E
    header.setUint8(12, 0x66); // f
    header.setUint8(13, 0x6d); // m
    header.setUint8(14, 0x74); // t
    header.setUint8(15, 0x20); // space
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    header.setUint8(36, 0x64); // d
    header.setUint8(37, 0x61); // a
    header.setUint8(38, 0x74); // t
    header.setUint8(39, 0x61); // a
    header.setUint32(40, dataSize, Endian.little);

    final wav = Uint8List(44 + dataSize);
    wav.setRange(0, 44, header.buffer.asUint8List());
    wav.setRange(44, 44 + dataSize, pcm);
    return wav;
  }
}
