import 'dart:typed_data';

import 'roleplay_realtime_audio_probe.dart';

Future<String?> writeRoleplayProbeWav({
  required RoleplayPcmPipelineProbe probe,
  int? sampleRateOverride,
}) async =>
    null;

Future<void> writeRoleplayProbeCompareNote({
  required String? rawPath,
  required String? sentPath,
  required Uint8List rawPcm,
  required Uint8List sentPcm,
}) async {}
