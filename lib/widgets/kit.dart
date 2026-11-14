import 'package:flutter/material.dart';
import 'motion.dart';
import 'ui.dart';

/// Building blocks of the 26.0 design: hero cards, chip groups, steppers,
/// tick rows, sheets and the tool page layout. All animate and give haptics.

enum HeroTone { dark, lime, white }

class HeroBtn {
  final String text;
  final VoidCallback onTap;
  final bool primary;
  const HeroBtn(this.text, this.onTap, {this.primary = false});
}

/// The big card at the top of a page.
class HeroCard extends StatelessWidget {
  final String label, big;
  final String? sub;
  final double? ring;
  final String? ringText;
  final List<(double, String)>? bars;
  final double? barMax;
  final List<(bool, String)>? dots;
  final List<HeroBtn>? btns;
  final HeroTone tone;
  const HeroCard({super.key, required this.label, required this.big, this.sub, this.ring, this.ringText, this.bars, this.barMax, this.dots, this.btns, this.tone = HeroTone.dark});

  @override
  Widget build(BuildContext context) {
    final dark = tone == HeroTone.dark;
    final bg = switch (tone) { HeroTone.dark => C.ink, HeroTone.lime => C.lime, HeroTone.white => C.white };
    final fg = dark ? C.white : C.ink;
    final soft = dark ? C.darkMuted : C.muted;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(26)),
      child: Col([
        Row(children: [
          Expanded(
            child: Col([
              Text(label, style: t(12, w: w6, c: dark ? C.lime : const Color(0xFF3F3F46))),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (c, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(a), child: c)),
                child: Text(big, key: ValueKey(big), style: t(26, w: w6, c: fg, ls: -0.5, h: 1.15)),
              ),
              if (sub != null && sub!.isNotEmpty) Text(sub!, style: t(13, c: soft, h: 1.35)),
            ], space: 4),
          ),
          if (ring != null) ...[
            const SizedBox(width: 12),
            Ring(
              value: ring!,
              size: 92,
              stroke: 10,
              color: dark ? C.lime : C.ink,
              track: dark ? C.dark3 : (tone == HeroTone.lime ? const Color(0x33111111) : C.chip),
              center: Text(ringText ?? '${(ring! * 100).clamp(0, 999).round()}%', style: t((ringText ?? '').length > 4 ? 16 : 19, w: w6, c: fg)),
            ),
          ],
        ]),
        if (bars != null) MiniBars(values: bars!, max: barMax, dark: dark),
        if (dots != null)
          Row(children: gap([
            for (final d in dots!)
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: d.$1 ? C.lime : (dark ? C.dark3 : C.chip), borderRadius: BorderRadius.circular(999)),
                  child: Text(d.$2, style: t(11, w: FontWeight.w700, c: d.$1 ? C.ink : C.darkFaint)),
                ),
              ),
          ], 8)),
        if (btns != null)
          Row(children: gap([
            for (final b in btns!)
              Expanded(
                child: PressPill(
                  b.text,
                  onTap: b.onTap,
                  bg: b.primary ? C.lime : (dark ? const Color(0xFF262626) : C.white),
                  fg: b.primary ? C.ink : fg,
                  height: 48,
                ),
              ),
          ], 8)),
      ], space: 14),
    );
  }
}

/// Seven bars with day letters; the last (today) is highlighted.
class MiniBars extends StatelessWidget {
  final List<(double, String)> values;
  final double? max;
  final bool dark;
  const MiniBars({super.key, required this.values, this.max, this.dark = true});
  @override
  Widget build(BuildContext context) {
    final m = max ?? values.fold<double>(0.0001, (a, v) => v.$1 > a ? v.$1 : a);
    return SizedBox(
      height: 84,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: gap([
        for (var i = 0; i < values.length; i++)
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: (values[i].$1 / (m <= 0 ? 1 : m)).clamp(0.0, 1.0)),
                duration: Duration(milliseconds: 500 + 60 * i),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => Container(
                  height: 6 + 54 * v,
                  decoration: BoxDecoration(
                    color: i == values.length - 1 ? (dark ? C.lime : C.ink) : (dark ? const Color(0xFF3A3A3A) : const Color(0xFFDAD8DF)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(values[i].$2, style: t(10, c: dark ? C.darkFaint : C.muted)),
            ]),
          ),
      ], 8)),
    );
  }
}

/// White card with a title and a small hint on the right.
class Panel extends StatelessWidget {
  final String? title, hint;
  final Widget child;
  final EdgeInsets padding;
  const Panel({super.key, this.title, this.hint, required this.child, this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 14)});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: Text(title!, style: t(15, w: w6))),
              if (hint != null) Text(hint!, style: t(12, c: C.muted)),
            ]),
          ),
        child,
      ]),
    );
  }
}

/// A pill button that shrinks when pressed.
class PressPill extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final Color bg, fg;
  final double height;
  final IconData? icon;
  final bool success;
  const PressPill(this.text, {super.key, this.onTap, this.bg = C.ink, this.fg = C.white, this.height = 56, this.icon, this.success = false});
  @override
  Widget build(BuildContext context) {
    return Press(
      onTap: onTap,
      label: text,
      haptic: success ? Haptic.success : Haptic.tap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 8)],
          Flexible(child: Text(text, style: t(height >= 54 ? 16 : 14, w: w6, c: fg), overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }
}

/// One chip. [on] = lime with a black border. [add] = "+ name" outline.
class Chip2 extends StatelessWidget {
  final String text;
  final bool on, add;
  final VoidCallback onTap;
  final Color off;
  const Chip2(this.text, {super.key, this.on = false, this.add = false, required this.onTap, this.off = C.chip});
  @override
  Widget build(BuildContext context) {
    return Press(
      onTap: onTap,
      label: text,
      selected: on,
      haptic: add ? Haptic.success : Haptic.select,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: add ? C.white : (on ? C.lime : off),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: add ? C.border : (on ? C.ink : off), width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(add ? '+ $text' : text, style: t(14, w: w5)),
        ]),
      ),
    );
  }
}

/// Wrapping group of chips.
class Chips extends StatelessWidget {
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onTap;
  final bool add;
  final Color off;
  const Chips({super.key, required this.options, this.selected = const {}, required this.onTap, this.add = false, this.off = C.chip});
  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final o in options) Chip2(o, on: selected.contains(o), add: add, off: off, onTap: () => onTap(o)),
      ]);
}

/// − value + inside a soft pill.
class Stepper2 extends StatelessWidget {
  final String value;
  final String unit;
  final VoidCallback onMinus, onPlus;
  final double size;
  final Color bg;
  const Stepper2({super.key, required this.value, this.unit = '', required this.onMinus, required this.onPlus, this.size = 24, this.bg = C.chip});
  @override
  Widget build(BuildContext context) {
    Widget btn(String s, VoidCallback f, Color c, String label) => Press(
          onTap: f,
          label: label,
          haptic: Haptic.select,
          scale: 0.88,
          child: Container(width: 48, height: 48, alignment: Alignment.center, decoration: BoxDecoration(color: c, shape: BoxShape.circle), child: Text(s, style: t(22))),
        );
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(children: [
        btn('−', onMinus, C.white, 'Less'),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            transitionBuilder: (c, a) => ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(a), child: FadeTransition(opacity: a, child: c)),
            child: Text.rich(
              key: ValueKey(value),
              TextSpan(children: [
                TextSpan(text: value, style: t(size, w: w6)),
                if (unit.isNotEmpty) TextSpan(text: '  $unit', style: t(13, w: w5, c: C.muted)),
              ]),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        btn('+', onPlus, C.lime, 'More'),
      ]),
    );
  }
}

/// Row with an optional round tick, a sub line, and a right side.
class Row2 extends StatelessWidget {
  final String title;
  final String? sub, right;
  final bool? done;
  final VoidCallback? onTick, onTap, onLongPress;
  final Widget? trailing, leading;
  final bool divider;
  final double? progress;
  const Row2({super.key, required this.title, this.sub, this.right, this.done, this.onTick, this.onTap, this.onLongPress, this.trailing, this.leading, this.divider = true, this.progress});
  @override
  Widget build(BuildContext context) {
    final struck = done == true && onTick != null;
    final row = Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: EdgeInsets.only(top: 8, bottom: progress != null ? 4 : 8),
      decoration: BoxDecoration(border: divider ? const Border(bottom: BorderSide(color: C.line)) : null),
      child: Column(children: [
        Row(children: [
          if (onTick != null) ...[TickCircle(done: done == true, onTap: onTick!, label: title), const SizedBox(width: 12)],
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: t(15, w: w5, c: struck ? const Color(0xFF8A8A84) : C.ink, deco: struck ? TextDecoration.lineThrough : null),
                child: Text(title),
              ),
              if (sub != null && sub!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(sub!, style: t(12, c: C.muted))),
            ]),
          ),
          if (right != null) Text(right!, style: t(13, w: w6, c: const Color(0xFF3F3F46))),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ]),
        if (progress != null) Padding(padding: const EdgeInsets.only(top: 8, bottom: 6), child: Bar(progress!, height: 6)),
      ]),
    );
    if (onTap == null && onLongPress == null) return row;
    return Press(onTap: onTap, onLongPress: onLongPress, scale: 0.98, child: row);
  }
}

/// Rows in a white panel; the last one has no divider.
class RowsPanel extends StatelessWidget {
  final String? title, hint;
  final List<Row2> rows;
  final String empty;
  const RowsPanel({super.key, this.title, this.hint, required this.rows, this.empty = 'Nothing here yet.'});
  @override
  Widget build(BuildContext context) {
    return Panel(
      title: title,
      hint: hint,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: rows.isEmpty
          ? Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(empty, style: t(13, c: C.muted)))
          : Column(children: [
              for (var i = 0; i < rows.length; i++)
                i == rows.length - 1
                    ? Row2(
                        title: rows[i].title,
                        sub: rows[i].sub,
                        right: rows[i].right,
                        done: rows[i].done,
                        onTick: rows[i].onTick,
                        onTap: rows[i].onTap,
                        onLongPress: rows[i].onLongPress,
                        trailing: rows[i].trailing,
                        leading: rows[i].leading,
                        progress: rows[i].progress,
                        divider: false,
                      )
                    : rows[i],
            ]),
    );
  }
}

/// Round tick with a pop.
class TickCircle extends StatelessWidget {
  final bool done;
  final VoidCallback onTap;
  final String label;
  final double size;
  const TickCircle({super.key, required this.done, required this.onTap, required this.label, this.size = 34});
  @override
  Widget build(BuildContext context) {
    return Press(
      onTap: onTap,
      label: 'Done: $label',
      selected: done,
      scale: 0.85,
      haptic: done ? Haptic.tap : Haptic.success,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutBack,
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: done ? C.lime : C.white,
          shape: BoxShape.circle,
          border: done ? null : Border.all(color: C.border, width: 1.5),
        ),
        child: AnimatedScale(
          scale: done ? 1 : 0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutBack,
          child: Icon(Icons.check_rounded, size: size * 0.5, color: C.ink),
        ),
      ),
    );
  }
}

/// Lime note card (prompts, tips).
class NoteCard extends StatelessWidget {
  final String title, text;
  const NoteCard(this.title, this.text, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: C.lime, borderRadius: BorderRadius.circular(24)),
        child: Col([Text(title, style: t(12, w: w6)), Text(text, style: t(16, w: w6, h: 1.35))], space: 6),
      );
}

/// Soft text box.
class SoftField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int lines;
  final ValueChanged<String>? onChanged;
  final bool pill;
  const SoftField({super.key, required this.controller, required this.hint, this.lines = 3, this.onChanged, this.pill = false});
  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        onChanged: onChanged,
        minLines: pill ? 1 : lines,
        maxLines: pill ? 1 : lines + 3,
        style: t(15, h: 1.45, w: pill ? w5 : FontWeight.w400),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: t(15, c: const Color(0xFF8A8A84)),
          filled: true,
          fillColor: C.chip,
          contentPadding: EdgeInsets.symmetric(horizontal: pill ? 20 : 16, vertical: pill ? 16 : 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(pill ? 999 : 18), borderSide: BorderSide.none),
        ),
      );
}

/// Bottom sheet with the drag handle and a title.
Future<T?> showSheet<T>(BuildContext context, String title, Widget Function(BuildContext c, StateSetter set) body) {
  Haptic.tap();
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: C.white,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
    builder: (c) => StatefulBuilder(
      builder: (c, set) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
        child: SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.85),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(title, style: t(22, w: w6, ls: -0.4)),
                const SizedBox(height: 14),
                ...stagger([body(c, set)]),
              ]),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Area tag colours used by goals and explore.
const areaColors = <String, (Color, Color)>{
  'Learn': (Color(0xFFEFEDFF), Color(0xFF4A3FB0)),
  'Health': (Color(0xFFE5F4E4), Color(0xFF1F6B2A)),
  'Faith': (Color(0xFFEEF7C9), Color(0xFF4D5A10)),
  'Work': (Color(0xFFE7F1FB), Color(0xFF1F4F86)),
  'Family': (Color(0xFFFBEBEB), Color(0xFFA33A3A)),
  'Money': (Color(0xFFF9EEDA), Color(0xFF7A5212)),
  'Self': (Color(0xFFF4F2F7), Color(0xFF4A4A52)),
};

class Tag extends StatelessWidget {
  final String text;
  final Color bg, fg;
  const Tag(this.text, {super.key, this.bg = C.chip, this.fg = const Color(0xFF4A4A52)});
  factory Tag.area(String a) {
    final c = areaColors[a] ?? (C.chip, const Color(0xFF4A4A52));
    return Tag(a, bg: c.$1, fg: c.$2);
  }
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: t(11, w: w6, c: fg)),
      );
}

/// Round white back button.
class BackBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  const BackBtn({super.key, this.icon = Icons.chevron_left_rounded, this.label = 'Back'});
  @override
  Widget build(BuildContext context) => Press(
        onTap: () => Navigator.of(context).maybePop(),
        label: label,
        scale: 0.9,
        child: Container(width: 46, height: 46, decoration: const BoxDecoration(color: C.white, shape: BoxShape.circle), child: Icon(icon, size: 22)),
      );
}

/// Layout of every tool page: back, coloured icon, title and subtitle,
/// then the blocks, each sliding in.
class ToolPage extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final (Color, Color) colors;
  final List<Widget> children;
  final Widget? trailing;
  const ToolPage({super.key, required this.title, required this.subtitle, required this.icon, required this.colors, required this.children, this.trailing});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: bgGradient),
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 48),
            children: gap(stagger([
              Row(children: [
                const BackBtn(),
                const SizedBox(width: 12),
                Hero(
                  tag: 'tool-$title',
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(color: colors.$1, borderRadius: BorderRadius.circular(16)),
                    child: Icon(icon, size: 22, color: colors.$2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: t(22, w: w6, ls: -0.4)),
                    Text(subtitle, style: t(13, c: C.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ),
                if (trailing != null) trailing!,
              ]),
              ...children,
            ]), 12),
          ),
        ),
      ),
    );
  }
}

/// Main tab title block (22px, one line) with an optional right widget.
class TabTitle extends StatelessWidget {
  final String title;
  final String? sub;
  final Widget? trailing;
  const TabTitle(this.title, {super.key, this.sub, this.trailing});
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: t(22, w: w6, ls: -0.4), maxLines: 1, overflow: TextOverflow.ellipsis),
            if (sub != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(sub!, style: t(13, c: C.muted))),
          ]),
        ),
        if (trailing != null) trailing!,
      ]);
}

/// Small white pill button used in headers ("Review", "Edit Home").
class HeadPill extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final bool dark;
  const HeadPill(this.text, {super.key, required this.onTap, this.dark = false});
  @override
  Widget build(BuildContext context) => Press(
        onTap: onTap,
        label: text,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: dark ? C.ink : C.white, borderRadius: BorderRadius.circular(999)),
          child: Text(text, style: t(13, w: w6, c: dark ? C.white : C.ink)),
        ),
      );
}

/// Snack-style toast at the top, with a matching haptic.
void say(BuildContext context, String msg, {bool good = true}) {
  good ? Haptic.success() : Haptic.warn();
  toast(context, msg);
}
