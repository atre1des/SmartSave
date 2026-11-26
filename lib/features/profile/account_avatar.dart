import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data/avatar_preferences.dart';
import '../../l10n/app_locale.dart';
import '../../shared/theme.dart';

class AccountAvatar extends ConsumerWidget {
  const AccountAvatar({super.key, this.diameter = 48, this.editable = false});

  final double diameter;
  final bool editable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatar = ref.watch(accountAvatarProvider);
    final portrait = _AvatarPortrait(avatar: avatar, diameter: diameter);
    final uid = ref.watch(avatarAccountProvider);
    if (!editable || uid == null) {
      return Semantics(label: _avatarLabel(context, avatar), child: portrait);
    }

    return Semantics(
      value: _avatarLabel(context, avatar),
      child: IconButton(
        tooltip: context.l10n.chooseAvatar,
        onPressed: () => _showAccountAvatarPicker(context, ref),
        icon: portrait,
      ),
    );
  }
}

Future<void> _showAccountAvatarPicker(
  BuildContext context,
  WidgetRef ref,
) async {
  final uid = ref.read(avatarAccountProvider);
  if (uid == null) return;
  final current = ref.read(accountAvatarProvider);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (_) => _AvatarPicker(uid: uid, initial: current),
  );
}

class _AvatarPortrait extends StatelessWidget {
  const _AvatarPortrait({required this.avatar, required this.diameter});

  final AnimalAvatar? avatar;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox.square(
      dimension: diameter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: avatar != null
              ? AppColors.mintLight
              : dark
              ? AppColors.firefly
              : AppColors.mintLight,
        ),
        child: Padding(
          padding: EdgeInsets.all(diameter * .10),
          child: avatar != null
              ? SvgPicture.asset(avatar!.asset, excludeFromSemantics: true)
              : Icon(
                  Icons.person_outline_rounded,
                  size: diameter * .56,
                  color: dark ? AppColors.mint : AppColors.firefly,
                ),
        ),
      ),
    );
  }
}

class _AvatarPicker extends ConsumerStatefulWidget {
  const _AvatarPicker({required this.uid, required this.initial});

  final String uid;
  final AnimalAvatar? initial;

  @override
  ConsumerState<_AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends ConsumerState<_AvatarPicker> {
  late AnimalAvatar? _selected = widget.initial;
  bool _saving = false;
  bool _saveFailed = false;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    var saved = false;
    try {
      saved = await ref.read(saveAccountAvatarProvider)(widget.uid, _selected);
    } catch (_) {
      // Keep the picker open and let the user retry a failed local write.
    }
    if (!mounted || ref.read(avatarAccountProvider) != widget.uid) return;
    if (saved) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _saving = false;
        _saveFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(avatarAccountProvider, (_, uid) {
      if (uid == widget.uid) return;
      _selected = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          Navigator.of(context).pop();
        }
      });
    });
    if (ref.watch(avatarAccountProvider) != widget.uid) {
      return const SizedBox.shrink();
    }
    final strings = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    strings.chooseAvatar,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    const gap = 8.0;
                    final largeText =
                        MediaQuery.textScalerOf(context).scale(13) > 19;
                    final columns = largeText || constraints.maxWidth < 315
                        ? 3
                        : 4;
                    final width =
                        (constraints.maxWidth - gap * (columns - 1)) / columns;
                    return Wrap(
                      runSpacing: gap,
                      spacing: gap,
                      children: [
                        for (final avatar in AnimalAvatar.values)
                          SizedBox(
                            width: width,
                            child: _AvatarChoice(
                              avatar: avatar,
                              selected: _selected == avatar,
                              onTap: _saving
                                  ? null
                                  : () => setState(() => _selected = avatar),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _saving || _selected == null
                      ? null
                      : () => setState(() => _selected = null),
                  child: Text(strings.resetAvatar),
                ),
                if (_saveFailed)
                  Text(
                    strings.avatarSaveFailed,
                    style: TextStyle(color: scheme.error),
                  ),
                const SizedBox(height: 6),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  children: [
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(strings.cancel),
                    ),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(112, 48),
                        backgroundColor: scheme.brightness == Brightness.dark
                            ? AppColors.mint
                            : AppColors.firefly,
                        foregroundColor: scheme.brightness == Brightness.dark
                            ? AppColors.firefly
                            : Colors.white,
                        shape: const StadiumBorder(),
                      ),
                      child: Text(strings.save),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarChoice extends StatelessWidget {
  const _AvatarChoice({
    required this.avatar,
    required this.selected,
    required this.onTap,
  });

  final AnimalAvatar avatar;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = _avatarLabel(context, avatar);
    final scheme = Theme.of(context).colorScheme;
    final accent = Theme.of(context).brightness == Brightness.dark
        ? AppColors.mint
        : AppColors.firefly;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: selected ? accent : Colors.transparent, width: 2),
    );
    return Semantics(
      label: label,
      selected: selected,
      button: true,
      enabled: onTap != null,
      onTap: onTap,
      child: Material(
        color: selected
            ? accent.withValues(alpha: .13)
            : scheme.surfaceContainer,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          excludeFromSemantics: true,
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _AvatarPortrait(avatar: avatar, diameter: 45),
                      if (selected)
                        PositionedDirectional(
                          end: -4,
                          bottom: 0,
                          child: Icon(
                            Icons.check_circle,
                            size: 16,
                            color: accent,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: scheme.onSurface),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _avatarLabel(BuildContext context, AnimalAvatar? avatar) {
  final strings = context.l10n;
  return switch (avatar) {
    null => strings.defaultAvatar,
    AnimalAvatar.dog => strings.avatarDog,
    AnimalAvatar.cat => strings.avatarCat,
    AnimalAvatar.rabbit => strings.avatarRabbit,
    AnimalAvatar.bear => strings.avatarBear,
    AnimalAvatar.panda => strings.avatarPanda,
    AnimalAvatar.koala => strings.avatarKoala,
    AnimalAvatar.tiger => strings.avatarTiger,
    AnimalAvatar.lion => strings.avatarLion,
    AnimalAvatar.pig => strings.avatarPig,
    AnimalAvatar.monkey => strings.avatarMonkey,
  };
}
