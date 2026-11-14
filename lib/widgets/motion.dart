import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/local.dart';

/// Haptics with a few distinct feels. Turn off in Account > Preferences.
class Haptic {
  static bool get _on => Local.haptics;

  /// Chips, tabs, small picks.
  static void select() {
    if (_on) HapticFeedback.selectionClick();
  }

  /// Buttons and rows.
  static void tap() {
    if (_on) HapticFeedback.lightImpact();
  }

  /// Something got done (tick, save, goal step): a soft double pulse.
  static void success() {
    if (!_on) return;
    HapticFeedback.mediumImpact();
    Timer(const Duration(milliseconds: 90), HapticFeedback.lightImpact);
  }

  /// Something big (goal reached, level up): three pulses.
  static void celebrate() {
    if (!_on) return;
    HapticFeedback.heavyImpact();
    Timer(const Duration(milliseconds: 110), HapticFeedback.mediumImpact);
    Timer(const Duration(milliseconds: 220), HapticFeedback.lightImpact);
  }

  /// Error or "not allowed".
  static void warn() {
    if (_on) HapticFeedback.heavyImpact();
  }
}

/// Fades and slides its child in once, after [index] * 45 ms (stagger lists).
class Appear extends StatefulWidget {
  final Widget child;
  final int index;
  final double dy;
  const Appear({super.key, required this.child, this.index = 0, this.dy = 18});
  @override
  State<Appear> createState() => _AppearState();
}

class _AppearState extends State<Appear> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final Animation<double> a = CurvedAnimation(parent: c, curve: Curves.easeOutCubic);
  Timer? _t;

  @override
  void initState() {
    super.initState();
    final delay = Duration(milliseconds: 45 * widget.index.clamp(0, 12));
    _t = Timer(delay, () {
      if (mounted) c.forward();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: a,
        child: widget.child,
        builder: (_, child) => Opacity(
          opacity: a.value,
          child: Transform.translate(offset: Offset(0, widget.dy * (1 - a.value)), child: child),
        ),
      );
}

/// Wraps each child in [Appear] with a growing delay.
List<Widget> stagger(List<Widget> items) => [for (var i = 0; i < items.length; i++) Appear(index: i, child: items[i])];

/// Tap target that shrinks a little while pressed, with haptics.
class Press extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final String? label;
  final bool selected;
  final void Function()? haptic;
  const Press({super.key, required this.child, this.onTap, this.onLongPress, this.scale = 0.95, this.label, this.selected = false, this.haptic});
  @override
  State<Press> createState() => _PressState();
}

class _PressState extends State<Press> {
  bool down = false;
  void _set(bool v) {
    if (widget.onTap != null && down != v) setState(() => down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: widget.onTap != null,
      label: widget.label,
      selected: widget.selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap == null
            ? null
            : () {
                (widget.haptic ?? Haptic.tap)();
                widget.onTap!();
              },
        onLongPress: widget.onLongPress == null
            ? null
            : () {
                Haptic.success();
                widget.onLongPress!();
              },
        child: AnimatedScale(
          scale: down ? widget.scale : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

/// A number that counts up or down to its new value.
class CountText extends StatelessWidget {
  final num value;
  final TextStyle style;
  final String Function(num v)? format;
  const CountText(this.value, {super.key, required this.style, this.format});
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.toDouble()),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text(format != null ? format!(v) : v.round().toString(), style: style),
    );
  }
}

/// Pages slide in from the right with a fade.
class SlideRoute<T> extends PageRouteBuilder<T> {
  SlideRoute(Widget page)
      : super(
          transitionDuration: const Duration(milliseconds: 340),
          reverseTransitionDuration: const Duration(milliseconds: 260),
          pageBuilder: (_, __, ___) => page,
          transitionsBuilder: (_, a, __, child) {
            final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
            return FadeTransition(
              opacity: c,
              child: SlideTransition(position: Tween(begin: const Offset(0.08, 0), end: Offset.zero).animate(c), child: child),
            );
          },
        );
}
