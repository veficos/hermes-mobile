import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'upload_http_exception.dart';
import 'upload_cancellation.dart';

Future<Map<String, dynamic>> uploadMultipartWithProgress({
  required String url,
  required Map<String, String> headers,
  required String path,
  required String filename,
  required Uint8List bytes,
  required void Function(int sent, int total) onProgress,
  UploadCancellation? cancellation,
}) {
  final completer = Completer<Map<String, dynamic>>();
  final xhr = web.XMLHttpRequest();
  xhr.open('POST', url, true);
  // External JS interop members cannot be passed as tear-offs in dart2js/
  // Wasm; wrap abort in a Dart closure instead.
  cancellation?.bind(() => xhr.abort());
  // Match the native client's two-minute upload budget so a stalled request
  // produces the explicit `ontimeout` diagnostic instead of hanging forever.
  xhr.timeout = 120000;
  for (final entry in headers.entries) {
    // The browser owns multipart Content-Type because it must append the
    // generated boundary. Setting it manually creates an unreadable body.
    if (entry.key.toLowerCase() == 'content-type') continue;
    xhr.setRequestHeader(entry.key, entry.value);
  }

  // Keep the original transport context in failures.  Browsers deliberately
  // hide the underlying CORS/TLS/mixed-content reason from JavaScript and
  // surface all of them as a generic XHR `error`; URL/status/statusText plus
  // the event source are therefore the useful diagnostics we can preserve.
  void fail(String event) {
    if (completer.isCompleted) return;
    final status = xhr.status;
    final statusText = xhr.statusText;
    completer.completeError(
      StateError(
        'upload network error ($event): url=$url, '
        'status=$status, statusText=${statusText.isEmpty ? '<empty>' : statusText}',
      ),
    );
  }

  xhr.upload.addEventListener(
    'progress',
    ((web.Event event) {
      final progress = event as web.ProgressEvent;
      onProgress(progress.loaded, progress.total);
    }).toJS,
  );
  xhr.onLoad.listen((_) {
    final status = xhr.status;
    final body = xhr.responseText;
    if (status >= 200 && status < 300) {
      completer.complete((jsonDecode(body) as Map).cast<String, dynamic>());
    } else {
      completer.completeError(UploadHttpException(status, body, url));
    }
  });
  xhr.onError.listen((_) {
    fail('onerror');
  });
  xhr.ontimeout = ((web.Event _) {
    fail('ontimeout');
  }).toJS;
  xhr.onabort = ((web.Event _) {
    fail('onabort');
  }).toJS;
  final form = web.FormData();
  form.append('path', path.toJS);
  form.append('overwrite', 'false'.toJS);
  final blob = web.Blob(<JSUint8Array>[bytes.toJS].toJS);
  form.append('file', blob, filename);
  xhr.send(form);
  return completer.future;
}
