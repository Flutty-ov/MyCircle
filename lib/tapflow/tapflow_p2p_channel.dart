import 'dart:async';

import 'package:flutter/services.dart';

class TapFlowP2pChannel {
  static const MethodChannel _m = MethodChannel('tapflow/p2p');
  static const EventChannel _e = EventChannel('tapflow/p2p_events');

  Stream<Map<dynamic, dynamic>>? _stream;

  Stream<Map<dynamic, dynamic>> events() {
    _stream ??= _e.receiveBroadcastStream().map((e) => e as Map);
    return _stream!;
  }

  Future<bool> discoverPeers() async {
    final ok = await _m.invokeMethod<bool>('discoverPeers');
    return ok ?? false;
  }

  Future<bool> stopDiscover() async {
    final ok = await _m.invokeMethod<bool>('stopDiscover');
    return ok ?? false;
  }

  Future<bool> createGroup() async {
    final ok = await _m.invokeMethod<bool>('createGroup');
    return ok ?? false;
  }

  Future<bool> removeGroup() async {
    final ok = await _m.invokeMethod<bool>('removeGroup');
    return ok ?? false;
  }

  Future<bool> connectToFirstPeer() async {
    final ok = await _m.invokeMethod<bool>('connectToFirstPeer');
    return ok ?? false;
  }

  Future<bool> connectToPeer(String address) async {
    final ok = await _m.invokeMethod<bool>('connectToPeer', {
      'address': address,
    });
    return ok ?? false;
  }

  Future<void> requestConnectionInfo() {
    return _m.invokeMethod('requestConnectionInfo');
  }

  Future<Map<dynamic, dynamic>> getThisDeviceInfo() async {
    final res = await _m.invokeMethod<dynamic>('getThisDeviceInfo');
    return (res as Map?) ?? <dynamic, dynamic>{};
  }
}
