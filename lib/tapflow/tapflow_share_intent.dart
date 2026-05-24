import 'dart:async';
import 'dart:io';

import 'package:receive_sharing_intent/receive_sharing_intent.dart';

class TapFlowShareIntent {
  TapFlowShareIntent();

  StreamSubscription<List<SharedMediaFile>>? _sub;

  void listen({required void Function(File file) onFile}) {
    _sub?.cancel();

    _sub = ReceiveSharingIntent.instance.getMediaStream().listen((files) {
      if (files.isEmpty) return;
      final f = files.first;
      if (f.path.trim().isEmpty) return;
      onFile(File(f.path));
    });

    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      if (files.isEmpty) return;
      final f = files.first;
      if (f.path.trim().isEmpty) return;
      onFile(File(f.path));
      ReceiveSharingIntent.instance.reset();
    });
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
