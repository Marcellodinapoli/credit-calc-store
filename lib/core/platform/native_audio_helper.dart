import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Registrazione e riproduzione audio per Warm-up (mobile/desktop nativo).
class NativeAudioHelper {
  NativeAudioHelper._();

  static final AudioRecorder _recorder = AudioRecorder();
  static final AudioPlayer _player = AudioPlayer();
  static String? _recordingPath;

  static Future<void> startRecording() async {
    if (!await _recorder.hasPermission()) {
      throw Exception('Permesso microfono negato');
    }
    final dir = await getTemporaryDirectory();
    _recordingPath =
        '${dir.path}/creditcore_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: _recordingPath!,
    );
  }

  static Future<List<int>> stopRecording() async {
    final path = await _recorder.stop();
    final filePath = path ?? _recordingPath;
    if (filePath == null || filePath.isEmpty) return [];
    final bytes = await File(filePath).readAsBytes();
    _recordingPath = filePath;
    return bytes;
  }

  static Future<void> playRecording({String? path}) async {
    final filePath = path ?? _recordingPath;
    if (filePath == null || filePath.isEmpty) return;
    await _player.stop();
    await _player.play(DeviceFileSource(filePath));
  }

  static Future<void> disposePlayer() async {
    await _player.dispose();
  }
}
