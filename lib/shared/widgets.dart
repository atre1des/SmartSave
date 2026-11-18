import 'package:flutter/material.dart';

import 'theme.dart';

String formatTenge(int amount) {
  final digits = amount.abs().toString();
  final grouped = digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ' ');
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
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (trailing != null)
            TextButton(onPressed: onTrailing, child: Text(trailing!, style: const TextStyle(color: AppColors.prussianBlue, fontSize: 12, fontWeight: FontWeight.w600))),
        ],
      );
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color = Colors.white, this.onTap});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(color: color, border: color == Colors.white ? Border.all(color: AppColors.border) : null, borderRadius: BorderRadius.circular(16)),
      child: child,
    );
    return onTap == null ? content : Material(color: Colors.transparent, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: content));
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.icon});
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
          style: FilledButton.styleFrom(backgroundColor: AppColors.firefly, foregroundColor: Colors.white, shape: const StadiumBorder()),
        ),
      );
}

class Pill extends StatelessWidget {
  const Pill({super.key, required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.firefly),
        backgroundColor: Colors.white,
        selectedColor: AppColors.firefly,
        side: BorderSide(color: selected ? AppColors.firefly : AppColors.border),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      );
}

class ProgressTrack extends StatelessWidget {
  const ProgressTrack({super.key, required this.value, this.height = 10, this.color = AppColors.mint});
  final double value;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: LinearProgressIndicator(value: value.clamp(0, 1), minHeight: height, backgroundColor: AppColors.mintLight, color: color),
      );
}

class LabeledValue extends StatelessWidget {
  const LabeledValue({super.key, required this.label, required this.value, this.trailing});
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: Theme.of(context).textTheme.bodySmall), const SizedBox(height: 4), Text(value, style: Theme.of(context).textTheme.titleMedium)])), ?trailing]),
      );
}

class PrimaryAction extends StatelessWidget {
  const PrimaryAction({super.key, required this.label, required this.onPressed, this.busy = false});
  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 52,
        child: FilledButton(
          onPressed: busy ? null : onPressed,
          style: FilledButton.styleFrom(backgroundColor: AppColors.firefly, foregroundColor: Colors.white, shape: const StadiumBorder()),
          child: busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      );
}

class SecondaryAction extends StatelessWidget {
  const SecondaryAction({super.key, required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 52,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.firefly, side: const BorderSide(color: AppColors.firefly, width: 1.5), shape: const StadiumBorder()),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      );
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
