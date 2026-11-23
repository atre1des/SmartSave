import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../services/sync_service.dart';

/// Mounted inside the same ProviderScope as the authenticated account database.
class AccountSyncScope extends ConsumerWidget {
  const AccountSyncScope({super.key, required this.uid, required this.child});

  final String? uid;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (uid == null) return child;
    final user = ref.watch(authStateProvider).valueOrNull;
    return Stack(
      alignment: Alignment.topLeft,
      fit: StackFit.passthrough,
      children: [
        child,
        if (user?.uid == uid && user?.emailVerified == true)
          _SyncSession(key: ValueKey(uid), child: const SizedBox.shrink()),
      ],
    );
  }
}

class _SyncSession extends ConsumerStatefulWidget {
  const _SyncSession({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<_SyncSession> createState() => _SyncSessionState();
}

class _SyncSessionState extends ConsumerState<_SyncSession>
    with WidgetsBindingObserver {
  static const _retryDelays = [
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 45),
  ];

  Timer? _timer;
  StreamSubscription<void>? _changes;
  StreamSubscription<bool>? _connection;
  bool _foreground = true;
  bool _running = false;
  bool _requested = false;
  int _retry = 0;

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    final service = ref.read(syncServiceProvider);
    _changes = ref.read(financeRepositoryProvider).localChanges.listen((_) {
      _request(const Duration(milliseconds: 400));
    });
    _connection = service.connectionChanges.listen(
      (online) {
        if (online) _request();
      },
      onError: (Object _) {
        // The retry schedule, resume and manual action remain available.
      },
    );
    _request();
  }

  void _request([Duration delay = Duration.zero]) {
    _retry = 0;
    _requested = true;
    if (_foreground && !_running) _schedule(delay);
  }

  void _schedule(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay, _run);
  }

  Future<void> _run() async {
    if (!mounted || !_foreground || _running) return;
    _requested = false;
    _running = true;
    ref.read(syncStatusMessageProvider.notifier).state = 'Synchronizing…';
    try {
      final result = await ref.read(syncServiceProvider).performFullSync();
      if (!mounted || result.isNoAuth) return;
      if (result.downloaded > 0) {
        await ref.read(financeControllerProvider).refresh();
        if (!mounted) return;
      }
      final retryable =
          result.failed > 0 ||
          result.isFailure ||
          result.isOffline ||
          result.status == SyncResultStatus.initializationFailed;
      ref.read(syncStatusMessageProvider.notifier).state = result.conflicts > 0
          ? 'Some records need review. Pending changes were kept.'
          : retryable || result.status == SyncResultStatus.initializationFailed
          ? 'Sync is unavailable. Local records were kept.'
          : 'Financial records synchronized.';
      if (retryable &&
          _foreground &&
          !_requested &&
          _retry < _retryDelays.length) {
        _schedule(_retryDelays[_retry++]);
      }
    } finally {
      _running = false;
      if (mounted && _foreground && _requested) _schedule(Duration.zero);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _request();
    } else {
      _timer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(syncServiceProvider);
    ref.listen(syncRequestProvider, (_, _) => _request());
    return widget.child;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    unawaited(_changes?.cancel());
    unawaited(_connection?.cancel());
    super.dispose();
  }
}
