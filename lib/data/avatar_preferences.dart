import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import 'providers.dart';

enum AnimalAvatar {
  dog,
  cat,
  rabbit,
  bear,
  panda,
  koala,
  tiger,
  lion,
  pig,
  monkey;

  String get asset => 'assets/avatars/openmoji/$name.svg';
}

String avatarPreferenceKey(String uid) =>
    '${AuthService.avatarPreferenceName}_$uid';

final avatarAccountProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider).asData?.value?.uid,
);

final _avatarForAccount = StateNotifierProvider.autoDispose
    .family<AccountAvatarPreferences, AnimalAvatar?, String>(
      (ref, uid) => AccountAvatarPreferences(
        ref.watch(sharedPreferencesProvider),
        avatarPreferenceKey(uid),
      ),
    );

final accountAvatarProvider = Provider.autoDispose<AnimalAvatar?>((ref) {
  final uid = ref.watch(avatarAccountProvider);
  return uid == null ? null : ref.watch(_avatarForAccount(uid));
});

final saveAccountAvatarProvider = Provider(
  (ref) => (String uid, AnimalAvatar? avatar) async {
    if (ref.read(avatarAccountProvider) != uid) return false;
    return ref.read(_avatarForAccount(uid).notifier).save(avatar);
  },
);

class AccountAvatarPreferences extends StateNotifier<AnimalAvatar?> {
  AccountAvatarPreferences(this._preferences, this._key)
    : super(_decode(_preferences.get(_key)));

  final SharedPreferences _preferences;
  final String _key;

  static AnimalAvatar? _decode(Object? value) {
    for (final avatar in AnimalAvatar.values) {
      if (avatar.name == value) return avatar;
    }
    return null;
  }

  Future<bool> save(AnimalAvatar? avatar) async {
    final saved = avatar == null
        ? await _preferences.remove(_key)
        : await _preferences.setString(_key, avatar.name);
    if (saved && mounted) state = avatar;
    return saved;
  }
}
