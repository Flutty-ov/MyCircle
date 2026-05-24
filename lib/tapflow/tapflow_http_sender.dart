import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'tapflow_models.dart';

class TapFlowHttpSender {
  TapFlowHttpSender();

  HttpServer? _server;
  String? _sessionId;
  File? _file;

  TapFlowOffer get offer {
    final server = _server;
    final sessionId = _sessionId;
    final file = _file;
    if (server == null || sessionId == null || file == null) {
      throw StateError('Sender not started');
    }

    final size = file.lengthSync();

    return TapFlowOffer(
      sessionId: sessionId,
      host: server.address.address,
      port: server.port,
      fileName: p.basename(file.path),
      size: size,
    );
  }

  bool get isRunning => _server != null;

  Future<TapFlowOffer> start({
    required String sessionId,
    required File file,
    required InternetAddress bind,
    int port = 0,
  }) async {
    if (_server != null) {
      await stop();
    }

    _sessionId = sessionId;
    _file = file;

    final router = Router();

    router.get('/tapflow/<sessionId>/meta', (Request req, String sessionId) {
      if (sessionId != _sessionId) return Response.notFound('Not found');
      final f = _file;
      if (f == null) return Response.notFound('Not found');
      final size = f.lengthSync();
      final meta = {'fileName': p.basename(f.path), 'size': size};
      return Response.ok(jsonEncode(meta), headers: _jsonHeaders);
    });

    router.get('/tapflow/<sessionId>/file', (Request req, String sessionId) {
      if (sessionId != _sessionId) return Response.notFound('Not found');
      final f = _file;
      if (f == null) return Response.notFound('Not found');
      final stream = f.openRead();
      return Response.ok(
        stream,
        headers: {
          ..._downloadHeaders,
          'Content-Length': f.lengthSync().toString(),
          'Content-Disposition': 'attachment; filename="${p.basename(f.path)}"',
        },
      );
    });

    router.get('/tapflow/<sessionId>/ping', (Request req, String sessionId) {
      if (sessionId != _sessionId) return Response.notFound('Not found');
      return Response.ok('ok');
    });

    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addHandler(router.call);

    final server = await shelf_io.serve(handler, bind, port);
    _server = server;

    return offer;
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    _sessionId = null;
    _file = null;
    if (server != null) {
      await server.close(force: true);
    }
  }

  static const _jsonHeaders = {
    'Content-Type': 'application/json; charset=utf-8',
  };
  static const _downloadHeaders = {
    'Content-Type': 'application/octet-stream',
    'Cache-Control': 'no-store',
  };
}
