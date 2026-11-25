import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:web/web.dart' as web;

HttpClientAdapter browserStreamAdapter(HttpClientAdapter fallback) =>
    _BrowserStreamAdapter(fallback);

class _BrowserStreamAdapter implements HttpClientAdapter {
  _BrowserStreamAdapter(this._fallback);

  final HttpClientAdapter _fallback;
  final _active = <web.AbortController>{};
  bool _closed = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (_closed) throw StateError('The browser transport has been closed.');
    if (options.responseType != ResponseType.stream &&
        options.uri.path != '/api/chat/completions') {
      return _fallback.fetch(options, requestStream, cancelFuture);
    }

    final abort = web.AbortController();
    _active.add(abort);
    void release() {
      if (_active.remove(abort)) abort.abort();
    }

    unawaited(cancelFuture?.then((_) => release()));
    final headers = web.Headers();
    for (final entry in options.headers.entries) {
      if (entry.key.toLowerCase() == Headers.contentLengthHeader) continue;
      final values = entry.value is Iterable
          ? entry.value as Iterable
          : [entry.value];
      for (final value in values) {
        if (value != null) headers.append(entry.key, value.toString());
      }
    }

    try {
      final bytes = BytesBuilder(copy: false);
      if (requestStream != null) {
        await for (final bytesChunk in requestStream) {
          bytes.add(bytesChunk);
        }
      }
      final responseFuture = web.window
          .fetch(
            options.uri.toString().toJS,
            web.RequestInit(
              method: options.method,
              headers: headers,
              body: requestStream == null ? null : bytes.takeBytes().toJS,
              mode: 'cors',
              redirect: 'error',
              credentials: 'omit',
              cache: 'no-store',
              signal: abort.signal,
            ),
          )
          .toDart;
      final deadline = options.connectTimeout;
      final response = deadline == null || deadline <= Duration.zero
          ? await responseFuture
          : await responseFuture.timeout(deadline);
      final responseHeaders = <String, List<String>>{};
      for (final name in [Headers.contentTypeHeader, 'retry-after']) {
        final value = response.headers.get(name);
        if (value != null) responseHeaders[name] = [value];
      }
      final stream = response.body;
      if (stream == null) release();
      return ResponseBody(
        stream == null ? const Stream.empty() : _read(stream, options, release),
        response.status,
        headers: responseHeaders,
        onClose: release,
      );
    } on TimeoutException {
      release();
      throw DioException.connectionTimeout(
        requestOptions: options,
        timeout: options.connectTimeout ?? Duration.zero,
      );
    } catch (_) {
      final cancelled = abort.signal.aborted;
      release();
      if (cancelled) {
        throw DioException.requestCancelled(
          requestOptions: options,
          reason: null,
        );
      }
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'Browser fetch failed.',
      );
    }
  }

  Stream<Uint8List> _read(
    web.ReadableStream stream,
    RequestOptions options,
    void Function() release,
  ) async* {
    final reader = stream.getReader() as web.ReadableStreamDefaultReader;
    try {
      while (true) {
        final deadline = options.receiveTimeout;
        final pending = reader.read().toDart;
        final result = deadline == null || deadline <= Duration.zero
            ? await pending
            : await pending.timeout(deadline);
        if (result.done) break;
        yield (result.value as JSUint8Array).toDart;
      }
    } on TimeoutException {
      throw DioException.receiveTimeout(
        requestOptions: options,
        timeout: options.receiveTimeout ?? Duration.zero,
      );
    } finally {
      release();
      reader.releaseLock();
    }
  }

  @override
  void close({bool force = false}) {
    _closed = true;
    for (final request in _active) {
      request.abort();
    }
    _active.clear();
    _fallback.close(force: force);
  }
}
