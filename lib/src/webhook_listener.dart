import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';

/// Signature of the user-supplied handler invoked for each well-formed
/// JSON-POST webhook received by [WebhookListener].
///
/// [body] is the parsed JSON payload.
typedef WebhookHandler = FutureOr<void> Function(
  Map<String, dynamic> body,
);

/// HTTP listener for JSON-POST webhook payloads.
///
/// Instantiate with a [port], an optional [route], and a [handler], then call
/// [run] to start a shelf-based HTTP server. The library does not perform any
/// authentication; consumers can validate the request inside [handler] (for
/// example, by inspecting fields in the body or verifying a signature header
/// against a shared secret).
class WebhookListener {
  /// TCP port to bind the HTTP server to.
  final int port;

  /// Optional path to listen on (e.g. `/webhook`). When `null`, the listener
  /// accepts POST requests on any path.
  final String? route;

  /// Callback invoked with the parsed JSON body for every accepted request.
  final WebhookHandler handler;

  /// Optional name of the consuming app, used as the bracketed prefix in
  /// stdout/stderr log lines (e.g. `[MyApp] ...`). Defaults to
  /// `WebhookListener` when not provided.
  final String appName;

  WebhookListener({
    required this.port,
    this.route,
    required this.handler,
    this.appName = 'WebhookListener',
  });

  /// Starts the HTTP server and returns the running [HttpServer] instance.
  Future<HttpServer> run() async {
    final Handler pipeline;

    if (route != null) {
      final router = Router();
      router.post(route!, _handle);
      pipeline = router.call;
    } else {
      pipeline = (Request req) {
        if (req.method != 'POST') {
          return Response(HttpStatus.methodNotAllowed, body: 'Method Not Allowed');
        }
        return _handle(req);
      };
    }

    final server = await serve(
      logRequests().addHandler(pipeline),
      InternetAddress.anyIPv4,
      port,
    );

    stdout.writeln(
      '[$appName] Listening on http://${server.address.host}:${server.port}'
      '${route != null ? ' (route: $route)' : ' (any path)'}',
    );

    return server;
  }

  Future<Response> _handle(Request req) async {
    final raw = await req.readAsString();

    final dynamic decoded;
    try {
      decoded = json.decode(raw);
    } catch (e) {
      stderr.writeln('[$appName] Error parsing JSON payload: $e');
      return Response.badRequest(body: 'Invalid JSON payload');
    }

    if (decoded is! Map<String, dynamic>) {
      stderr.writeln('[$appName] Invalid payload structure - expected JSON object');
      return Response.badRequest(body: 'Invalid payload structure');
    }

    try {
      await handler(decoded);
    } catch (e, st) {
      stderr.writeln('[$appName] Handler threw: $e\n$st');
      return Response.internalServerError(body: 'Handler error');
    }

    return Response.ok('ok');
  }
}
