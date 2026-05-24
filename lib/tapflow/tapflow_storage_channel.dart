import 'dart:async';

import 'package:flutter/services.dart';

class TapFlowStorageChannel {
  static const MethodChannel _ch = MethodChannel('tapflow/storage');

  Future<String?> saveToDownloads({
    required String srcPath,
    required String displayName,
    String? mimeType,
    String relativeDir = 'TapFlow',
  }) async {
    final res = await _ch.invokeMethod<String>('saveToDownloads', {
      'srcPath': srcPath,
      'displayName': displayName,
      'mimeType': mimeType,
      'relativeDir': relativeDir,
    });
    return res;
  }
}
