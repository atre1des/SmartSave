import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
      final user = _User('fixture-user', 'test-token');

      OpenRouterProvider buildProvider() => _provider((request) {
        if (request.path == '/health') return _json({'status': 'ok'}, 200);
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
      await tester.enterText(find.byType(TextField), 'Fictional question');
      await tester.tap(find.byTooltip('Send question'));
      await tester.pump();
      expect(find.text('Fictional question', findRichText: true), findsWidgets);
      stream.add(
        Uint8List.fromList(
          utf8.encode(
            'data: {"choices":[{"delta":{"content":"Fictional reply"}}]}\n\n',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.textContaining('Fictional reply', findRichText: true),
        findsWidgets,
      );
      stream.add(Uint8List.fromList(utf8.encode('data: [DONE]\n\n')));
      await stream.close();
      await tester.pumpAndSettle();
      expect(
        await repo.assistantConversationHistory(),
        contains('Fictional reply'),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await open();
      expect(
        find.textContaining('Fictional reply', findRichText: true),
        findsWidgets,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
    timeout: const Timeout(Duration(seconds: 20)),
  );
}
