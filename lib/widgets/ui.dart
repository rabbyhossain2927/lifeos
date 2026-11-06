import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/store.dart';

/// Colours from the design.
class C {
  static const ink = Color(0xFF111111);
  static const lime = Color(0xFFD4F06B);
  static const lime2 = Color(0xFFC5E35A);
  static const limeSoft = Color(0xFFEEF7C9);
  static const limeText = Color(0xFF3A3F1C);
  static const muted = Color(0xFF5F6368);
  static const chip = Color(0xFFF4F2F7);
  static const line = Color(0xFFEDEDE8);
  static const border = Color(0xFFC9C9C2);
  static const off = Color(0xFFE3E1E8);
  static const dark2 = Color(0xFF222222);
  static const dark3 = Color(0xFF2A2A2A);
  static const darkMuted = Color(0xFFB5B5AE);
  static const darkFaint = Color(0xFF9A9A94);
  static const warn = Color(0xFFB4410C);
  static const warnSoft = Color(0xFFFBEDE6);
  static const good = Color(0xFF0B6B50);
  static const white = Colors.white;
}

const bgGradient = LinearGradient(
  begin: Alignment(-0.18, -1),
  end: Alignment(0.18, 1),
  colors: [Color(0xFFF6E8EE), Color(0xFFF1EEF4), Color(0xFFECE9F7)],
  stops: [0, 0.4, 1],
);

TextStyle t(double size, {FontWeight w = FontWeight.w400, Color c = C.ink, double? h, double ls = 0, TextDecoration? deco}) =>
    TextStyle(fontFamily: 'Geist', fontSize: size, fontWeight: w, color: c, height: h, letterSpacing: ls, decoration: deco, decorationColor: c);

const w5 = FontWeight.w500;
const w6 = FontWeight.w600;

/// Shortcut: the Store of the signed-in user.
Store store(BuildContext c, {bool listen = true}) => Provider.of<Store>(c, listen: listen);

// ---------------------------------------------------------------- layout

/// A pushed page: gradient, back button, centered title, scrolling body.
class SubPage extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? trailing;
  final bool closeIcon;
  final EdgeInsets padding;
  const SubPage({super.key, required this.title, required this.children, this.trailing, this.closeIcon = false, this.padding = const EdgeInsets.fromLTRB(20, 4, 20, 40)});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: bgGradient),
        child: SafeArea(
          bottom: false,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(children: [
                RoundBtn(icon: closeIcon ? Icons.close_rounded : Icons.chevron_left_rounded, label: closeIcon ? 'Close' : 'Back', onTap: () => Navigator.of(context).maybePop()),
                Expanded(child: Text(title, textAlign: TextAlign.center, style: t(17, w: w6), maxLines: 1, overflow: TextOverflow.ellipsis)),
                SizedBox(width: 44, child: trailing ?? const SizedBox()),
              ]),
            ),
            Expanded(child: ListView(padding: padding, children: gap(children, 14))),
          ]),
        ),
      ),
    );
  }
}

List<Widget> gap(List<Widget> items, double space) {
  final out = <Widget>[];
  for (var i = 0; i < items.length; i++) {
    if (i > 0) out.add(SizedBox(height: space, width: space));
    out.add(items[i]);
  }
  return out;
}

/// White (or black) rounded card.
class Box extends StatelessWidget {
  final Widget child;
  final bool dark;
  final Color? color;
  final EdgeInsets padding;
  final double radius;
  final VoidCallback? onTap;
  const Box({super.key, required this.child, this.dark = false, this.color, this.padding = const EdgeInsets.all(16), this.radius = 28, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(color: color ?? (dark ? C.ink : C.white), borderRadius: BorderRadius.circular(radius)),
      child: DefaultTextStyle.merge(style: TextStyle(color: dark ? C.white : C.ink, fontFamily: 'Geist'), child: child),
    );
    if (onTap == null) return c;
    return Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(radius), onTap: onTap, child: c));
  }
}

/// Column with a fixed gap between children.
class Col extends StatelessWidget {
  final List<Widget> children;
  final double space;
  final CrossAxisAlignment cross;
  const Col(this.children, {super.key, this.space = 12, this.cross = CrossAxisAlignment.start});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: cross, mainAxisSize: MainAxisSize.min, children: gap(children, space));
}

class H2 extends StatelessWidget {
  final String text;
  final Color color;
  final double size;
  const H2(this.text, {super.key, this.color = C.ink, this.size = 16});
  @override
  Widget build(BuildContext context) => Text(text, style: t(size, w: w6, c: color));
}

/// Card header: title on the left, optional small action on the right.
class CardHead extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final String? note;
  final Color color;
  const CardHead(this.title, {super.key, this.action, this.onAction, this.note, this.color = C.ink});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: H2(title, color: color)),
      if (note != null) Text(note!, style: t(12, c: color == C.ink ? C.muted : C.darkMuted)),
      if (action != null) SmallPill(action!, onTap: onAction),
    ]);
  }
}

// ---------------------------------------------------------------- controls

class RoundBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color bg, fg;
  final double size;
  const RoundBtn({super.key, required this.icon, required this.label, this.onTap, this.bg = C.white, this.fg = C.ink, this.size = 44});
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: bg,
        shape: const CircleBorder(),
        child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: SizedBox(width: size, height: size, child: Icon(icon, size: size * 0.45, color: fg))),
      ),
    );
  }
}

/// Full-width pill button (lime, black or chip).
class PillButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final Color bg, fg;
  final double height;
  final bool expand;
  final IconData? icon;
  const PillButton(this.text, {super.key, this.onTap, this.bg = C.lime, this.fg = C.ink, this.height = 52, this.expand = true, this.icon});
  @override
  Widget build(BuildContext context) {
    final b = Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.center,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 8)],
            Flexible(child: Text(text, style: t(15, w: w6, c: fg), overflow: TextOverflow.ellipsis)),
          ]),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: b) : b;
  }
}

class SmallPill extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final Color bg, fg;
  const SmallPill(this.text, {super.key, this.onTap, this.bg = C.chip, this.fg = C.ink});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          child: Text(text, style: t(12, w: w6, c: fg)),
        ),
      ),
    );
  }
}

/// The black/lime switch from the design.
class Toggle extends StatelessWidget {
  final bool on;
  final ValueChanged<bool> onChanged;
  final String label;
  const Toggle({super.key, required this.on, required this.onChanged, required this.label});
  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: on,
      label: label,
      child: GestureDetector(
        onTap: () => onChanged(!on),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 52,
          height: 32,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: on ? C.ink : C.off, borderRadius: BorderRadius.circular(999)),
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(width: 26, height: 26, decoration: BoxDecoration(shape: BoxShape.circle, color: on ? C.lime : C.white)),
        ),
      ),
    );
  }
}

/// Round tick button (habit/goal rows).
class Tick extends StatelessWidget {
  final bool done;
  final VoidCallback onTap;
  final String label;
  final double size;
  final bool square;
  final bool darkBg;
  const Tick({super.key, required this.done, required this.onTap, required this.label, this.size = 26, this.square = false, this.darkBg = false});
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      checked: done,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 26,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: done ? C.lime2 : Colors.transparent,
                shape: square ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: square ? BorderRadius.circular(7) : null,
                border: done ? null : Border.all(color: darkBg ? const Color(0xFF6E6E68) : C.border, width: 1.5),
              ),
              child: done ? Icon(Icons.check_rounded, size: size * 0.62, color: C.ink) : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// Text with strike-through when done.
Text doneText(String s, bool done, {double size = 15, bool dark = false}) => Text(s,
    style: t(size, c: done ? (dark ? C.darkFaint : C.muted) : (dark ? C.white : C.ink), deco: done ? TextDecoration.lineThrough : null));

/// Horizontal progress bar.
class Bar extends StatelessWidget {
  final double value;
  final double height;
  final Color color, track;
  const Bar(this.value, {super.key, this.height = 8, this.color = C.ink, this.track = C.chip});
  @override
  Widget build(BuildContext context) {
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    return Container(
      height: height,
      decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(height)),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: v,
        child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(height))),
      ),
    );
  }
}

/// Progress ring with text in the middle.
class Ring extends StatelessWidget {
  final double value;
  final double size, stroke;
  final Color color, track;
  final Widget? center;
  const Ring({super.key, required this.value, this.size = 104, this.stroke = 12, this.color = C.lime, this.track = C.dark3, this.center});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(value.isNaN ? 0 : value.clamp(0.0, 1.0), stroke, color, track),
        child: Center(child: center),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double v, stroke;
  final Color color, track;
  _RingPainter(this.v, this.stroke, this.color, this.track);
  @override
  void paint(Canvas canvas, Size size) {
    final r = (size.width - stroke) / 2;
    final c = Offset(size.width / 2, size.height / 2);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r, p..color = track);
    if (v > 0) canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, 2 * math.pi * v, false, p..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.v != v || o.color != color;
}

/// The LifeOS mark: lime ring with the white dot.
class LogoMark extends StatelessWidget {
  final double size;
  final bool tile;
  const LogoMark({super.key, this.size = 64, this.tile = true});
  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size, child: CustomPaint(painter: _MarkPainter(tile)));
}

class _MarkPainter extends CustomPainter {
  final bool tile;
  _MarkPainter(this.tile);
  @override
  void paint(Canvas canvas, Size s) {
    final k = s.width / 1024;
    if (tile) canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(232 * k)), Paint()..color = C.ink);
    final c = Offset(s.width / 2, s.height / 2);
    canvas.drawArc(Rect.fromCircle(center: c, radius: 260 * k), -math.pi / 2, math.pi * 1.5, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 96 * k
          ..strokeCap = StrokeCap.round
          ..color = C.lime);
    canvas.drawCircle(Offset(328 * k, 328 * k), 52 * k, Paint()..color = C.white);
  }

  @override
  bool shouldRepaint(_MarkPainter o) => false;
}

/// One row in a white list card.
class ListRow extends StatelessWidget {
  final String title;
  final String? sub;
  final Widget? leading, trailing;
  final VoidCallback? onTap, onLongPress;
  final bool divider;
  final double minHeight;
  const ListRow({super.key, required this.title, this.sub, this.leading, this.trailing, this.onTap, this.onLongPress, this.divider = true, this.minHeight = 56});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        constraints: BoxConstraints(minHeight: minHeight),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(border: divider ? const Border(bottom: BorderSide(color: C.line)) : null),
        child: Row(children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(title, style: t(15, w: w5)),
              if (sub != null && sub!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(sub!, style: t(12, c: C.muted))),
            ]),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ]),
      ),
    );
  }
}

/// A white card holding rows; the last row has no divider.
class ListCard extends StatelessWidget {
  final String? title;
  final String? action;
  final VoidCallback? onAction;
  final List<ListRow> rows;
  final String empty;
  const ListCard({super.key, this.title, this.action, this.onAction, required this.rows, this.empty = 'Nothing here yet.'});
  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      items.add(i == rows.length - 1
          ? ListRow(title: r.title, sub: r.sub, leading: r.leading, trailing: r.trailing, onTap: r.onTap, onLongPress: r.onLongPress, divider: false, minHeight: r.minHeight)
          : r);
    }
    return Box(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (title != null) Padding(padding: const EdgeInsets.only(bottom: 4), child: CardHead(title!, action: action, onAction: onAction)),
        if (rows.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(empty, style: t(13, c: C.muted))),
        ...items,
      ]),
    );
  }
}

/// Selectable chips in a row/grid (segmented choices).
class ChoiceRow extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onPick;
  final bool dark; // selected = black instead of lime
  final double height;
  final Color unselected;
  const ChoiceRow({super.key, required this.options, required this.selected, required this.onPick, this.dark = false, this.height = 44, this.unselected = C.chip});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: gap([
        for (final o in options)
          Expanded(
            child: Semantics(
              selected: o == selected,
              button: true,
              child: GestureDetector(
                onTap: () => onPick(o),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: height,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: o == selected ? (dark ? C.ink : C.lime) : unselected,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(o, textAlign: TextAlign.center, style: t(12, w: w5, c: o == selected && dark ? C.white : C.ink)),
                ),
              ),
            ),
          ),
      ], 6),
    );
  }
}

/// Segmented control inside a pill (Year / Month / Week / Day).
class Segmented extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onPick;
  final bool dark;
  const Segmented({super.key, required this.options, required this.selected, required this.onPick, this.dark = false});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: dark ? C.dark2 : const Color(0xFFEBEBE6), borderRadius: BorderRadius.circular(dark ? 999 : 14)),
      child: Row(children: [
        for (final o in options)
          Expanded(
            child: GestureDetector(
              onTap: () => onPick(o),
              child: Container(
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: o == selected ? C.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(dark ? 999 : 10),
                  boxShadow: o == selected && !dark ? const [BoxShadow(color: Color(0x14000000), blurRadius: 2, offset: Offset(0, 1))] : null,
                ),
                child: Text(o, style: t(13, w: o == selected ? w6 : w5, c: o == selected ? C.ink : (dark ? C.darkMuted : C.muted))),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Simple vertical bars (week charts).
class Bars extends StatelessWidget {
  final List<double> values; // 0..1, negative = empty slot
  final double height;
  final Color color;
  final Color empty;
  final List<String>? labels;
  final Color labelColor;
  final double radius;
  const Bars({super.key, required this.values, this.height = 64, this.color = C.lime, this.empty = C.dark3, this.labels, this.labelColor = C.darkMuted, this.radius = 8});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SizedBox(
        height: height,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: gap([
          for (final v in values)
            Expanded(
              child: Container(
                height: v < 0 ? 4 : math.max(4, height * v.clamp(0.0, 1.0)),
                decoration: BoxDecoration(color: v < 0 ? empty : color, borderRadius: BorderRadius.circular(radius)),
              ),
            ),
        ], 6)),
      ),
      if (labels != null) ...[
        const SizedBox(height: 8),
        Row(children: gap([for (final l in labels!) Expanded(child: Text(l, textAlign: TextAlign.center, style: t(11, c: labelColor)))], 6)),
      ],
    ]);
  }
}

const weekLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

/// Monday of this week.
DateTime get weekStart {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day).subtract(Duration(days: n.weekday - 1));
}

const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const monthsLong = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const weekdaysLong = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

String niceDate(DateTime d) => '${weekdaysLong[d.weekday - 1]}, ${d.day} ${monthsLong[d.month - 1]}';
String shortDate(DateTime d) => '${d.day} ${months[d.month - 1]}';
String hm(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$h:${d.minute.toString().padLeft(2, '0')}';
}

String hmA(DateTime d) => '${hm(d)} ${d.hour < 12 ? 'AM' : 'PM'}';

String numText(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg, style: t(14, c: C.white)),
    behavior: SnackBarBehavior.floating,
    backgroundColor: C.ink,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ));
}

Future<bool> confirm(BuildContext context, String title, {String ok = 'Delete', String? body}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: C.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(title, style: t(18, w: w6)),
      content: body == null ? null : Text(body, style: t(14, c: C.muted)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Cancel', style: t(14, w: w6, c: C.muted))),
        TextButton(onPressed: () => Navigator.pop(c, true), child: Text(ok, style: t(14, w: w6, c: ok == 'Delete' ? C.warn : C.ink))),
      ],
    ),
  );
  return r == true;
}

Future<T?> push<T>(BuildContext context, Widget page) => Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));
