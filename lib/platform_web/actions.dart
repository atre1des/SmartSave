part of 'workspace.dart';

bool _usesDesktopActions(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= _desktopBreakpoint;

ThemeData _workspaceTheme(ThemeData theme, bool desktop) {
  if (!desktop) return theme;
  ButtonStyle desktopStyle(ButtonStyle? style, double horizontal) =>
      (style ?? const ButtonStyle()).copyWith(
        minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: horizontal, vertical: 8),
        ),
        visualDensity: VisualDensity.standard,
        tapTargetSize: MaterialTapTargetSize.padded,
      );
  return theme.copyWith(
    filledButtonTheme: FilledButtonThemeData(
      style: desktopStyle(theme.filledButtonTheme.style, 20),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: desktopStyle(theme.outlinedButtonTheme.style, 18),
    ),
    textButtonTheme: TextButtonThemeData(
      style: desktopStyle(theme.textButtonTheme.style, 14),
    ),
  );
}

/// Keeps the form or card wide while loosening its standalone action.
class _WebAction extends StatelessWidget {
  const _WebAction({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => _usesDesktopActions(context)
      ? Align(
          alignment: AlignmentDirectional.centerStart,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: child,
          ),
        )
      : child;
}

class _WebActionGroup extends StatelessWidget {
  const _WebActionGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => _usesDesktopActions(context)
      ? Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final action in children)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: action,
              ),
          ],
        )
      : Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );
}

class _WebSectionAction extends StatelessWidget {
  const _WebSectionAction({required this.title, required this.action});
  final String title;
  final Widget action;

  @override
  Widget build(BuildContext context) => _usesDesktopActions(context)
      ? Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 8,
            children: [
              _Heading(title),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: action,
              ),
            ],
          ),
        )
      : Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [_Heading(title), const SizedBox(height: 8), action],
        );
}
