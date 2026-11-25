part of 'workspace.dart';

class _LiveWorkspace extends StatefulWidget {
  const _LiveWorkspace({required this.repository});
  final WebFinanceRepository repository;
  @override
  State<_LiveWorkspace> createState() => _LiveWorkspaceState();
}

class _LiveWorkspaceState extends State<_LiveWorkspace> {
  late final WebFinanceRepository _repository = widget.repository;
  WebSnapshot? _data;
  bool _loading = true;
  bool _unavailable = false;
  int _generation = 0;
  StreamSubscription<web.Event>? _offline;
  StreamSubscription<web.Event>? _online;

  @override
  void initState() {
    super.initState();
    _offline = web.EventStreamProviders.offlineEvent
        .forTarget(web.window)
        .listen((_) {
          if (!mounted) return;
          _generation++;
          setState(() {
            _unavailable = true;
            _loading = false;
          });
        });
    _online = web.EventStreamProviders.onlineEvent.forTarget(web.window).listen(
      (_) {
        if (mounted) unawaited(_refresh());
      },
    );
    unawaited(_refresh());
  }

  @override
  void dispose() {
    _repository.close();
    unawaited(_offline?.cancel());
    unawaited(_online?.cancel());
    super.dispose();
  }

  Future<void> _refresh() async {
    final generation = ++_generation;
    if (mounted) {
      setState(() {
        _loading = true;
        _unavailable = false;
      });
    }
    try {
      final snapshot = await _repository.snapshot();
      if (mounted && _repository.active && generation == _generation) {
        setState(() => _data = snapshot);
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _unavailable = true);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_repository.active) return const SizedBox.shrink();
    final data = _data;
    if (data == null) {
      return Scaffold(
        body: Center(
          child: _unavailable
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_webUnavailable(context)),
                    TextButton(
                      onPressed: _refresh,
                      child: Text(context.l10n.retry),
                    ),
                    TextButton(
                      onPressed: _repository.auth.signOut,
                      child: Text(context.l10n.signOut),
                    ),
                  ],
                )
              : const CircularProgressIndicator(),
        ),
      );
    }
    final locale = data.preferenceRows.firstOrNull?.data['locale'];
    final workspace = _ReviewWorkspace(
      data: data,
      repository: _repository,
      stale: _unavailable,
      loading: _loading,
      refresh: _refresh,
      onLocale: (locale) async {
        try {
          await _repository.save(
            'webPreferences',
            _repository.operationId(),
            data.preferenceRows.firstOrNull,
            {'locale': locale.languageCode},
          );
          await _refresh();
        } catch (error) {
          if (context.mounted && _repository.active) {
            showMessage(context, _writeNotice(context, error));
          }
        }
      },
    );
    return Localizations.override(
      context: context,
      locale: locale is String
          ? Locale(locale)
          : Localizations.localeOf(context),
      child: workspace,
    );
  }
}

String _webUnavailable(BuildContext context) => _copy(
  context,
  'Server unavailable. Check your connection and retry.',
  'Сервер қолжетімсіз. Байланысты тексеріп, қайталап көріңіз.',
  'Сервер недоступен. Проверьте подключение и повторите попытку.',
);

String _writeNotice(BuildContext context, Object error) =>
    error == WebDataIssue.conflict
    ? _copy(
        context,
        'Some records need review. Reload before editing.',
        'Кейбір жазбалар өзгерген. Өңдеу алдында жаңартыңыз.',
        'Некоторые записи изменились. Обновите их перед редактированием.',
      )
    : _webUnavailable(context);

Widget _financeActions(
  BuildContext context,
  WebFinanceRepository repository,
  WebSnapshot data,
  Future<void> Function() refresh,
) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    _Heading(context.l10n.transactions),
    const SizedBox(height: 8),
    OutlinedButton(
      onPressed: () =>
          _editRecord(context, repository, 'transactions', null, refresh),
      child: Text(context.l10n.addTransaction),
    ),
    for (final row in data.transactionRows)
      ListTile(
        title: Text(row.data['merchant'] as String),
        subtitle: Text(
          context.transactionCategory(row.data['category'] as String),
        ),
        trailing: Text(
          context
              .formatSignedTenge(
                row.data['amount'] as int,
                income: row.data['isIncome'] == true,
              )
              .replaceFirst('−', '-'),
        ),
        onTap: () =>
            _editRecord(context, repository, 'transactions', row, refresh),
      ),
    const SizedBox(height: 20),
    _Heading(context.l10n.goals),
    const SizedBox(height: 8),
    OutlinedButton(
      onPressed: () => _editRecord(context, repository, 'goals', null, refresh),
      child: Text(context.l10n.newGoal),
    ),
    for (final row in data.goalRows)
      ListTile(
        title: Text(row.data['name'] as String),
        onTap: () => _editRecord(context, repository, 'goals', row, refresh),
        trailing: TextButton(
          onPressed: () =>
              _editRecord(context, repository, 'contributions', row, refresh),
          child: Text(context.l10n.addMoney),
        ),
      ),
    const SizedBox(height: 20),
    _Heading(context.l10n.editMonthlyBudget),
    const SizedBox(height: 8),
    OutlinedButton(
      onPressed: () => _editRecord(
        context,
        repository,
        'budgets',
        null,
        refresh,
        budgets: data.budgetRows,
      ),
      child: Text(context.l10n.editBudget),
    ),
    for (final row in data.budgetRows)
      ListTile(
        title: Text(
          context.transactionCategory(row.data['category'] as String),
        ),
        trailing: Text(context.formatTenge(row.data['monthlyLimit'] as int)),
        onTap: () => _editRecord(context, repository, 'budgets', row, refresh),
      ),
    const SizedBox(height: 20),
    _Heading(context.l10n.spendingByCategory),
    for (final entry in data.spending.entries)
      ListTile(
        title: Text(context.transactionCategory(entry.key)),
        trailing: Text(context.formatTenge(entry.value)),
      ),
  ],
);

Future<void> _editRecord(
  BuildContext context,
  WebFinanceRepository repository,
  String collection,
  CloudRow? row,
  Future<void> Function() refresh, {
  List<CloudRow> budgets = const [],
}) async {
  final saved = await showEditorSheet<bool>(
    context: context,
    builder: (_) => Localizations.override(
      context: context,
      child: _CloudEditor(
        repository: repository,
        collection: collection,
        row: row,
        budgets: budgets,
      ),
    ),
  );
  if (saved == true && repository.active) await refresh();
}

class _CloudEditor extends StatefulWidget {
  const _CloudEditor({
    required this.repository,
    required this.collection,
    this.row,
    required this.budgets,
  });
  final WebFinanceRepository repository;
  final String collection;
  final CloudRow? row;
  final List<CloudRow> budgets;
  @override
  State<_CloudEditor> createState() => _CloudEditorState();
}

class _CloudEditorState extends State<_CloudEditor> {
  late final _operation = widget.repository.operationId();
  late final _name = TextEditingController(
    text: switch (widget.collection) {
      'goals' => widget.row?.data['name'] as String?,
      'transactions' => widget.row?.data['merchant'] as String?,
      _ => null,
    },
  );
  late final _amount = TextEditingController(
    text: switch (widget.collection) {
      'goals' => widget.row?.data['target']?.toString(),
      'transactions' => widget.row?.data['amount']?.toString(),
      'budgets' => widget.row?.data['monthlyLimit']?.toString(),
      _ => null,
    },
  );
  late bool _income = widget.row?.data['isIncome'] == true;
  late String _category = widget.row?.data['category'] as String? ?? 'Food';
  late DateTime _date =
      DateTime.tryParse(
        (widget.row?.data[widget.collection == 'goals'
                    ? 'deadline'
                    : 'occurredAt']
                as String?) ??
            '',
      )?.toLocal() ??
      DateTime.now();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save({bool delete = false}) async {
    final amount = int.tryParse(_amount.text.trim());
    final name = _name.text.trim();
    final collection = widget.collection;
    if (!delete &&
        (amount == null ||
            amount < 0 ||
            amount > 1000000000000 ||
            (amount == 0 && collection != 'budgets') ||
            (const {'goals', 'transactions'}.contains(collection) &&
                name.isEmpty))) {
      setState(() => _error = context.l10n.amountTenge);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (collection == 'contributions') {
        await widget.repository.contribute(_operation, widget.row!, amount!);
      } else {
        final fields = delete
            ? <String, Object?>{'isDeleted': true, 'syncStatus': 'deleted'}
            : switch (collection) {
                'goals' => {
                  'name': name,
                  'target': amount!,
                  'deadline': _date.toIso8601String(),
                  if (widget.row == null) ...{'saved': 0, 'purpose': ''},
                },
                'transactions' => {
                  'merchant': name,
                  'amount': amount!,
                  'isIncome': _income,
                  'category': _category,
                  'occurredAt': _date.toIso8601String(),
                  if (widget.row == null) ...{
                    'note': '',
                    'source': 'Manual entry',
                  },
                },
                _ => {'category': _category, 'monthlyLimit': amount!},
              };
        final matchingBudgets = widget.budgets.where(
          (budget) => budget.data['category'] == _category,
        );
        if (collection == 'budgets' && matchingBudgets.length > 1) {
          throw WebDataIssue.conflict;
        }
        await widget.repository.save(
          collection,
          _operation,
          widget.row ??
              (collection == 'budgets' ? matchingBudgets.firstOrNull : null),
          fields,
        );
      }
      if (mounted && widget.repository.active) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted && widget.repository.active) {
        setState(() => _error = _writeNotice(context, error));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    final collection = widget.collection;
    final creating = widget.row == null;
    final isGoal = collection == 'goals';
    final isTransaction = collection == 'transactions';
    return EditorSheet(
      title: Text(switch (collection) {
        'goals' => creating ? strings.newGoal : strings.editGoal,
        'transactions' =>
          creating ? strings.addTransaction : strings.editTransaction,
        'contributions' => strings.addMoney,
        _ => strings.editBudget,
      }),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isGoal || isTransaction)
            TextField(
              controller: _name,
              enabled: !_saving,
              maxLength: 120,
              decoration: InputDecoration(
                labelText: isGoal ? strings.goalName : strings.merchant,
              ),
            ),
          TextField(
            controller: _amount,
            enabled: !_saving,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: isGoal ? strings.target : strings.amountTenge,
            ),
          ),
          if (isTransaction || collection == 'budgets') ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: InputDecoration(labelText: strings.category),
              items: [
                for (final category in {
                  'Food',
                  'Transport',
                  'Shopping',
                  'Home',
                  'Health',
                  'Salary',
                  'Other',
                  _category,
                })
                  DropdownMenuItem(
                    value: category,
                    child: Text(context.transactionCategory(category)),
                  ),
              ],
              onChanged: _saving || (collection == 'budgets' && !creating)
                  ? null
                  : (value) {
                      if (value != null) setState(() => _category = value);
                    },
            ),
          ],
          if (isTransaction)
            SwitchListTile(
              title: Text(strings.income),
              value: _income,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _income = value),
            ),
          if (isGoal || isTransaction)
            TextButton(
              onPressed: _saving
                  ? null
                  : () async {
                      final date = await showDatePicker(
                        useRootNavigator: false,
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(1900),
                        lastDate: DateTime(2200),
                      );
                      if (date != null && mounted) setState(() => _date = date);
                    },
              child: Text(
                '${isGoal ? strings.deadline : strings.date}: ${context.formatShortDate(_date)}',
              ),
            ),
          if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(strings.cancel),
        ),
        if (!creating && (isGoal || isTransaction))
          TextButton(
            onPressed: _saving
                ? null
                : () async {
                    final confirmed = await showDialog<bool>(
                      useRootNavigator: false,
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(
                          isGoal
                              ? strings.deleteGoalQuestion
                              : strings.deleteTransaction,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(strings.cancel),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(strings.delete),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true && mounted) await _save(delete: true);
                  },
            child: Text(strings.delete),
          ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(strings.save),
        ),
      ],
    );
  }
}

Widget _liveInvestment(
  BuildContext context,
  WebSnapshot data,
  VoidCallback onAssistant,
) => _SectionPage(
  title: context.l10n.investmentIntelligence,
  child: _Columns(
    primary: RecordGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Heading(context.l10n.theses),
          if (data.thesisRows.isEmpty)
            Text(
              _copy(
                context,
                'No saved theses.',
                'Сақталған тезис жоқ.',
                'Сохранённых тезисов нет.',
              ),
            ),
          for (final row in data.thesisRows)
            ListTile(
              title: Text(row.data['securityName'] as String),
              subtitle: Text(row.data['rationale'] as String),
            ),
        ],
      ),
    ),
    secondary: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RecordGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Heading(context.l10n.portfolioHoldings),
              if (data.holdingRows.isEmpty)
                Text(
                  _copy(
                    context,
                    'No saved holdings.',
                    'Сақталған активтер жоқ.',
                    'Сохранённых активов нет.',
                  ),
                ),
              for (final row in data.holdingRows)
                ListTile(
                  title: Text(row.data['securityName'] as String),
                  trailing: Text(
                    context.formatTenge(row.data['marketValueKzt'] as int),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _Deferred(
          heading: context.l10n.explore,
          description: context.l10n.portfolioUnknownNotice,
        ),
        TextButton(
          onPressed: onAssistant,
          child: Text(context.l10n.askSmartSaveShort),
        ),
      ],
    ),
  ),
);

Widget _accountActions(
  BuildContext context,
  WebFinanceRepository repository,
  WebSnapshot data,
  Future<void> Function() refresh,
  bool stale,
) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    _Heading(context.l10n.privacyData),
    Text(repository.auth.currentUser?.email ?? ''),
    const SizedBox(height: 10),
    OutlinedButton(onPressed: refresh, child: Text(context.l10n.syncRecords)),
    OutlinedButton(
      onPressed: stale
          ? null
          : () async {
              try {
                final snapshot = await repository.snapshot();
                if (!context.mounted || !repository.active) return;
                final export =
                    JsonEncoder.withIndent(
                      '  ',
                      (value) => value is Timestamp
                          ? value.toDate().toIso8601String()
                          : value.toString(),
                    ).convert({
                      'transactions': snapshot.transactionRows
                          .map((r) => r.data)
                          .toList(),
                      'goals': snapshot.goalRows.map((r) => r.data).toList(),
                      'budgets': snapshot.budgetRows
                          .map((r) => r.data)
                          .toList(),
                      'investmentTheses': snapshot.thesisRows
                          .map((r) => r.data)
                          .toList(),
                      'portfolioHoldings': snapshot.holdingRows
                          .map((r) => r.data)
                          .toList(),
                    });
                await showEditorSheet<void>(
                  context: context,
                  builder: (context) => EditorSheet(
                    title: Text(context.l10n.localDataExport),
                    content: SizedBox(
                      height: 260,
                      child: SingleChildScrollView(
                        child: SelectableText(export),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () async {
                          if (!repository.active) return;
                          await Clipboard.setData(ClipboardData(text: export));
                          if (context.mounted && repository.active) {
                            Navigator.pop(context);
                          }
                        },
                        child: Text(context.l10n.copyJson),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(context.l10n.close),
                      ),
                    ],
                  ),
                );
              } catch (error) {
                if (context.mounted && repository.active) {
                  showMessage(context, _writeNotice(context, error));
                }
              }
            },
      child: Text(context.l10n.exportData),
    ),
    _Deferred(
      heading: context.l10n.deleteAccount,
      description: context.l10n.privacyDisclosure,
    ),
    TextButton(
      onPressed: () async {
        try {
          await repository.auth.signOut();
        } catch (error) {
          if (context.mounted) {
            showMessage(context, _writeNotice(context, error));
          }
        }
      },
      child: Text(context.l10n.signOut),
    ),
  ],
);
