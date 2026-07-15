// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

/// Registrazione e riproduzione audio Warm-up (browser / PC web).
class NativeAudioHelper {
  NativeAudioHelper._();

  static html.MediaRecorder? _recorder;
  static html.MediaStream? _stream;
  static String? _audioUrl;
  static final List<html.Blob> _chunks = [];
  static Completer<List<int>>? _stopCompleter;

  static Future<void> startRecording() async {
    _stream =
        await html.window.navigator.mediaDevices?.getUserMedia({'audio': true});
    if (_stream == null) {
      throw Exception('Permesso microfono negato');
    }

    _chunks.clear();
    _recorder = html.MediaRecorder(
      _stream!,
      {'mimeType': 'audio/webm;codecs=opus'},
    );

    _recorder!.addEventListener('dataavailable', (event) {
      final blobEvent = event as html.BlobEvent;
      if (blobEvent.data != null && blobEvent.data!.size > 0) {
        _chunks.add(blobEvent.data!);
      }
    });

    _recorder!.addEventListener('stop', (event) {
      unawaited(_finalizeRecording());
    });

    _recorder!.start(250);
  }

  static Future<void> _finalizeRecording() async {
    final completer = _stopCompleter;
    if (completer == null || completer.isCompleted) return;

    try {
      if (_chunks.isEmpty) {
        completer.complete([]);
        return;
      }

      final blob = html.Blob(_chunks, 'audio/webm');
      _audioUrl = html.Url.createObjectUrlFromBlob(blob);

      final reader = html.FileReader();
      reader.readAsArrayBuffer(blob);
      await reader.onLoad.first;

      final result = reader.result;
      if (result is ByteBuffer) {
        completer.complete(result.asUint8List().toList());
        return;
      }
      completer.complete([]);
    } catch (e, stack) {
      completer.completeError(e, stack);
    } finally {
      _releaseStream();
    }
  }

  static void _releaseStream() {
    final tracks = _stream?.getAudioTracks() ?? [];
    for (final track in tracks) {
      track.stop();
    }
    _stream = null;
    _recorder = null;
  }

  static Future<List<int>> stopRecording() async {
    final recorder = _recorder;
    if (recorder == null) return [];

    _stopCompleter = Completer<List<int>>();
    recorder.stop();
    return _stopCompleter!.future.whenComplete(() {
      _stopCompleter = null;
    });
  }

  static Future<void> playRecording({String? path}) async {
    if (_audioUrl == null) return;
    html.AudioElement(_audioUrl!)..play();
  }

  static Future<void> disposePlayer() async {}
}
