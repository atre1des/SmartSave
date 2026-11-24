import 'package:flutter/material.dart';

import 'theme.dart';
import 'glass.dart';

String formatTenge(int amount) {
  final digits = amount.abs().toString();
  final grouped = digits.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ' ',
  );
  return '${amount < 0 ? '−' : ''}$grouped ₸';
}

String formatSignedTenge(int amount, {required bool income}) =>
    '${income ? '+' : '−'}${formatTenge(amount).replaceAll('−', '')}';

String formatShortDate(DateTime date) =>
    '${date.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][date.month - 1]} ${date.year}';

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.trailing, this.onTrailing});
  final String title;
  final String? trailing;
  final VoidCallback? onTrailing;

  @override
  Widget build(BuildContext context) {
    final heading = Text(title, style: Theme.of(context).textTheme.titleMedium);
    final action = trailing;
    if (action == null) return heading;

    return Row(
      children: [
        Expanded(child: heading),
        TextButton(
          onPressed: onTrailing,
          child: Text(
            action,
            style: TextStyle(
              color: context.colors.action,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.onTap,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fill = color ?? colors.surface;
    final radius = BorderRadius.circular(16);
    final shape = RoundedRectangleBorder(
      borderRadius: radius,
      side: fill == colors.surface
          ? BorderSide(color: colors.outline)
          : BorderSide.none,
    );
    final content = SizedBox(
      width: double.infinity,
      child: Padding(padding: padding, child: child),
    );
    return Material(
      color: fill,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 52,
    child: FilledButton.icon(
      onPressed: onPressed,
      icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 18),
      label: Text(label),
    ),
  );
}

class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onTap(),
    showCheckmark: false,
    labelStyle: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: selected ? context.colors.onSelection : context.colors.text,
    ),
    backgroundColor: context.colors.surface,
    selectedColor: context.colors.selection,
    side: BorderSide(
      color: selected ? context.colors.selection : context.colors.fieldOutline,
    ),
    shape: const StadiumBorder(),
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
  );
}

class ProgressTrack extends StatelessWidget {
  const ProgressTrack({
    super.key,
    required this.value,
    this.height = 10,
    this.color,
  });
  final double value;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(height / 2),
    child: LinearProgressIndicator(
      value: value.clamp(0, 1),
      minHeight: height,
      backgroundColor: context.colors.mutedSurface,
      color: color ?? context.colors.progress,
    ),
  );
}

class LabeledValue extends StatelessWidget {
  const LabeledValue({
    super.key,
    required this.label,
    required this.value,
    this.trailing,
  });
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class PrimaryAction extends StatelessWidget {
  const PrimaryAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 52,
    child: FilledButton(
      onPressed: busy ? null : onPressed,

      child: busy
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    ),
  );
}

class SecondaryAction extends StatelessWidget {
  const SecondaryAction({
    super.key,
    required this.label,
    required this.onPressed,
  });
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 52,
    child: OutlinedButton(
      onPressed: onPressed,

      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    ),
  );
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class AppNavigationBar extends StatelessWidget {
  const AppNavigationBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<({String label, Widget icon})> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 300);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(18, 5, 18, 12),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: GlassSurface(
            radius: 36,
            padding: const EdgeInsets.all(5),
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedPositionedDirectional(
                    duration: duration,
                    curve: Curves.easeOutBack,
                    start:
                        constraints.maxWidth *
                        selectedIndex /
                        destinations.length,
                    width: constraints.maxWidth / destinations.length,
                    top: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.action.withValues(
                            alpha: colors.isDark ? .2 : .11,
                          ),
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < destinations.length; i++)
                        Expanded(
                          child: Semantics(
                            selected: i == selectedIndex,
                            button: true,
                            label: destinations[i].label,
                            child: Material(
                              type: MaterialType.transparency,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(28),
                                onTap: () => onSelected(i),
                                child: ExcludeSemantics(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 7,
                                      horizontal: 2,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        destinations[i].icon,
                                        const SizedBox(height: 3),
                                        Text(
                                          destinations[i].label,
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: i == selectedIndex
                                                ? colors.action
                                                : colors.muted,
                                            fontWeight: i == selectedIndex
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
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
