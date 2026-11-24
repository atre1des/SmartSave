import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'models.dart';

/// Result of an AI request
class AIRequestResult {
  const AIRequestResult({
    required this.success,
    this.content,
    this.error,
    this.model,
    this.usage,
  });

  final bool success;
  final String? content;
  final String? error;
  final String? model;
  final Map<String, dynamic>? usage;
}

/// Backend API client for AI chat completions (proxies to OpenRouter via Express)
class OpenRouterProvider {
  OpenRouterProvider({
    Dio? dio,
    String? baseUrl,
    String? model,
    User? Function()? currentUser,
  }) : _dio = dio ?? _createDefaultDio(),
       _baseUrl = baseUrl ?? _getDefaultBackendUrl(),
       _model = model,
       _currentUser = currentUser ?? _firebaseUser {
    _sessionUid = _currentUser()?.uid;
    _configureDio();
  }

  static Dio _createDefaultDio() => Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 120),
      sendTimeout: const Duration(seconds: 30),
    ),
  );

  /// Get the default backend URL based on platform
  static String _getDefaultBackendUrl() {
    const configured = String.fromEnvironment('SMARTSAVE_BACKEND_URL');
    if (configured.isNotEmpty) return configured;

    // For Android emulator, use 10.0.2.2 to reach host machine
    // For iOS simulator, use localhost
    // For web/desktop, use localhost
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3001';
    }
    return 'http://localhost:3001';
  }

  final Dio _dio;
  final String _baseUrl;
  final String? _model;
  final User? Function() _currentUser;
  String? _sessionUid;

  static User? _firebaseUser() =>
      Firebase.apps.isEmpty ? null : FirebaseAuth.instance.currentUser;

  void _configureDio() {
    _dio.options.baseUrl = _baseUrl;

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final destination = options.uri;
          final localDevelopment =
              kDebugMode &&
              destination.scheme == 'http' &&
              const {
                'localhost',
                '127.0.0.1',
                '10.0.2.2',
              }.contains(destination.host);
          if (destination.host.isEmpty ||
              destination.userInfo.isNotEmpty ||
              (destination.scheme != 'https' && !localDevelopment)) {
            handler.reject(
              DioException(
                requestOptions: options,
                message: 'Configure a trusted HTTPS address for the AI proxy.',
              ),
            );
            return;
          }

          options.followRedirects = false;
          if (options.path != '/api/chat/completions') {
            handler.next(options);
            return;
          }
          try {
            final user = _currentUser();
            if (user == null ||
                (_sessionUid != null && user.uid != _sessionUid)) {
              throw StateError('The account session changed.');
            }
            _sessionUid = user.uid;
            // Firebase returns a fresh token when the cached token has expired.
            final token = await user.getIdToken();
            if (token == null ||
                token.isEmpty ||
                _currentUser()?.uid != user.uid) {
              throw StateError('The account session changed.');
            }
            options.headers['Authorization'] = 'Bearer $token';
            handler.next(options);
          } catch (_) {
            handler.reject(
              DioException(
                requestOptions: options,
                message:
                    'Unable to authenticate the AI request. Reopen the assistant or sign in again.',
              ),
            );
          }
        },
      ),
    );
  }

  /// Whether the backend is configured (always true since backend handles API key)
  bool get isConfigured =>
      true; // Backend handles API key, so we just try to connect

  /// Get the backend URL for debugging
  String get backendUrl => _baseUrl;

  Future<bool>? _healthInFlight;

  /// Probes only liveness. Concurrent callers share the same bounded probe.
  Future<bool> checkBackendHealth() =>
      _healthInFlight ??= _probeBackend().whenComplete(() {
        _healthInFlight = null;
      });

  Future<bool> _probeBackend() async {
    final hosted = Uri.tryParse(_baseUrl)?.scheme == 'https';
    final attempts = hosted ? 2 : 1;
    final timeout = Duration(seconds: hosted ? 38 : 5);
    for (var attempt = 0; attempt < attempts; attempt++) {
      final cancel = CancelToken();
      final deadline = Timer(timeout, cancel.cancel);
      try {
        final response = await _dio.get<Object?>(
          '/health',
          cancelToken: cancel,
          options: Options(
            connectTimeout: timeout,
            receiveTimeout: timeout,
            sendTimeout: Duration.zero,
            validateStatus: (status) => status != null,
          ),
        );
        final body = response.data;
        if (response.statusCode == 200 &&
            body is Map &&
            body['status'] == 'ok') {
          return true;
        }
        final wakingPage =
            response.statusCode == 200 &&
            body is String &&
            (response.headers.value('content-type') ?? '').contains(
              'text/html',
            );
        if (!wakingPage &&
            !const {502, 503, 504}.contains(response.statusCode)) {
          return false;
        }
      } on DioException catch (error) {
        if (!const {
          DioExceptionType.connectionTimeout,
          DioExceptionType.sendTimeout,
          DioExceptionType.receiveTimeout,
          DioExceptionType.connectionError,
          DioExceptionType.cancel,
        }.contains(error.type)) {
          return false;
        }
      } finally {
        deadline.cancel();
      }
      if (attempt + 1 < attempts) {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
    return false;
  }

  /// Send a chat completion request (non-streaming)
  Future<AIRequestResult> sendMessage({
    required List<AIMessage> messages,
    double temperature = 0.7,
    int maxTokens = 2000,
  }) async {
    try {
      final response = await _dio.post(
        '/api/chat/completions',
        data: {
          'model': ?_model,
          'messages': messages
              .map((m) => {'role': m.role, 'content': m.content})
              .toList(),
          'temperature': temperature,
          'max_tokens': maxTokens,
          'stream': false,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final choices = data['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          final message = choices.first['message'] as Map<String, dynamic>?;
          final content = message?['content'] as String?;
          final usage = data['usage'] as Map<String, dynamic>?;
          final model = data['model'] as String?;

          return AIRequestResult(
            success: true,
            content: content,
            model: model,
            usage: usage,
          );
        }
      }

      // Handle error responses from backend
      if (response.data is Map && response.data['error'] != null) {
        return AIRequestResult(
          success: false,
          error: response.data['error']?.toString() ?? 'Backend error',
        );
      }

      return AIRequestResult(
        success: false,
        error: 'Unexpected response: ${response.statusCode}',
      );
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return AIRequestResult(
        success: false,
        error: 'Request failed: ${e.toString()}',
      );
    }
  }

  /// Send a streaming chat completion request.
  ///
  /// Error handling:
  /// - If the backend returns a non-2xx HTTP status, yields a single error chunk
  ///   with `isDone: true` and the error message. No further chunks follow.
  /// - If the stream is interrupted mid-flight, yields a single error chunk.
  /// - If the stream ends normally, yields a final `isDone: true` chunk with `error: null`.
  ///
  /// The caller MUST check `chunk.error` before treating `isDone` as success.
  Stream<AIStreamChunk> sendMessageStream({
    required List<AIMessage> messages,
    double temperature = 0.7,
    int maxTokens = 2000,
  }) async* {
    try {
      final response = await _dio.post(
        '/api/chat/completions',
        data: {
          'model': ?_model,
          'messages': messages
              .map((m) => {'role': m.role, 'content': m.content})
              .toList(),
          'temperature': temperature,
          'max_tokens': maxTokens,
          'stream': true,
        },
        options: Options(
          responseType: ResponseType.stream,
          validateStatus: (status) => status != null,
          receiveTimeout: const Duration(seconds: 120),
        ),
      );

      if (response.statusCode != 200) {
        final payload = await _readErrorPayload(response.data.stream);
        final status = response.statusCode;
        yield AIStreamChunk(
          content: '',
          isDone: true,
          error: _httpError(status, payload),
          isRateLimitError: status == 429,
          isDailyQuotaExhausted: payload['isDailyQuota'] == true,
          retryAfterSeconds: int.tryParse(
            response.headers.value('retry-after') ?? '',
          ),
        );
        return;
      }

      if (!(response.headers.value('content-type') ?? '').contains(
        'text/event-stream',
      )) {
        yield const AIStreamChunk(
          content: '',
          isDone: true,
          error:
              'The AI proxy returned an unexpected response instead of a stream.',
        );
        return;
      }

      await for (final chunk in _parseStream(response.data.stream)) {
        yield chunk;
      }
    } on DioException catch (e) {
      yield AIStreamChunk(
        content: '',
        isDone: true,
        error: _handleDioError(e).error,
      );
    } catch (_) {
      yield const AIStreamChunk(
        content: '',
        isDone: true,
        error: 'The AI response was interrupted. Please try again.',
      );
    }
  }

  Stream<AIStreamChunk> _parseStream(Stream<List<int>> bytes) async* {
    var hasContent = false;
    var sawDone = false;
    await for (final line
        in utf8.decoder.bind(bytes).transform(const LineSplitter())) {
      if (sawDone || !line.startsWith('data:')) continue;
      final data = line.substring(5).trim();
      if (data == '[DONE]') {
        sawDone = true;
        continue;
      }

      final event = _decodeObject(data);
      if (event['error'] != null) {
        yield const AIStreamChunk(
          content: '',
          isDone: true,
          error: 'The AI provider interrupted the response. Please try again.',
        );
        return;
      }
      final choices = event['choices'];
      if (choices is! List || choices.isEmpty || choices.first is! Map) {
        continue;
      }
      final delta = (choices.first as Map)['delta'];
      final content = delta is Map ? delta['content'] : null;
      if (content is String && content.isNotEmpty) {
        hasContent = true;
        yield AIStreamChunk(content: content, isDone: false);
      }
    }
    yield AIStreamChunk(
      content: '',
      isDone: true,
      error: !sawDone
          ? 'The AI response ended before completion. Please try again.'
          : hasContent
          ? null
          : 'The AI service returned an empty response.',
    );
  }

  Future<Map<String, dynamic>> _readErrorPayload(
    Stream<List<int>> bytes,
  ) async {
    final buffer = StringBuffer();
    await for (final text in const Utf8Decoder(
      allowMalformed: true,
    ).bind(bytes)) {
      if (buffer.length + text.length > 16384) return const {};
      buffer.write(text);
    }
    return _decodeObject(buffer.toString());
  }

  static Map<String, dynamic> _decodeObject(String text) {
    try {
      final data = jsonDecode(text);
      return data is Map<String, dynamic> ? data : const {};
    } on FormatException {
      return const {};
    }
  }

  static String _httpError(int? status, Object? payload) {
    final code = payload is Map ? payload['code'] : null;
    if (code == 'OPENROUTER_KEY_MISSING') {
      return 'The AI proxy has no OpenRouter key configured.';
    }
    if (code == 'AUTH_UNAVAILABLE') {
      return 'The AI proxy cannot verify Firebase sign-ins.';
    }
    return switch (status ?? 0) {
      401 when code == 'OPENROUTER_HTTP_401' =>
        'OpenRouter rejected the proxy credentials.',
      401 =>
        'The AI proxy could not verify your sign-in. Please sign in again.',
      403 =>
        'The AI provider refused access. Check the proxy key and model permissions.',
      402 =>
        'OpenRouter refused the request due to insufficient credits or quota.',
      429 when payload is Map && payload['isDailyQuota'] == true =>
        'The OpenRouter daily quota is exhausted.',
      429 => 'Rate limit exceeded. Please wait and try again.',
      502 =>
        'The AI proxy received an invalid response from its provider. Please try again.',
      503 => 'The AI proxy is unavailable or restarting. Please try again.',
      504 => 'The AI provider timed out. Please try again.',
      >= 500 => 'The AI service is temporarily unavailable. Please try again.',
      _ => 'The AI request failed (HTTP $status). Please try again.',
    };
  }

  AIRequestResult _handleDioError(DioException e) {
    String errorMessage;
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        errorMessage =
            'Request timed out. Please check if the backend is running on ${_baseUrl.replaceAll('/api', '')}.';
        break;
      case DioExceptionType.badResponse:
        errorMessage = _httpError(e.response?.statusCode, e.response?.data);
        break;
      case DioExceptionType.connectionError:
        errorMessage =
            'Cannot connect to backend at $_baseUrl. Make sure the backend server is running (npm start in backend folder).';
        break;
      case DioExceptionType.cancel:
        errorMessage = 'Request was cancelled.';
        break;
      default:
        errorMessage = 'Request failed: ${e.message}';
    }
    return AIRequestResult(success: false, error: errorMessage);
  }

  /// Close the dio client
  void dispose() {
    _dio.close();
  }
}

/// Represents a chunk of streamed AI response
class AIStreamChunk {
  const AIStreamChunk({
    required this.content,
    required this.isDone,
    this.error,
    this.isRateLimitError = false,
    this.isDailyQuotaExhausted = false,
    this.retryAfterSeconds,
  });

  final String content;
  final bool isDone;
  final String? error;

  /// Whether this error is an HTTP 429 rate limit error
  final bool isRateLimitError;

  /// Whether the error is due to daily free-tier quota exhaustion (permanent until reset)
  final bool isDailyQuotaExhausted;

  /// Seconds to wait before retrying (from Retry-After header or upstream metadata)
  final int? retryAfterSeconds;
}
