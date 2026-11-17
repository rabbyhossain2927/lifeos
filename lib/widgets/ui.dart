import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/local.dart';
import '../services/store.dart';
import 'motion.dart';

/// The look: colour theme, light or dark, paper texture, text size.
/// Saved on this phone (Local) so it shows before data loads.
class Look {
  static final rev = ValueNotifier<int>(0);
  static const themes = <String, (Color, Color, Color)>{
    // swatch, top of background, bottom of background
    'Lavender': (Color(0xFFC7B8FF), Color(0xFFF6E8EE), Color(0xFFECE9F7)),
    'Mint': (Color(0xFFA8E6CF), Color(0xFFEAF6EF), Color(0xFFDFF1EA)),
    'Peach': (Color(0xFFFFC9A8), Color(0xFFFBEEE5), Color(0xFFF6E2E7)),
    'Sky': (Color(0xFF9FD3F2), Color(0xFFE8F3FA), Color(0xFFE4E7F6)),
    'Sand': (Color(0xFFE8D5B5), Color(0xFFF6F0E6), Color(0xFFEEE7DB)),
    'Rose': (Color(0xFFF4B6C8), Color(0xFFFBE9EF), Color(0xFFF2E5F1)),
    'Lime': (Color(0xFFD4F06B), Color(0xFFF3F7E3), Color(0xFFE9EFDB)),
    'Mono': (Color(0xFFD9D9DE), Color(0xFFF5F5F7), Color(0xFFEAEAEE)),
  };
  static String get theme => themes.containsKey(Local.sp.getString('theme')) ? Local.sp.getString('theme')! : 'Lavender';
  static String get mode => Local.sp.getString('mode') ?? 'Light'; // Light, Dark, Auto
  static bool get texture => Local.sp.getBool('texture') ?? true;
  static String get textSize => Local.sp.getString('text_size') ?? 'Normal';
  static double get scale => switch (textSize) { 'Small' => 0.88, 'Large' => 1.04, _ => 0.94 };
  static bool dark = false;

  /// Picks the palette; call before building the app.
  static void apply(Brightness platform) {
    dark = mode == 'Dark' || (mode == 'Auto' && platform == Brightness.dark);
    C.p = dark ? Pal.dark : Pal.light;
  }

  static Future<void> set(String key, Object v) async {
    if (v is bool) {
      await Local.sp.setBool(key, v);
    } else {
      await Local.sp.setString(key, '$v');
    }
    rev.value++;
  }
}

class Pal {
  final Color ink;
  final Color white;
  final Color chip;
  final Color line;
  final Color border;
  final Color off;
  final Color muted;
  final Color dark2;
  final Color dark3;
  final Color darkMuted;
  final Color darkFaint;
  final Color limeSoft;
  final Color limeText;
  final Color warnSoft;
  const Pal(this.ink, this.white, this.chip, this.line, this.border, this.off, this.muted, this.dark2, this.dark3, this.darkMuted, this.darkFaint, this.limeSoft, this.limeText, this.warnSoft);
  static const light = Pal(Color(0xFF1F1F23), Colors.white, Color(0xFFF4F2F7), Color(0xFFEFEEF2), Color(0xFFC9C9C2), Color(0xFFE3E1E8), Color(0xFF6B6B73), Color(0xFF2A2A30),
      Color(0xFF34343A), Color(0xFFB9B9C0), Color(0xFF8E8E96), Color(0xFFEEF7C9), Color(0xFF3A3F1C), Color(0xFFFBEDE6));
  // In dark mode the roles swap: cards go dark, "ink" (text and strong cards) goes light.
  static const dark = Pal(Color(0xFFECECEF), Color(0xFF1E1E23), Color(0xFF2A2A31), Color(0xFF2E2E35), Color(0xFF4A4A52), Color(0xFF33333A), Color(0xFFA0A0A8), Color(0xFFDADADF),
      Color(0xFFD3D3D9), Color(0xFF55555C), Color(0xFF6B6B73), Color(0xFF2F3A12), Color(0xFFD9EFA0), Color(0xFF3A2218));
}

/// Colours from the design. Most follow the light/dark palette.
class C {
  static Pal p = Pal.light;
  static Color get ink => p.ink;
  static Color get white => p.white;
  static Color get chip => p.chip;
  static Color get line => p.line;
  static Color get border => p.border;
  static Color get off => p.off;
  static Color get muted => p.muted;
  static Color get dark2 => p.dark2;
  static Color get dark3 => p.dark3;
  static Color get darkMuted => p.darkMuted;
  static Color get darkFaint => p.darkFaint;
  static Color get limeSoft => p.limeSoft;
  static Color get limeText => p.limeText;
  static Color get warnSoft => p.warnSoft;
  static const lime = Color(0xFFD4F06B);
  /// Lime text on an "ink" card (that card turns light in dark mode).
  static Color get accentOnInk => Look.dark ? const Color(0xFF5A6B12) : lime;
  static const lime2 = Color(0xFFC5E35A);
  static const onLime = Color(0xFF1F1F23); // text on lime stays dark in both modes
  static const warn = Color(0xFFB4410C);
  static const good = Color(0xFF0B6B50);
}

LinearGradient get bgGradient {
  final th = Look.themes[Look.theme]!;
  return LinearGradient(
    begin: const Alignment(-0.18, -1),
    end: const Alignment(0.18, 1),
    colors: Look.dark ? const [Color(0xFF1A1A1F), Color(0xFF141417), Color(0xFF111114)] : [th.$2, Color.lerp(th.$2, th.$3, 0.45)!, th.$3],
    stops: const [0, 0.4, 1],
  );
}

final _dots = MemoryImage(base64Decode('iVBORw0KGgoAAAANSUhEUgAAABwAAAAcCAYAAAByDd+UAAAAK0lEQVR42mNgGGmABYrpZtljKGYZlhbSPUhHwSgYBaNgFIyCUTAKRsFgBQCCIwOt/c/ojgAAAABJRU5ErkJggg=='));

/// Page background: theme gradient plus the soft paper dots.
BoxDecoration get bgDecoration => BoxDecoration(
      gradient: bgGradient,
      image: Look.texture
          ? DecorationImage(image: _dots, repeat: ImageRepeat.repeat, scale: 2, opacity: Look.dark ? 0.0 : 0.06, colorFilter: null)
          : null,
    );

TextStyle t(double size, {FontWeight w = FontWeight.w400, Color? c, double? h, double ls = 0, TextDecoration? deco}) =>
    TextStyle(fontFamily: 'Geist', fontSize: size, fontWeight: w, color: c ?? C.ink, height: h, letterSpacing: ls, decoration: deco, decorationColor: c ?? C.ink);

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
        decoration: bgDecoration,
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
  final Color? _color;
  Color get color => _color ?? C.ink;
  final double size;
  const H2(this.text, {super.key, Color? color, this.size = 16}) : _color = color;
  @override
  Widget build(BuildContext context) => Text(text, style: t(size, w: w6, c: color));
}

/// Card header: title on the left, optional small action on the right.
class CardHead extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final String? note;
  final Color? _color;
  Color get color => _color ?? C.ink;
  const CardHead(this.title, {super.key, this.action, this.onAction, this.note, Color? color}) : _color = color;
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
  final Color? _bg;
  Color get bg => _bg ?? C.white;
  final Color? _fg;
  Color get fg => _fg ?? C.ink;
  final double size;
  const RoundBtn({super.key, required this.icon, required this.label, this.onTap, Color? bg, Color? fg, this.size = 44}) : _bg = bg, _fg = fg;
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
  final Color? _bg;
  Color get bg => _bg ?? C.lime;
  final Color? _fg;
  Color get fg => _fg ?? C.ink;
  final double height;
  final bool expand;
  final IconData? icon;
  const PillButton(this.text, {super.key, this.onTap, Color? bg, Color? fg, this.height = 52, this.expand = true, this.icon}) : _bg = bg, _fg = fg;
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
  final Color? _bg;
  Color get bg => _bg ?? C.chip;
  final Color? _fg;
  Color get fg => _fg ?? C.ink;
  const SmallPill(this.text, {super.key, this.onTap, Color? bg, Color? fg}) : _bg = bg, _fg = fg;
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
        onTap: () {
          Haptic.select();
          onChanged(!on);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
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
        onTap: () {
          done ? Haptic.tap() : Haptic.success();
          onTap();
        },
        radius: 26,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: done ? C.lime : Colors.transparent,
                shape: square ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: square ? BorderRadius.circular(7) : null,
                border: done ? null : Border.all(color: darkBg ? const Color(0xFF6E6E68) : C.border, width: 1.5),
              ),
              child: AnimatedScale(
                scale: done ? 1 : 0,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                child: Icon(Icons.check_rounded, size: size * 0.62, color: C.ink),
              ),
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
  final Color? _color;
  Color get color => _color ?? C.ink;
  final Color? _track;
  Color get track => _track ?? C.chip;
  const Bar(this.value, {super.key, this.height = 8, Color? color, Color? track}) : _color = color, _track = track;
  @override
  Widget build(BuildContext context) {
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    return Container(
      height: height,
      decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(height)),
      alignment: Alignment.centerLeft,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: v),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (_, x, __) => FractionallySizedBox(
          widthFactor: x,
          child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(height))),
        ),
      ),
    );
  }
}

/// Progress ring with text in the middle.
class Ring extends StatelessWidget {
  final double value;
  final double size, stroke;
  final Color? _color;
  Color get color => _color ?? C.lime;
  final Color? _track;
  Color get track => _track ?? C.dark3;
  final Widget? center;
  const Ring({super.key, required this.value, this.size = 104, this.stroke = 12, Color? color, Color? track, this.center}) : _color = color, _track = track;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value.isNaN ? 0 : value.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (_, v, child) => CustomPaint(painter: _RingPainter(v, stroke, color, track), child: child),
        child: Center(child: center),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double v, stroke;
  final Color color;
  final Color track;
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
        decoration: BoxDecoration(border: divider ? Border(bottom: BorderSide(color: C.line)) : null),
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
  final Color? _unselected;
  Color get unselected => _unselected ?? C.chip;
  const ChoiceRow({super.key, required this.options, required this.selected, required this.onPick, this.dark = false, this.height = 44, Color? unselected}) : _unselected = unselected;
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
                onTap: () {
                  Haptic.select();
                  onPick(o);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
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
              onTap: () {
                Haptic.select();
                onPick(o);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
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
  final Color? _color;
  Color get color => _color ?? C.lime;
  final Color? _empty;
  Color get empty => _empty ?? C.dark3;
  final List<String>? labels;
  final Color? _labelColor;
  Color get labelColor => _labelColor ?? C.darkMuted;
  final double radius;
  const Bars({super.key, required this.values, this.height = 64, Color? color, Color? empty, this.labels, Color? labelColor, this.radius = 8}) : _color = color, _empty = empty, _labelColor = labelColor;
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SizedBox(
        height: height,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: gap([
          for (final v in values)
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
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

/// First day of this week (Saturday by default; Preferences can change it).
DateTime get weekStart {
  final n = DateTime.now();
  final first = Local.weekStartDay; // DateTime.saturday / sunday / monday
  final back = (n.weekday - first + 7) % 7;
  return DateTime(n.year, n.month, n.day).subtract(Duration(days: back));
}

const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const monthsLong = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const weekdaysLong = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

String niceDate(DateTime d) => '${weekdaysLong[d.weekday - 1]}, ${d.day} ${monthsLong[d.month - 1]}';
String shortDate(DateTime d) => '${d.day} ${months[d.month - 1]}';
String hm(DateTime d) {
  if (Local.time24) return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$h:${d.minute.toString().padLeft(2, '0')}';
}

String hmA(DateTime d) => Local.time24 ? hm(d) : '${hm(d)} ${d.hour < 12 ? 'AM' : 'PM'}';

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

Future<T?> push<T>(BuildContext context, Widget page) => Navigator.of(context).push<T>(SlideRoute<T>(page));
