import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../shared/theme.dart';
import '../../l10n/app_locale.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({
    super.key,
    required this.children,
    this.back = false,
    this.footer,
    this.centered = false,
  });

  final List<Widget> children;
  final bool back;
  final Widget? footer;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.isDark ? colors.canvas : colors.surface,
      body: SafeArea(
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(26, 12, 26, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (back)
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: IconButton(
                              tooltip: MaterialLocalizations.of(
                                context,
                              ).backButtonTooltip,
                              style: IconButton.styleFrom(
                                backgroundColor: _authFieldSurface(context),
                                foregroundColor: colors.text,
                                minimumSize: const Size(44, 44),
                              ),
                              onPressed: () => Navigator.maybePop(context),
                              icon: const BackButtonIcon(),
                            ),
                          ),
                        if (centered) const Spacer(),
                        ...children,
                        if (footer case final content?) ...[
                          const SizedBox(height: 16),
                          const Spacer(),
                          content,
                        ] else if (centered)
                          const Spacer(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthHeading extends StatelessWidget {
  const AuthHeading({
    super.key,
    required this.title,
    required this.subtitle,
    this.hero = false,
  });

  final String title;
  final String subtitle;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        Container(
          width: hero ? 104 : 56,
          height: hero ? 104 : 56,
          padding: EdgeInsets.all(hero ? 23 : 13),
          decoration: BoxDecoration(
            color: colors.accentSurface(colors.highlight),
            borderRadius: BorderRadius.circular(hero ? 31 : 19),
          ),
          child: SvgPicture.asset(
            'assets/figma/auth-logo.svg',
            excludeFromSemantics: true,
            colorFilter: ColorFilter.mode(
              colors.isDark ? colors.action : colors.text,
              BlendMode.srcIn,
            ),
          ),
        ),
        SizedBox(height: hero ? 21 : 13),
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.isDark ? colors.text : colors.onPremium,
              fontSize: hero ? 42 : 25,
              height: 1.13,
              letterSpacing: hero ? -1.9 : -.6,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colors.muted),
        ),
      ],
    );
  }
}

Color _authFieldSurface(BuildContext context) {
  final colors = context.colors;
  return colors.isDark
      ? colors.groupedSurface
      : Color.lerp(colors.surface, colors.onPremium, .065)!;
}

class AuthInput extends StatefulWidget {
  const AuthInput({
    super.key,
    required this.label,
    required this.controller,
    required this.validator,
    this.hint,
    this.email = false,
    this.secret = false,
    this.autofillHints,
    this.last = false,
  });

  final String label;
  final TextEditingController controller;
  final String? Function(String?) validator;
  final String? hint;
  final bool email;
  final bool secret;
  final Iterable<String>? autofillHints;
  final bool last;

  @override
  State<AuthInput> createState() => _AuthInputState();
}

class _AuthInputState extends State<AuthInput> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(22),
      borderSide: BorderSide.none,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Text(widget.label, style: theme.textTheme.titleMedium),
        ),
        const SizedBox(height: 7),
        Semantics(
          label: widget.label,
          child: TextFormField(
            controller: widget.controller,
            validator: widget.validator,
            keyboardType: widget.email ? TextInputType.emailAddress : null,
            textInputAction: widget.last
                ? TextInputAction.done
                : TextInputAction.next,
            autofillHints: widget.autofillHints,
            autocorrect: !widget.email && !widget.secret,
            enableSuggestions: !widget.email && !widget.secret,
            obscureText: widget.secret && !_revealed,
            decoration: InputDecoration(
              hintText: widget.hint,
              fillColor: _authFieldSurface(context),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 15,
              ),
              border: border,
              enabledBorder: border,
              focusedBorder: border.copyWith(
                borderSide: BorderSide(color: colors.action, width: 2),
              ),
              errorBorder: border.copyWith(
                borderSide: BorderSide(color: colors.error),
              ),
              focusedErrorBorder: border.copyWith(
                borderSide: BorderSide(color: colors.error, width: 2),
              ),
              suffixIcon: widget.secret
                  ? IconButton(
                      tooltip: _revealed
                          ? context.l10n.authHidePassword
                          : context.l10n.authShowPassword,
                      onPressed: () => setState(() => _revealed = !_revealed),
                      icon: Icon(
                        _revealed
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 19,
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

class AuthButton extends StatelessWidget {
  const AuthButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.secondary = false,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool secondary;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ink = secondary
        ? colors.text
        : colors.isDark
        ? colors.onPremium
        : colors.onEmphasis;
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: secondary
            ? _authFieldSurface(context)
            : colors.isDark
            ? colors.text
            : colors.onPremium,
        foregroundColor: ink,
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        shape: const StadiumBorder(),
      ),
      onPressed: busy ? null : onPressed,
      child: busy
          ? SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                color: colors.action,
                strokeWidth: 2,
              ),
            )
          : Text(label, textAlign: TextAlign.center),
    );
  }
}
