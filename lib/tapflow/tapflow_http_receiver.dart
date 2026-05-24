import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tapflow_models.dart';
import 'tapflow_storage_channel.dart';

class TapFlowHttpReceiver {
  TapFlowHttpReceiver({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              sendTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 90),
            ),
          );

  final Dio _dio;
  final TapFlowStorageChannel _storage = TapFlowStorageChannel();
  CancelToken? _cancelToken;

  bool get isReceiving => _cancelToken != null;

  Future<TapFlowReceivedFile> download({
    required TapFlowOffer offer,
    required void Function(TapFlowTransferProgress progress) onProgress,
  }) async {
    if (_cancelToken != null) {
      throw StateError('Receiver already active');
    }

    final safeName = offer.fileName.trim().isEmpty ? 'file' : offer.fileName;
    final tmpDir = await getTemporaryDirectory();
    final tmpPath = p.join(
      tmpDir.path,
      '${DateTime.now().millisecondsSinceEpoch}_$safeName',
    );

    final cancel = CancelToken();
    _cancelToken = cancel;

    try {
      var attempt = 0;
      while (true) {
        attempt++;
        try {
          // Give Wi‑Fi Direct some time to finish routing after NFC handshake.
          if (attempt == 1) {
            await Future<void>.delayed(const Duration(milliseconds: 700));
          }

          // Warm up connection (some devices open routing a bit later than connect()).
          await _dio.getUri<dynamic>(
            offer.pingUri,
            cancelToken: cancel,
            options: Options(
              responseType: ResponseType.plain,
              followRedirects: false,
              validateStatus: (code) =>
                  code != null && code >= 200 && code < 300,
            ),
          );

          await _dio.download(
            offer.downloadUri.toString(),
            tmpPath,
            cancelToken: cancel,
            onReceiveProgress: (received, total) {
              onProgress(
                TapFlowTransferProgress(received: received, total: total),
              );
            },
            options: Options(
              responseType: ResponseType.stream,
              followRedirects: false,
              validateStatus: (code) =>
                  code != null && code >= 200 && code < 300,
            ),
          );
          break;
        } catch (e) {
          if (e is DioException && CancelToken.isCancel(e)) rethrow;
          if (attempt >= 5) rethrow;
          try {
            final f = File(tmpPath);
            if (await f.exists()) await f.delete();
          } catch (_) {}
          await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
        }
      }

      final saved = await _storage.saveToDownloads(
        srcPath: tmpPath,
        displayName: safeName,
        relativeDir: 'TapFlow',
      );

      final tmpFile = File(tmpPath);
      final tmpSize = await tmpFile.length();
      try {
        await tmpFile.delete();
      } catch (_) {}

      final outPath = (saved == null || saved.isEmpty) ? tmpPath : saved;
      final size = offer.size > 0 ? offer.size : tmpSize;
      return TapFlowReceivedFile(path: outPath, fileName: safeName, size: size);
    } finally {
      _cancelToken = null;
    }
  }

  void cancel() {
    _cancelToken?.cancel('cancelled');
    _cancelToken = null;
  }
}
