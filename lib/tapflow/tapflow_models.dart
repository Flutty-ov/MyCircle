import 'dart:typed_data';

enum TapFlowStage {
  standby,
  waitingForTap,
  handshake,
  incomingRequest,
  connecting,
  transferring,
  completed,
  error,
}

class TapFlowOffer {
  const TapFlowOffer({
    required this.sessionId,
    required this.host,
    required this.port,
    required this.fileName,
    required this.size,
    this.p2pAddress,
  });

  final String sessionId;
  final String host;
  final int port;
  final String fileName;
  final int size;
  final String? p2pAddress;

  Uri get downloadUri =>
      Uri.parse('http://$host:$port/tapflow/$sessionId/file');

  Uri get pingUri => Uri.parse('http://$host:$port/tapflow/$sessionId/ping');

  Uri get metaUri => Uri.parse('http://$host:$port/tapflow/$sessionId/meta');

  Map<String, Object?> toJson() => {
    'sessionId': sessionId,
    'host': host,
    'port': port,
    'fileName': fileName,
    'size': size,
    'p2pAddress': p2pAddress,
  };

  static TapFlowOffer fromJson(Map<String, Object?> json) {
    return TapFlowOffer(
      sessionId: json['sessionId'] as String,
      host: json['host'] as String,
      port: (json['port'] as num).toInt(),
      fileName: json['fileName'] as String,
      size: (json['size'] as num).toInt(),
      p2pAddress: json['p2pAddress']?.toString(),
    );
  }
}

class TapFlowIncomingRequest {
  const TapFlowIncomingRequest({
    required this.offer,
    this.peerName,
    this.supabaseConfig,
  });

  final TapFlowOffer offer;
  final String? peerName;
  final TapFlowSupabaseConfig? supabaseConfig;
}

class TapFlowTransferProgress {
  const TapFlowTransferProgress({required this.received, required this.total});

  final int received;
  final int total;

  double get ratio => total <= 0 ? 0.0 : received / total;
}

class TapFlowReceivedFile {
  const TapFlowReceivedFile({
    required this.path,
    required this.fileName,
    required this.size,
    this.bytesPreview,
  });

  final String path;
  final String fileName;
  final int size;
  final Uint8List? bytesPreview;
}

class TapFlowSupabaseConfig {
  const TapFlowSupabaseConfig({required this.url, required this.anonKey});

  final String url;
  final String anonKey;
}
