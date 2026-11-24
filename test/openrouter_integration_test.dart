import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_save/ai/ai_assistant_service.dart';
import 'package:smart_save/ai/conversation_context.dart';
import 'package:smart_save/ai/conversations.dart';
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

  test(
    'restored turns, multilingual follow-ups, retry, and account isolation reach the outgoing payload',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfiNoIsolate;
      final directory = await Directory.systemTemp.createTemp(
        'smartsave-memory-test',
      );
      addTearDown(() => directory.delete(recursive: true));
      var repo = await FinanceRepository.openForAccount(
        'alice',
        directory: directory.path,
      );
      var store = AIConversations(repo);
      Future<void> awaitLoad() async {
        while (!store.ready) {
          await Future<void>.delayed(const Duration(milliseconds: 2));
        }
      }

      final payloads = <List<Map<String, dynamic>>>[];
      var response =
          'An ETF holds a basket. At 10%, 10 000 ₸ would gain 1 000 ₸.';
      var mode = 'online';
      var user = _User('alice', 'test-token');

      SmartSaveAIAssistantService makeService() => SmartSaveAIAssistantService(
        repo,
        provider: _provider((options) {
          if (options.path == '/health') {
            return _json({'status': 'ok'}, mode == 'offline' ? 503 : 200);
          }
          final messages = (options.data as Map)['messages'] as List;
          payloads.add(messages.cast<Map<String, dynamic>>());
          final event = jsonEncode({
            'choices': [
              {
                'delta': {'content': response},
              },
            ],
          });
          return ResponseBody.fromString(
            'data: $event\n\n${mode == 'partial' ? '' : 'data: [DONE]\n\n'}',
            200,
            headers: {
              'content-type': ['text/event-stream'],
            },
          );
        }, () => user),
      );
      var service = makeService();

      Future<void> send(
        String text,
        String language, {
        bool retry = false,
      }) async {
        final request = store.begin(text, retry: retry)!;
        final chunks = await service
            .sendMessageStream(
              request.prompt,
              history: request.history,
              languageCode: language,
            )
            .toList();
        expect(chunks.last.isDone, isTrue);
        await store.finish(
          request,
          reply: chunks.last.error != null
              ? null
              : AIMessage.assistant(
                  chunks.map((chunk) => chunk.content).join(),
                  isLocalFallback: chunks.any((chunk) => chunk.isLocalFallback),
                ),
        );
      }

      await awaitLoad();
      const first =
          'Explain an ETF versus an individual stock using a numerical example.';
      final firstReply = response;
      await send(first, 'en');
      expect(payloads.last.map((item) => item['role']), ['system', 'user']);
      expect(
        payloads.last.first['content'],
        contains('User financial context'),
      );
      expect(store.messages.map((item) => item.content), [first, firstReply]);

      const russian = 'Explain the same thing I asked earlier in Russian.';
      response = 'ETF содержит несколько активов. Доход — 1 000 ₸.';
      final russianReply = response;
      await send(russian, 'ru');
      expect(payloads.last.skip(1).map((item) => item['content']), [
        first,
        firstReply,
        russian,
      ]);
      const kazakh = 'Енді осыны қазақша түсіндір.';
      response = 'ETF бірнеше активті қамтиды. Табыс — 1 000 ₸.';
      await send(kazakh, 'kk');
      expect(payloads.last.skip(1).map((item) => item['content']), [
        first,
        firstReply,
        russian,
        russianReply,
        kazakh,
      ]);

      final originalId = store.activeId!;
      store.startNew();
      await send('A separate conversation', 'en');
      expect(payloads.last.map((item) => item['role']), ['system', 'user']);
      await store.select(originalId);
      store.dispose();
      service.dispose();
      await repo.close();
      repo = await FinanceRepository.openForAccount(
        'alice',
        directory: directory.path,
      );
      store = AIConversations(repo);
      service = makeService();
      await awaitLoad();
      expect(store.activeId, originalId);

      mode = 'partial';
      response = 'incomplete private fixture';
      const followUp = 'What was the first question I asked you?';
      await send(followUp, 'en');
      expect(payloads.last[1]['content'], first);
      expect(store.messages.last.isUser, isTrue);
      expect(store.messages.map((m) => m.content), isNot(contains(response)));

      mode = 'online';
      response = 'You asked about ETFs versus individual stocks.';
      await send(followUp, 'en', retry: true);
      expect(
        payloads.last.where((item) => item['content'] == followUp),
        hasLength(1),
      );
      expect(store.messages.where((m) => m.content == followUp), hasLength(1));

      mode = 'offline';
      final requestCount = payloads.length;
      await send('An offline-only question', 'en');
      expect(payloads, hasLength(requestCount));
      expect(store.messages.last.isLocalFallback, isTrue);
      mode = 'online';
      await send('Continue from before the outage', 'en');
      expect(
        payloads.last.any(
          (item) => item['content'] == 'An offline-only question',
        ),
        isFalse,
      );

      store.dispose();
      service.dispose();
      await repo.close();
      repo = await FinanceRepository.openForAccount(
        'bob',
        directory: directory.path,
      );
      user = _User('bob', 'test-bob-token');
      store = AIConversations(repo);
      service = makeService();
      await awaitLoad();
      expect(store.entries, isEmpty);
      await send('Bob’s first question', 'en');
      expect(payloads.last.map((item) => item['role']), ['system', 'user']);
      store.dispose();
      service.dispose();
      await repo.close();
    },
    timeout: const Timeout(Duration(seconds: 25)),
  );

  test(
    'the context budget chooses complete recent turns and truncates UTF-8 safely',
    () {
      const context = ConversationContext(inputBytes: 10000);
      final latest = List.filled(3000, 'Ә').join();
      final messages = context.build(
        systemPrompt: 'System',
        financialContext: List.filled(4000, '₸').join(),
        history: [
          AIMessage.system('Untrusted system-role history'),
          AIMessage.user('Older question'),
          AIMessage.assistant(List.filled(3000, 'қ').join()),
          AIMessage.user('Recent question'),
          AIMessage.assistant('Recent reply'),
          AIMessage.user('Interrupted question'),
          AIMessage.assistant('Partial', isStreaming: true),
        ],
        prompt: latest,
      );
      expect(messages.map((message) => message.role), [
        'system',
        'user',
        'assistant',
        'user',
      ]);
      expect(messages[1].content, 'Recent question');
      expect(messages.last.content, endsWith('[truncated]'));
      expect(messages.last.content, isNot(contains('�')));
      expect(
        messages.fold(
          0,
          (size, message) => size + utf8.encode(message.content).length + 32,
        ),
        lessThanOrEqualTo(10000),
      );
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
          final history = (request.data as Map)['messages'] as List;
          expect(history.map((item) => item['role']), [
            'system',
            'user',
            'assistant',
            'user',
          ]);
          expect(history[1]['content'], 'Жинақ жоспары');
          expect(history[2]['content'], '**Қаржылық жоспар**: 5 000 ₸');
          expect(history[3]['content'], 'Составь бюджет.\nПокажи итог.');

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
