import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/decrypt/audio_decryptor.dart';

typedef DownloadAudioDecryptor =
    Future<void> Function({
      required File input,
      required File output,
      required String encodedParameters,
    });

final downloadAudioDecryptorProvider = Provider<DownloadAudioDecryptor>(
  (ref) => decryptAudioFile,
);
