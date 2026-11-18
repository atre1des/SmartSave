import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smart_save/data/finance_repository.dart';
import 'package:smart_save/features/advice/financial_assistant_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late FinanceRepository repository;
  late FinancialAssistantService assistant;

  setUp(() async {
    repository = await FinanceRepository.open(
      databasePath: inMemoryDatabasePath,
    );
    assistant = FinancialAssistantService(repository);
  });
  tearDown(() => repository.close());

  test('answers budget questions from saved SQLite records', () async {
    final answer = await assistant.answer('Am I within budget?');
    expect(answer, contains('recorded expenses this month'));
    expect(answer, contains('Food'));
    expect(answer, contains('sample transactions may be fictional'));
  });

  test('explains goals using local goal calculations', () async {
    final answer = await assistant.answer('How are my goals progressing?');
    expect(answer, contains('New laptop'));
    expect(answer, contains('per month'));
    expect(answer, contains('do not move money'));
  });

  test('does not pretend to provide live quotes or generative AI', () async {
    final answer = await assistant.answer('What is the current stock price?');
    expect(answer, contains('no live market feed'));
    final fallback = await assistant.answer('Tell me a joke about SmartSave');
    expect(fallback, contains('no generative AI'));
  });
}
