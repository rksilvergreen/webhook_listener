# webhook_listener

A small Dart library for receiving JSON-POST webhook payloads. It exposes a
single `WebhookListener` class whose `run()` method starts a
[`shelf`](https://pub.dev/packages/shelf)-based HTTP server and dispatches
each accepted request to a user-supplied handler.

## Inputs

`WebhookListener` takes:

- `port` (required) – TCP port to bind to.
- `handler` (required) – `FutureOr<void> Function(Map<String, dynamic> body)`
  invoked with the parsed JSON payload.
- `route` (optional) – path to listen on (e.g. `/webhook`). When omitted, the
  listener accepts `POST` requests on any path.
- `appName` (optional) – name of the consuming app, used as the bracketed
  prefix in stdout/stderr log lines (e.g. `[MyApp] ...`). Defaults to
  `WebhookListener`.

The library does **not** perform any authentication. If you need to verify
the source of a request, do it inside your `handler` (for example by
verifying a signature header against a shared secret, or by checking an
identifier in the body), or run the listener behind a reverse proxy that
handles auth.

## Usage

```dart
import 'package:webhook_listener/webhook_listener.dart';

Future<void> main() async {
  final listener = WebhookListener(
    port: 8080,
    route: '/webhook', // optional; omit to accept any path
    handler: (body) async {
      print('Got webhook payload with keys: ${body.keys.toList()}');
    },
  );

  await listener.run();
}
```

## Behavior

- `POST` requests with a valid JSON object body are passed to `handler` and
  the server responds `200 ok`.
- Invalid JSON or a non-object body returns `400`.
- An exception thrown from `handler` returns `500`.
- When `route` is `null`, non-`POST` requests return `405`. When `route` is
  set, only that path matches; everything else returns `404`.
