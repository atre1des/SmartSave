import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_save/ai/ai_assistant_service.dart';
import 'package:smart_save/ai/models.dart';
import 'package:smart_save/ai/openrouter_provider.dart';
import 'package:smart_save/data/finance_repository.dart';
import 'package:smart_save/data/providers.dart';
import 'package:smart_save/features/advice/ai_assistant_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final _messages = [AIMessage.user('Test question')];

class _User implements User {
  _User(this.uid, this.token);

  @override
  final String uid;
  String token;
  Completer<String?>? pending;

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async =>
      pending == null ? token : await pending!.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final ResponseBody Function(RequestOptions) respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => respond(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(
  Object value,
  int status, {
  Map<String, List<String>>? headers,
}) => ResponseBody.fromString(
  jsonEncode(value),
  status,
  headers: {
    'content-type': ['application/json'],
    ...?headers,
  },
);

OpenRouterProvider _provider(
  ResponseBody Function(RequestOptions) respond,
  User? Function() currentUser,
) => OpenRouterProvider(
  dio: Dio()..httpClientAdapter = _Adapter(respond),
  baseUrl: 'http://10.0.2.2:3001',
  currentUser: currentUser,
);

void main() {
  test('Android defaults to the emulator host bridge', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final provider = OpenRouterProvider(currentUser: () => null);
    addTearDown(provider.dispose);
    expect(provider.backendUrl, 'http://10.0.2.2:3001');
  });

  test('hosted HTTPS probes coalesce and never replay a completion', () async {
    final requests = <RequestOptions>[];
    var probes = 0;
    final provider = OpenRouterProvider(
      baseUrl: 'https://proxy.example.invalid',
      currentUser: () => _User('alice', 'test-token'),
      dio: Dio()
        ..httpClientAdapter = _Adapter((request) {
          requests.add(request);
          if (request.path == '/health') {
            probes++;
            return probes == 1
                ? ResponseBody.fromString('waking', 502)
                : _json({'status': 'ok'}, 200);
          }
          return _json({'code': 'OPENROUTER_HTTP_403'}, 403);
        }),
    );
    addTearDown(provider.dispose);

    expect(
      await Future.wait([
        provider.checkBackendHealth(),
        provider.checkBackendHealth(),
      ]),
      [true, true],
    );
    final error = await provider.sendMessageStream(messages: _messages).single;
    expect(error.error, contains('refused access'));
    expect(requests.map((request) => request.method), ['GET', 'GET', 'POST']);
    for (final request in requests) {
      expect(request.uri.scheme, 'https');
      expect(request.uri.host, 'proxy.example.invalid');
      expect(request.followRedirects, isFalse);
    }
    expect(requests.first.headers['Authorization'], isNull);
    expect(requests.last.headers['Authorization'], 'Bearer test-token');
  });

  test(
    'remote cleartext is rejected before any probe or token request',
    () async {
      final provider = OpenRouterProvider(
        baseUrl: 'http://proxy.example.invalid',
        currentUser: () => _User('alice', 'test-token'),
        dio: Dio()
          ..httpClientAdapter = _Adapter((_) {
            fail('The client must not send a request over remote HTTP.');
          }),
      );
      addTearDown(provider.dispose);
      expect(await provider.checkBackendHealth(), isFalse);
      final result = await provider.sendMessage(messages: _messages);
      expect(result.success, isFalse);
      expect(result.error, contains('trusted HTTPS'));
    },
  );

  test('late sign-in, token rotation and account boundaries', () async {
    _User? current;
    final sent = <RequestOptions>[];
    ResponseBody respond(RequestOptions options) {
      sent.add(options);
      return _json({
        'choices': [
          {
            'message': {'content': 'Reply'},
          },
        ],
      }, 200);
    }

    final provider = _provider(respond, () => current);
    addTearDown(provider.dispose);

    expect((await provider.sendMessage(messages: _messages)).success, isFalse);
    expect(sent, isEmpty);
    final alice = _User('alice', 'first-test-token');
    current = alice;
    expect((await provider.sendMessage(messages: _messages)).success, isTrue);
    expect(sent.single.uri.host, '10.0.2.2');
    expect(sent.single.uri.port, 3001);
    expect(sent.single.headers['Authorization'], 'Bearer first-test-token');
    expect(sent.single.followRedirects, isFalse);
    expect(sent.single.data, isNot(contains('model')));

    alice.token = 'rotated-test-token';
    await provider.sendMessage(messages: _messages);
    expect(sent.last.headers['Authorization'], 'Bearer rotated-test-token');

    alice.pending = Completer<String?>();
    final stale = provider.sendMessage(messages: _messages);
    await Future<void>.delayed(Duration.zero);
    current = null;
    alice.pending!.complete(alice.token);
    expect((await stale).success, isFalse);
    expect((await provider.sendMessage(messages: _messages)).success, isFalse);

    current = _User('bob', 'bob-test-token');
    expect((await provider.sendMessage(messages: _messages)).success, isFalse);
    expect(sent, hasLength(2));
    final newSession = _provider(respond, () => current);
    addTearDown(newSession.dispose);
    expect((await newSession.sendMessage(messages: _messages)).success, isTrue);
    expect(sent.last.headers['Authorization'], 'Bearer bob-test-token');
  });

  test(
    'stream errors retain sign-in, quota and provider failure distinctions',
    () async {
      for (final (status, code, expected) in [
        (401, 'AUTH_INVALID', 'sign-in'),
        (401, 'OPENROUTER_HTTP_401', 'proxy credentials'),
        (402, 'OPENROUTER_HTTP_402', 'insufficient credits'),
        (429, 'OPENROUTER_DAILY_QUOTA_EXCEEDED', 'daily quota'),
        (500, 'OPENROUTER_HTTP_500', 'temporarily unavailable'),
        (502, 'OPENROUTER_HTTP_502', 'invalid response'),
        (503, 'OPENROUTER_HTTP_503', 'unavailable or restarting'),
        (503, 'OPENROUTER_KEY_MISSING', 'no OpenRouter key'),
        (504, 'UPSTREAM_TIMEOUT', 'timed out'),
      ]) {
        final provider = _provider((request) {
          if (request.path == '/health') return _json({'status': 'ok'}, 200);
          return _json(
            {'code': code, 'isDailyQuota': status == 429},
            status,
            headers: {
              'retry-after': ['14'],
            },
          );
        }, () => _User('alice', 'test-token'));
        addTearDown(provider.dispose);
        expect(await provider.checkBackendHealth(), isTrue);
        final chunk = await provider
            .sendMessageStream(messages: _messages)
            .single;
        expect(chunk.error, contains(expected));
        expect(chunk.isDone, isTrue);
        expect(chunk.isDailyQuotaExhausted, status == 429);
        expect(chunk.isRateLimitError, status == 429);
        expect(chunk.retryAfterSeconds, 14);
      }

      final timedOut = _provider(
        (options) => throw DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
        ),
        () => _User('alice', 'test-token'),
      );
      addTearDown(timedOut.dispose);
      final chunk = await timedOut
          .sendMessageStream(messages: _messages)
          .single;
      expect(chunk.error, contains('timed out'));
    },
  );

  test('SSE decodes split UTF-8 and requires completion', () async {
    final bytes = utf8.encode(
      'data: {"choices":[{"delta":{"content":"₸500"}}]}\r\n\r\n',
    );
    final split = bytes.indexOf(0xe2) + 1;
    final provider = _provider(
      (_) => ResponseBody(
        Stream.fromIterable([
          Uint8List.fromList(bytes.sublist(0, split)),
          Uint8List.fromList(bytes.sublist(split)),
        ]),
        200,
        headers: {
          'content-type': ['text/event-stream'],
        },
      ),
      () => _User('alice', 'test-token'),
    );
    addTearDown(provider.dispose);
    final chunks = await provider
        .sendMessageStream(messages: _messages)
        .toList();
    expect(chunks.first.content, '₸500');
    expect(chunks.last.error, contains('before completion'));
  });

  test(
    'mocked English, Kazakh and Russian streams preserve prompts and replies',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfiNoIsolate;
      final repo = await FinanceRepository.open(
        databasePath: inMemoryDatabasePath,
        seed: false,
      );
      addTearDown(repo.close);
      final user = _User('fixture-user', 'test-token');
      for (final (language, prompt, reply) in [
        ('en', 'How can I set a budget?', '**Monthly budget**'),
        (
          'kk',
          'Әр шығынды қалай бақылаймын?',
          '**Жинақ мақсаты**: Ғ, Қ, Ң, Ө, Ұ, Ү, Һ, І',
        ),
        ('ru', 'Как составить бюджет на месяц?', '**Расходы**: 50 000 ₸'),
      ]) {
        final provider = _provider((request) {
          if (request.path == '/health') return _json({'status': 'ok'}, 200);
          final messages = (request.data as Map)['messages'] as List;
          expect(messages.last['content'], prompt);
          expect(messages.first['content'], contains('latest user message'));
          expect(
            messages.first['content'],
            contains('app language code: $language'),
          );
          final event = jsonEncode({
            'choices': [
              {
                'delta': {'content': reply},
              },
            ],
          });
          return ResponseBody.fromString(
            'data: $event\n\ndata: [DONE]\n\n',
            200,
            headers: {
              'content-type': ['text/event-stream'],
            },
          );
        }, () => user);
        final service = SmartSaveAIAssistantService(repo, provider: provider);
        addTearDown(service.dispose);
        final chunks = await service
            .sendMessageStream(prompt, languageCode: language)
            .toList();
        expect(chunks.first.content, reply);
        expect(chunks.last.isDone, isTrue);
        expect(chunks.last.error, isNull);
      }

      final offlineProvider = _provider((request) {
        expect(request.path, '/health');
        return _json({'status': 'down'}, 503);
      }, () => user);
      final offline = SmartSaveAIAssistantService(
        repo,
        provider: offlineProvider,
      );
      addTearDown(offline.dispose);
      final kazakh = await offline
          .sendMessageStream('Мақсатты қалай қоямын?')
          .toList();
      final russian = await offline
          .sendMessageStream('Как составить бюджет?')
          .toList();
      expect(kazakh.first.content, contains('Мақсаттар'));
      expect(russian.first.content, contains('расходы и бюджеты'));
      expect(kazakh.last.isDone && russian.last.isDone, isTrue);
    },
  );

  testWidgets(
    'SSE renders before completion and reopens persisted replies',
    (tester) async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfiNoIsolate;
      final repo = await FinanceRepository.open(
        databasePath: inMemoryDatabasePath,
        accountUid: 'fixture-user',
        seed: false,
      );
      addTearDown(repo.close);
      final stream = StreamController<Uint8List>();
      var sentRequests = 0;
      final user = _User('fixture-user', 'test-token');

      OpenRouterProvider buildProvider() => _provider((request) {
        if (request.path == '/health') return _json({'status': 'ok'}, 200);
        sentRequests++;
        if (sentRequests == 2) {
          return ResponseBody.fromString(
            'data: {"choices":[{"delta":{"content":"Ответ принят."}}]}\n\ndata: [DONE]\n\n',
            200,
            headers: {
              'content-type': ['text/event-stream'],
            },
          );
        }
        return ResponseBody(
          stream.stream,
          200,
          headers: {
            'content-type': ['text/event-stream'],
          },
        );
      }, () => user);

      Future<void> open() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [financeRepositoryProvider.overrideWithValue(repo)],
            child: MaterialApp(
              home: AIAssistantScreen(provider: buildProvider()),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await open();
      expect(find.text('Proxy reachable'), findsOneWidget);
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final input = find.byType(TextField);
      await tester.enterText(input, '  ');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(find.byTooltip('Send question'), findsOneWidget);
      await tester.enterText(input, 'Жинақ жоспары');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      final controller = tester.widget<TextField>(input).controller!;
      expect(controller.text, 'Жинақ жоспары\n');
      controller.value = controller.value.copyWith(
        composing: const TextRange(start: 0, end: 4),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(controller.text, 'Жинақ жоспары\n');
      controller.clearComposing();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(controller.text, isEmpty);
      expect(find.text('Жинақ жоспары', findRichText: true), findsOneWidget);
      stream.add(
        Uint8List.fromList(
          utf8.encode(
            'data: {"choices":[{"delta":{"content":"**Қаржылық жоспар**: 5 000 ₸"}}]}\n\n',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.textContaining('Қаржылық жоспар: 5 000 ₸', findRichText: true),
        findsWidgets,
      );
      expect(
        tester
            .widget<EditableText>(
              find.descendant(of: input, matching: find.byType(EditableText)),
            )
            .focusNode
            .hasFocus,
        isTrue,
      );
      expect(sentRequests, 1);
      stream.add(Uint8List.fromList(utf8.encode('data: [DONE]\n\n')));
      await stream.close();
      await tester.pumpAndSettle();
      expect(
        await repo.assistantConversationHistory(),
        contains('**Қаржылық жоспар**: 5 000 ₸'),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await open();
      expect(
        find.textContaining('Қаржылық жоспар: 5 000 ₸', findRichText: true),
        findsWidgets,
      );
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await tester.enterText(input, 'Составь бюджет.\nПокажи итог.');
      expect(
        tester.widget<TextField>(input).textInputAction,
        TextInputAction.newline,
      );
      await tester.testTextInput.receiveAction(TextInputAction.newline);
      await tester.pump();
      expect(sentRequests, 1);
      await tester.tap(find.byTooltip('Send question'));
      await tester.pumpAndSettle();
      expect(sentRequests, 2);
      expect(
        find.textContaining('Ответ принят.', findRichText: true),
        findsWidgets,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    },
    timeout: const Timeout(Duration(seconds: 20)),
  );
}
