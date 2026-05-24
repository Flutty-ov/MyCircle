import 'dart:async';

import 'package:flutter/services.dart';

class TapFlowNfcChannel {
  static const MethodChannel _m = MethodChannel('tapflow/nfc');
  static const EventChannel _e = EventChannel('tapflow/nfc_events');

  Stream<Map<dynamic, dynamic>>? _stream;

  Stream<Map<dynamic, dynamic>> events() {
    _stream ??= _e.receiveBroadcastStream().map((e) => e as Map);
    return _stream!;
  }

  Future<void> setHcePayload(String? payload) {
    return _m.invokeMethod('setHcePayload', {'payload': payload});
  }

  Future<bool> startReader() async {
    final ok = await _m.invokeMethod<bool>('startReader');
    return ok ?? false;
  }

  Future<void> stopReader() {
    return _m.invokeMethod('stopReader');
  }

  Future<bool> openPaymentSettings() async {
    final ok = await _m.invokeMethod<bool>('openPaymentSettings');
    return ok ?? false;
  }

  Future<bool> setPreferredHceService(bool enable) async {
    final ok = await _m.invokeMethod<bool>('setPreferredHceService', {
      'enable': enable,
    });
    return ok ?? false;
  }
}
