import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'config.dart';
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
  })  : _dio = dio ?? _createDefaultDio(),
        _baseUrl = baseUrl ?? _getDefaultBackendUrl(),
        _model = model ?? AIConfig.defaultModel {
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
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:3001';
    }
    return 'http://localhost:3001';
  }

  final Dio _dio;
  final String _baseUrl;
  final String _model;
  final _sessionUser = Firebase.apps.isEmpty ? null : FirebaseAuth.instance.currentUser;

  void _configureDio() {
    _dio.options.baseUrl = _baseUrl;
    _dio.options.headers.addAll({
      'Content-Type': 'application/json',
      'HTTP-Referer': 'https://github.com/smartsave',
      'X-Title': 'SmartSave',
    });

    _dio.interceptors.add(
      InterceptorsWrapper(onRequest: (options, handler) async {
        if (options.path != '/api/chat/completions' || _sessionUser == null) {
          handler.next(options);
          return;
        }
        try {
          final destination = options.uri;
          final localDevelopment = kDebugMode && destination.scheme == 'http' &&
              const {'localhost', '127.0.0.1', '10.0.2.2'}.contains(destination.host);
          if (destination.scheme != 'https' && !localDevelopment) {
            throw StateError('A trusted backend transport is required.');
          }
          final user = _sessionUser;
          if (FirebaseAuth.instance.currentUser?.uid != user.uid) {
            throw StateError('The account session changed.');
          }
          final token = await user.getIdToken();
          if (token == null || FirebaseAuth.instance.currentUser?.uid != user.uid) {
            throw StateError('The account session changed.');
          }
          options.followRedirects = false;
          options.headers['Authorization'] = 'Bearer $token';
          handler.next(options);
        } catch (_) {
          handler.reject(DioException(
            requestOptions: options,
            message: 'Unable to authenticate the request.',
          ));
        }
      }),
    );
  }

  /// Whether the backend is configured (always true since backend handles API key)
  bool get isConfigured => true; // Backend handles API key, so we just try to connect

  /// Get the current model being used
  String get currentModel => _model;

  /// Get the backend URL for debugging
  String get backendUrl => _baseUrl;

  /// Check if the backend is reachable and healthy.
  /// Returns true if backend responds to /health endpoint.
  Future<bool> checkBackendHealth() async {
    try {
      final response = await _dio.get(
        '/health',
        options: Options(
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
        ),
      );
      final isHealthy = response.statusCode == 200 && response.data['status'] == 'ok';
      return isHealthy;
    } catch (e) {
      return false;
    }
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
          'model': _model,
          'messages': messages.map((m) => {'role': m.role, 'content': m.content}).toList(),
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
          'model': _model,
          'messages': messages.map((m) => {'role': m.role, 'content': m.content}).toList(),
          'temperature': temperature,
          'max_tokens': maxTokens,
          'stream': true,
        },
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: const Duration(seconds: 120),
        ),
      );

      if (response.statusCode != 200) {
        final errorText = await _readStreamAsString(response.data.stream);

        // Parse error response for structured metadata
        bool isRateLimitError = response.statusCode == 429;
        bool isDailyQuotaExhausted = false;
        int? retryAfterSeconds;
        String errorMessage = errorText;

        try {
          final errorJson = jsonDecode(errorText) as Map<String, dynamic>;
          // The backend wraps errors in a structured format.
          // Check for our backend's error format first, then OpenRouter's.
          if (errorJson['error'] != null) {
            final errorField = errorJson['error'];
            if (errorField is String) {
              errorMessage = errorField;
            } else if (errorField is Map) {
              final errorMap = errorField as Map<String, dynamic>;
              errorMessage =
                  errorMap['message']?.toString() ??
                  errorMap.toString();
            }
          }
          if (errorJson['isDailyQuota'] == true) {
            isDailyQuotaExhausted = true;
          }
          if (errorJson['isRateLimit'] == true) {
            isRateLimitError = true;
          }
          // Extract retry-after from headers or metadata
          final headers = response.headers;
          if (headers.map.containsKey('retry-after')) {
            retryAfterSeconds = int.tryParse(headers.map['retry-after']!.first);
          }
        } catch (e) {
          // Ignore parsing errors, use defaults
        }

        yield AIStreamChunk(
          content: '',
          isDone: true,
          error: 'HTTP ${response.statusCode}: $errorMessage',
          isRateLimitError: isRateLimitError,
          isDailyQuotaExhausted: isDailyQuotaExhausted,
          retryAfterSeconds: retryAfterSeconds,
        );
        return;
      }

      yield* _parseStream(response.data.stream);
    } on DioException catch (e) {
      final isRateLimitError = e.response?.statusCode == 429;
      final isDailyQuota = _detectDailyQuotaFromDioError(e);
      yield AIStreamChunk(
        content: '',
        isDone: true,
        error: _dioErrorToString(e),
        isRateLimitError: isRateLimitError,
        isDailyQuotaExhausted: isDailyQuota,
      );
    } catch (e) {
      yield AIStreamChunk(
        content: '',
        isDone: true,
        error: 'Stream failed: ${e.toString()}',
      );
    }
  }

  /// Parse the SSE stream from backend
  Stream<AIStreamChunk> _parseStream(Stream<List<int>> byteStream) async* {
    final decoder = Utf8Decoder();
    String buffer = '';
    int chunkCount = 0;
    String pendingContent = '';
    bool sawAnyData = false;
    String? streamError;

    await for (final chunk in byteStream) {
      buffer += decoder.convert(chunk);
      final lines = buffer.split('\n');
      buffer = lines.removeLast(); // Keep incomplete line in buffer

      for (final line in lines) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6).trim();
          if (data == '[DONE]') {
            sawAnyData = true;
            // Flush any pending content before completing
            if (pendingContent.isNotEmpty) {
              yield AIStreamChunk(content: pendingContent, isDone: false);
              pendingContent = '';
            }
            // If we saw an error event in the stream, propagate it
            if (streamError != null) {
              yield AIStreamChunk(
                content: '',
                isDone: true,
                error: streamError,
              );
            } else {
              yield AIStreamChunk(content: '', isDone: true);
            }
            return;
          }

          try {
            final json = jsonDecode(data) as Map<String, dynamic>;

            // Check for an error event injected by our backend
            if (json['error'] != null) {
              final err = json['error'];
              final msg = err is Map
                  ? (err['message']?.toString() ?? err.toString())
                  : err.toString();
              streamError = msg;
              continue;
            }

            final choices = json['choices'] as List<dynamic>?;
            if (choices != null && choices.isNotEmpty) {
              final delta = choices.first['delta'] as Map<String, dynamic>?;
              final content = delta?['content'] as String?;
              if (content != null && content.isNotEmpty) {
                sawAnyData = true;
                chunkCount++;
                pendingContent += content;

                // Flush when we have a meaningful amount of content or hit a paragraph boundary
                final shouldFlush = pendingContent.length >= 80 ||
                    pendingContent.endsWith('\n\n') ||
                    _endsWithSentenceBoundary(pendingContent);

                if (shouldFlush) {
                  if (chunkCount % 10 == 1) {
                  }
                  yield AIStreamChunk(content: pendingContent, isDone: false);
                  pendingContent = '';
                }
              }
            }
          } catch (e) {
            // Ignore parse errors for malformed chunks
          }
        }
      }
    }

    // Process any remaining buffer
    if (buffer.isNotEmpty && buffer.startsWith('data: ')) {
      final data = buffer.substring(6).trim();
      if (data != '[DONE]') {
        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          if (json['error'] != null) {
            final err = json['error'];
            streamError = err is Map
                ? (err['message']?.toString() ?? err.toString())
                : err.toString();
          } else {
            final choices = json['choices'] as List<dynamic>?;
            if (choices != null && choices.isNotEmpty) {
              final delta = choices.first['delta'] as Map<String, dynamic>?;
              final content = delta?['content'] as String?;
              if (content != null && content.isNotEmpty) {
                sawAnyData = true;
                chunkCount++;
                pendingContent += content;
              }
            }
          }
        } catch (e) {
        }
      }
    }

    // Flush any remaining pending content
    if (pendingContent.isNotEmpty) {
      yield AIStreamChunk(content: pendingContent, isDone: false);
    }

    // If we never saw any data and no error was reported, treat as empty response error
    if (!sawAnyData && streamError == null) {
      yield AIStreamChunk(
        content: '',
        isDone: true,
        error: 'The AI service returned an empty response. Please try again.',
      );
      return;
    }

    // If a stream error was detected, propagate it
    if (streamError != null) {
      yield AIStreamChunk(
        content: '',
        isDone: true,
        error: streamError,
      );
      return;
    }

    yield AIStreamChunk(content: '', isDone: true);
  }

  /// Checks if the text ends at a natural sentence/paragraph boundary
  bool _endsWithSentenceBoundary(String text) {
    if (text.isEmpty) return false;
    final trimmed = text.trimRight();
    // Check for paragraph ending (double newline)
    if (trimmed.endsWith('\n\n')) return true;
    // Check for sentence ending with proper punctuation followed by space
    // This regex checks for . ! ? followed by end of string or space + capital letter
    if (RegExp(r'[.!?]\s*$').hasMatch(trimmed)) return true;
    // Check for common paragraph-ending patterns
    if (RegExp(r'[.!?]\s+[A-Z]').hasMatch(trimmed)) return true;
    return false;
  }

  Future<String> _readStreamAsString(Stream<List<int>> stream) async {
    final chunks = <String>[];
    await for (final chunk in stream) {
      chunks.add(Utf8Decoder().convert(chunk));
    }
    return chunks.join();
  }

  /// Detect daily-quota exhaustion from a DioException (e.g. a non-200
  /// response that Dio surfaces as an exception).
  bool _detectDailyQuotaFromDioError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['isDailyQuota'] == true) return true;
    final headers = e.response?.headers;
    if (headers != null) {
      final remaining = headers.value('x-ratelimit-remaining');
      final limit = headers.value('x-ratelimit-limit');
      if (remaining != null && limit != null) {
        final rem = int.tryParse(remaining);
        final lim = int.tryParse(limit);
        if (rem != null && lim != null && rem == 0 && lim > 0) {
          // Treat as daily quota exhaustion — do not auto-retry.
          return true;
        }
      }
    }
    return false;
  }

  AIRequestResult _handleDioError(DioException e) {
    String errorMessage;
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        errorMessage = 'Request timed out. Please check if the backend is running on ${_baseUrl.replaceAll('/api', '')}.';
        break;
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final responseData = e.response?.data;
        if (statusCode == 401) {
          errorMessage = 'OpenRouter API authentication failed. Check OPENROUTER_API_KEY in backend/.env.';
        } else if (statusCode == 402) {
          errorMessage = 'OpenRouter payment required. Check your OpenRouter account credits.';
        } else if (statusCode == 403) {
          errorMessage = 'OpenRouter access forbidden. Check API key permissions.';
        } else if (statusCode == 429) {
          errorMessage = 'Rate limit exceeded. Please wait a moment and try again.';
        } else if (statusCode == 500 || statusCode == 502 || statusCode == 503) {
          errorMessage = 'OpenRouter service unavailable. Please try again later.';
        } else if (responseData is Map && responseData['error'] != null) {
          errorMessage = 'API error: ${responseData['error']}';
        } else {
          errorMessage = 'Server error (HTTP $statusCode). Please try again later.';
        }
        break;
      case DioExceptionType.connectionError:
        errorMessage = 'Cannot connect to backend at $_baseUrl. Make sure the backend server is running (npm start in backend folder).';
        break;
      case DioExceptionType.cancel:
        errorMessage = 'Request was cancelled.';
        break;
      default:
        errorMessage = 'Request failed: ${e.message}';
    }
    return AIRequestResult(success: false, error: errorMessage);
  }

  String _dioErrorToString(DioException e) {
    final result = _handleDioError(e);
    return result.error ?? 'Unknown error';
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