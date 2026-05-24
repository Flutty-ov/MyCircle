import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import 'tapflow_http_receiver.dart';
import 'tapflow_http_sender.dart';
import 'tapflow_models.dart';
import 'tapflow_nfc_channel.dart';
import 'tapflow_p2p_channel.dart';

class TapFlowService {
  TapFlowService({
    TapFlowHttpSender? sender,
    TapFlowHttpReceiver? receiver,
    TapFlowNfcChannel? nfc,
    TapFlowP2pChannel? p2p,
  }) : _sender = sender ?? TapFlowHttpSender(),
       _receiver = receiver ?? TapFlowHttpReceiver(),
       _nfc = nfc ?? TapFlowNfcChannel(),
       _p2p = p2p ?? TapFlowP2pChannel();

  final TapFlowHttpSender _sender;
  final TapFlowHttpReceiver _receiver;
  final TapFlowNfcChannel _nfc;
  final TapFlowP2pChannel _p2p;

  final ValueNotifier<TapFlowStage> stage = ValueNotifier(TapFlowStage.standby);
  final ValueNotifier<TapFlowIncomingRequest?> incomingRequest =
      ValueNotifier<TapFlowIncomingRequest?>(null);
  final ValueNotifier<TapFlowTransferProgress?> progress =
      ValueNotifier<TapFlowTransferProgress?>(null);
  final ValueNotifier<TapFlowReceivedFile?> receivedFile =
      ValueNotifier<TapFlowReceivedFile?>(null);
  final ValueNotifier<TapFlowSupabaseConfig?> receivedSupabaseConfig =
      ValueNotifier<TapFlowSupabaseConfig?>(null);
  final ValueNotifier<String?> errorText = ValueNotifier<String?>(null);
  final ValueNotifier<String?> debugText = ValueNotifier<String?>(null);

  StreamSubscription? _nfcSub;
  StreamSubscription? _p2pSub;
  TapFlowOffer? _pendingOffer;
  String? _groupOwnerIp;
  int _peersCount = 0;
  bool _groupFormed = false;

  void _ensureP2pListening() {
    if (_p2pSub != null) return;
    _p2pSub = _p2p.events().listen((e) {
      final type = e['type']?.toString();
      if (type == 'peers') {
        final c = e['count'];
        if (c is num) _peersCount = c.toInt();
      } else if (type == 'connection') {
        final groupFormed = e['groupFormed'] == true;
        _groupFormed = groupFormed;
        final go = e['groupOwnerAddress']?.toString();
        if (groupFormed && go != null && go.isNotEmpty) {
          _groupOwnerIp = go;
        }
      }
    });
  }

  Future<void> _waitUntil(
    bool Function() cond, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final until = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(until)) {
      if (cond()) return;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  Future<void> enterRadar() async {
    errorText.value = null;
    debugText.value = null;
    receivedFile.value = null;
    receivedSupabaseConfig.value = null;
    progress.value = null;
    incomingRequest.value = null;

    stage.value = TapFlowStage.waitingForTap;

    await _ensurePermissions();

    await _nfc.setPreferredHceService(false);
    await _nfc.setHcePayload(null);
    await _nfc.startReader();

    _nfcSub?.cancel();
    _nfcSub = _nfc.events().listen((e) {
      final type = e['type']?.toString();
      if (type == 'offer') {
        final payload = e['payload']?.toString() ?? '';
        _onOfferPayload(payload);
      } else {
        debugText.value = e.toString();
      }
    });

    _p2pSub?.cancel();
    _p2pSub = null;
    _peersCount = 0;
    _groupFormed = false;
    _groupOwnerIp = null;
    _ensureP2pListening();
  }

  Future<void> leaveRadar() async {
    _nfcSub?.cancel();
    _nfcSub = null;
    await _nfc.stopReader();
    await _nfc.setPreferredHceService(false);
    await _nfc.setHcePayload(null);
    _p2pSub?.cancel();
    _p2pSub = null;
    incomingRequest.value = null;
    progress.value = null;
    debugText.value = null;
    stage.value = TapFlowStage.standby;
  }

  Future<void> _ensurePermissions() async {
    await Permission.nearbyWifiDevices.request();
    await Permission.locationWhenInUse.request();
    await Permission.storage.request();
  }

  void _onOfferPayload(String payload) {
    if (stage.value != TapFlowStage.waitingForTap) return;
    final supa = _parseSupabaseConfigText(payload);
    final offer = supa != null
        ? _supabaseOfferStub()
        : _parseOfferText(payload);
    if (offer == null) return;
    incomingRequest.value = TapFlowIncomingRequest(
      offer: offer,
      peerName: null,
      supabaseConfig: supa,
    );
    stage.value = TapFlowStage.incomingRequest;
  }

  TapFlowOffer _supabaseOfferStub() {
    return const TapFlowOffer(
      sessionId: 'supabase',
      host: '0.0.0.0',
      port: 0,
      fileName: 'Данные Supabase',
      size: 0,
    );
  }

  TapFlowSupabaseConfig? _parseSupabaseConfigText(String raw) {
    try {
      if (!raw.trim().startsWith('{')) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      if (map['protocol']?.toString() != 'tapflow') return null;
      final v = (map['v'] as num?)?.toInt() ?? 1;
      if (v != 1) return null;
      final type = map['type']?.toString() ?? '';
      if (type != 'supabase') return null;
      final supa =
          (map['supabase'] as Map?)?.cast<String, dynamic>() ?? const {};
      final url = (supa['url'] ?? '').toString().trim();
      final anonKey = (supa['anonKey'] ?? '').toString().trim();
      if (url.isEmpty || anonKey.isEmpty) return null;
      return TapFlowSupabaseConfig(url: url, anonKey: anonKey);
    } catch (_) {
      return null;
    }
  }

  TapFlowOffer? _parseOfferText(String raw) {
    // v1 payload: tapflow://host:port/sessionId?name=...&size=...
    // also allow: host:port|sessionId|name|size
    try {
      if (raw.trim().startsWith('{')) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        if (map['protocol']?.toString() != 'tapflow') return null;
        final v = (map['v'] as num?)?.toInt() ?? 1;
        if (v != 1) return null;
        final host = map['ip']?.toString() ?? '';
        final port = (map['port'] as num?)?.toInt() ?? 0;
        final sid = map['sid']?.toString() ?? '';
        final p2pAddress = map['p2pAddress']?.toString();
        final file = (map['file'] as Map?)?.cast<String, dynamic>() ?? {};
        final name = file['name']?.toString() ?? 'file';
        final size = (file['size'] as num?)?.toInt() ?? 0;
        if (host.isEmpty || port <= 0 || sid.isEmpty) return null;
        return TapFlowOffer(
          sessionId: sid,
          host: host,
          port: port,
          fileName: name,
          size: size,
          p2pAddress: (p2pAddress != null && p2pAddress.isNotEmpty)
              ? p2pAddress
              : null,
        );
      }
      if (raw.startsWith('tapflow://')) {
        final uri = Uri.parse(raw);
        final host = uri.host;
        final port = uri.port == 0 ? 8080 : uri.port;
        final sessionId = uri.pathSegments.isNotEmpty
            ? uri.pathSegments.last
            : (uri.path.replaceAll('/', '').trim());
        final name = uri.queryParameters['name'] ?? 'file';
        final size = int.tryParse(uri.queryParameters['size'] ?? '') ?? 0;
        if (host.isEmpty || sessionId.isEmpty) return null;
        return TapFlowOffer(
          sessionId: sessionId,
          host: host,
          port: port,
          fileName: name,
          size: size,
        );
      }

      final parts = raw.split('|');
      if (parts.length >= 4) {
        final hp = parts[0].split(':');
        final host = hp[0];
        final port = hp.length > 1 ? int.tryParse(hp[1]) ?? 8080 : 8080;
        final sessionId = parts[1];
        final name = parts[2];
        final size = int.tryParse(parts[3]) ?? 0;
        if (host.isEmpty || sessionId.isEmpty) return null;
        return TapFlowOffer(
          sessionId: sessionId,
          host: host,
          port: port,
          fileName: name,
          size: size,
        );
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<void> startSendingFile(File file) async {
    errorText.value = null;
    receivedFile.value = null;
    progress.value = null;
    incomingRequest.value = null;

    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    stage.value = TapFlowStage.connecting;

    // Sender must behave as HCE card (not reader) for reliable NFC exchange.
    await _nfc.stopReader();
    await _nfc.setHcePayload(null);
    await _nfc.setPreferredHceService(false);

    _p2pSub?.cancel();
    _p2pSub = null;
    _peersCount = 0;
    _groupFormed = false;
    _ensureP2pListening();

    // Ensure we're the group owner so receiver can connect to us reliably.
    await _p2p.removeGroup();
    _groupOwnerIp = null;
    _groupFormed = false;
    await _p2p.createGroup();
    await _p2p.requestConnectionInfo();
    await _waitUntil(
      () => _groupFormed && (_groupOwnerIp?.isNotEmpty ?? false),
      timeout: const Duration(seconds: 12),
    );

    final deviceInfo = await _p2p.getThisDeviceInfo();
    final p2pAddress = deviceInfo['address']?.toString();

    final ip = _groupOwnerIp ?? '192.168.49.1';

    final offer = await _sender.start(
      sessionId: sessionId,
      file: file,
      bind: InternetAddress.anyIPv4,
      port: 0,
    );

    _pendingOffer = TapFlowOffer(
      sessionId: offer.sessionId,
      host: ip,
      port: offer.port,
      fileName: offer.fileName,
      size: offer.size,
      p2pAddress: (p2pAddress != null && p2pAddress.isNotEmpty)
          ? p2pAddress
          : null,
    );

    await _nfc.setHcePayload(_pendingOfferJsonPayload(_pendingOffer!));
    await _nfc.setPreferredHceService(true);
    stage.value = TapFlowStage.waitingForTap;
  }

  Future<void> startSendingSupabaseConfig({
    required String url,
    required String anonKey,
  }) async {
    errorText.value = null;
    debugText.value = null;
    receivedFile.value = null;
    receivedSupabaseConfig.value = null;
    progress.value = null;
    incomingRequest.value = null;

    stage.value = TapFlowStage.connecting;

    await _ensurePermissions();

    // Sender must behave as HCE card (not reader) for reliable NFC exchange.
    await _nfc.stopReader();
    await _nfc.setHcePayload(null);
    await _nfc.setPreferredHceService(false);

    _p2pSub?.cancel();
    _p2pSub = null;
    _peersCount = 0;
    _groupFormed = false;
    _groupOwnerIp = null;
    _ensureP2pListening();

    await _nfc.setHcePayload(
      jsonEncode({
        'protocol': 'tapflow',
        'v': 1,
        'type': 'supabase',
        'supabase': {'url': url.trim(), 'anonKey': anonKey.trim()},
      }),
    );
    await _nfc.setPreferredHceService(true);
    stage.value = TapFlowStage.waitingForTap;
  }

  TapFlowOffer? get pendingOffer => _pendingOffer;

  String? get pendingOfferPayload {
    final offer = _pendingOffer;
    if (offer == null) return null;
    return _pendingOfferJsonPayload(offer);
  }

  String _pendingOfferJsonPayload(TapFlowOffer offer) {
    final json = <String, Object?>{
      'protocol': 'tapflow',
      'v': 1,
      'ip': offer.host,
      'port': offer.port,
      'sid': offer.sessionId,
      'p2pAddress': offer.p2pAddress,
      'file': {'name': offer.fileName, 'size': offer.size},
    };
    return jsonEncode(json);
  }

  Future<void> acceptIncoming() async {
    final req = incomingRequest.value;
    if (req == null) return;

    final supa = req.supabaseConfig;
    if (supa != null) {
      receivedSupabaseConfig.value = supa;
      stage.value = TapFlowStage.completed;
      return;
    }

    stage.value = TapFlowStage.connecting;
    progress.value = const TapFlowTransferProgress(received: 0, total: 1);

    try {
      debugText.value = 'Подготовка…';
      // Receiver: after offer is received, stop reader to avoid interference.
      await _nfc.stopReader();
      await _nfc.setPreferredHceService(false);
      await _nfc.setHcePayload(null);

      _ensureP2pListening();
      _groupOwnerIp = null;
      _peersCount = 0;
      _groupFormed = false;
      debugText.value = 'Wi‑Fi Direct: сбрасываю группу…';
      await _p2p.removeGroup();
      debugText.value = 'Wi‑Fi Direct: ищу устройства…';
      await _p2p.discoverPeers();
      await _waitUntil(
        () => _peersCount > 0,
        timeout: const Duration(seconds: 10),
      );
      debugText.value = 'Wi‑Fi Direct: подключаюсь…';
      final addr = req.offer.p2pAddress;
      if (addr == null || addr.isEmpty) {
        final ok = await _p2p.connectToFirstPeer();
        if (!ok) {
          throw Exception(
            'Не удалось подключиться по Wi‑Fi Direct (нет p2pAddress и не найдено peers). Проверь: включены Wi‑Fi и Геолокация (и разрешения), затем попробуй снова.',
          );
        }
      } else {
        await _p2p.connectToPeer(addr);
      }
      await _p2p.stopDiscover();

      // On some devices requestConnectionInfo may return groupFormed=false for a while
      // after connect() succeeds. We poll a few times before failing.
      debugText.value = 'Wi‑Fi Direct: получаю connectionInfo…';
      final startedAt = DateTime.now();
      var polls = 0;
      while (true) {
        polls++;
        await _p2p.requestConnectionInfo();
        try {
          await _waitUntil(
            () => _groupFormed && (_groupOwnerIp?.isNotEmpty ?? false),
            timeout: const Duration(seconds: 2),
          );
          break;
        } catch (_) {
          final elapsed = DateTime.now().difference(startedAt);
          if (elapsed >= const Duration(seconds: 18)) {
            // One reconnect attempt, helps when connection changed broadcast is missed.
            debugText.value =
                'Wi‑Fi Direct: не получилось, пробую переподключение…';
            _groupOwnerIp = null;
            _groupFormed = false;
            await _p2p.removeGroup();
            await _p2p.discoverPeers();
            await _waitUntil(
              () => _peersCount > 0,
              timeout: const Duration(seconds: 8),
            );
            if (addr == null || addr.isEmpty) {
              final ok = await _p2p.connectToFirstPeer();
              if (!ok) break;
            } else {
              await _p2p.connectToPeer(addr);
            }
            await _p2p.stopDiscover();
            // reset timer for second phase
            polls = 0;
            // give device time to settle
            await Future<void>.delayed(const Duration(milliseconds: 500));
          } else {
            if (polls % 2 == 0) {
              debugText.value =
                  'Wi‑Fi Direct: жду connectionInfo… (${elapsed.inSeconds}s)';
            }
            await Future<void>.delayed(const Duration(milliseconds: 450));
          }
        }
      }
      final hadConnInfo = _groupFormed && (_groupOwnerIp?.isNotEmpty ?? false);
      if (!hadConnInfo) {
        // Some devices may keep reporting groupFormed=false even though routing works.
        // We'll attempt to download using the IP from the offer as a fallback.
        debugText.value =
            'Wi‑Fi Direct: connectionInfo не получен, пробую скачать по IP из offer…';
      }

      final goIp = (_groupOwnerIp?.isNotEmpty ?? false)
          ? _groupOwnerIp!
          : req.offer.host;
      final patchedOffer = TapFlowOffer(
        sessionId: req.offer.sessionId,
        host: goIp,
        port: req.offer.port,
        fileName: req.offer.fileName,
        size: req.offer.size,
        p2pAddress: req.offer.p2pAddress,
      );

      stage.value = TapFlowStage.transferring;
      debugText.value = 'Скачиваю файл…';
      TapFlowReceivedFile out;
      var attempt = 0;
      Object? lastErr;
      while (true) {
        attempt++;
        try {
          out = await _receiver.download(
            offer: patchedOffer,
            onProgress: (p) {
              progress.value = p;
            },
          );
          break;
        } catch (e) {
          lastErr = e;
          if (attempt >= 5) {
            if (!hadConnInfo) {
              throw Exception(
                'Не удалось получить connectionInfo Wi‑Fi Direct (groupFormed=$_groupFormed, groupOwnerIp=$_groupOwnerIp) и не удалось скачать файл по offer.ip=${req.offer.host}. Ошибка: $lastErr',
              );
            }
            rethrow;
          }
          await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
        }
      }
      receivedFile.value = out;
      stage.value = TapFlowStage.completed;
    } catch (e) {
      stage.value = TapFlowStage.error;
      errorText.value = e.toString();
    }
  }

  void declineIncoming() {
    incomingRequest.value = null;
    stage.value = TapFlowStage.waitingForTap;
  }

  Future<void> stopSending() async {
    _pendingOffer = null;
    _groupOwnerIp = null;
    await _nfc.setPreferredHceService(false);
    await _p2p.removeGroup();
    await _sender.stop();
    stage.value = TapFlowStage.standby;
  }

  void dispose() {
    _nfcSub?.cancel();
    _nfc.stopReader();
    _nfc.setPreferredHceService(false);
    _p2pSub?.cancel();
    stage.dispose();
    incomingRequest.dispose();
    progress.dispose();
    receivedFile.dispose();
    receivedSupabaseConfig.dispose();
    errorText.dispose();
    debugText.dispose();
  }
}
