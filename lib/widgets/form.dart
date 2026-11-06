import 'package:flutter/material.dart';
import 'ui.dart';

enum F { text, long, number, date, time, times, choice, toggle }

/// One field of an add/edit form.
class Field {
  final String key, label;
  final F type;
  final List<String> options;
  final String hint;
  final bool required;
  const Field(this.key, this.label, {this.type = F.text, this.options = const [], this.hint = '', this.required = false});
}

/// Opens a bottom sheet form. Returns the values, or null when cancelled.
/// When [onDelete] is given, a Delete button is shown.
Future<Map<String, dynamic>?> showForm(BuildContext context, String title, List<Field> fields,
    {Map<String, dynamic>? initial, String save = 'Save', VoidCallback? onDelete}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: C.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
    builder: (_) => _FormSheet(title: title, fields: fields, initial: initial ?? const {}, save: save, onDelete: onDelete),
  );
}

class _FormSheet extends StatefulWidget {
  final String title, save;
  final List<Field> fields;
  final Map<String, dynamic> initial;
  final VoidCallback? onDelete;
  const _FormSheet({required this.title, required this.fields, required this.initial, required this.save, this.onDelete});
  @override
  State<_FormSheet> createState() => _FormSheetState();
}

class _FormSheetState extends State<_FormSheet> {
  final Map<String, dynamic> v = {};
  final Map<String, TextEditingController> ctl = {};
  String? error;

  @override
  void initState() {
    super.initState();
    for (final f in widget.fields) {
      final init = widget.initial[f.key];
      v[f.key] = init;
      if (f.type == F.text || f.type == F.long || f.type == F.number || f.type == F.times) {
        final text = init == null ? '' : (init is List ? init.join(', ') : (init is num ? numText(init) : '$init'));
        ctl[f.key] = TextEditingController(text: text);
      }
      if (f.type == F.choice && init == null && f.options.isNotEmpty) v[f.key] = f.options.first;
      if (f.type == F.toggle && init == null) v[f.key] = false;
    }
  }

  @override
  void dispose() {
    for (final c in ctl.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final out = <String, dynamic>{};
    for (final f in widget.fields) {
      switch (f.type) {
        case F.text:
        case F.long:
          out[f.key] = ctl[f.key]!.text.trim();
        case F.number:
          out[f.key] = num.tryParse(ctl[f.key]!.text.trim().replaceAll(',', ''));
        case F.times:
          out[f.key] = ctl[f.key]!.text
              .split(RegExp(r'[,\s]+'))
              .map((s) => s.trim())
              .where((s) => RegExp(r'^\d{1,2}:\d{2}$').hasMatch(s))
              .map((s) => s.padLeft(5, '0'))
              .toList();
        default:
          out[f.key] = v[f.key];
      }
      final val = out[f.key];
      if (f.required && (val == null || (val is String && val.isEmpty) || (val is List && val.isEmpty))) {
        setState(() => error = '${f.label} is needed.');
        return;
      }
    }
    Navigator.pop(context, out);
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: t(15, c: const Color(0xFF8A8A92)),
        filled: true,
        fillColor: C.chip,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      );

  Widget _field(Field f) {
    switch (f.type) {
      case F.text:
      case F.number:
      case F.times:
        return TextField(
          controller: ctl[f.key],
          style: t(15),
          keyboardType: f.type == F.number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          textCapitalization: f.type == F.text ? TextCapitalization.sentences : TextCapitalization.none,
          decoration: _dec(f.hint.isNotEmpty ? f.hint : (f.type == F.times ? '09:00, 21:00' : '')),
        );
      case F.long:
        return TextField(controller: ctl[f.key], style: t(15, h: 1.45), minLines: 3, maxLines: 8, textCapitalization: TextCapitalization.sentences, decoration: _dec(f.hint));
      case F.date:
        final d = DateTime.tryParse('${v[f.key] ?? ''}');
        return _tapBox(d == null ? (f.hint.isEmpty ? 'Pick a date' : f.hint) : '${d.day} ${monthsLong[d.month - 1]} ${d.year}', Icons.calendar_today_rounded, () async {
          final now = DateTime.now();
          final p = await showDatePicker(context: context, initialDate: d ?? now, firstDate: DateTime(1900), lastDate: DateTime(now.year + 30));
          if (p != null) setState(() => v[f.key] = dayKeyOf(p));
        });
      case F.time:
        final s = '${v[f.key] ?? ''}';
        return _tapBox(s.isEmpty ? 'Pick a time' : s, Icons.schedule_rounded, () async {
          final parts = s.split(':');
          final init = parts.length == 2 ? TimeOfDay(hour: int.tryParse(parts[0]) ?? 9, minute: int.tryParse(parts[1]) ?? 0) : const TimeOfDay(hour: 9, minute: 0);
          final p = await showTimePicker(context: context, initialTime: init);
          if (p != null) setState(() => v[f.key] = '${p.hour.toString().padLeft(2, '0')}:${p.minute.toString().padLeft(2, '0')}');
        });
      case F.choice:
        return Wrap(spacing: 8, runSpacing: 8, children: [
          for (final o in f.options)
            GestureDetector(
              onTap: () => setState(() => v[f.key] = o),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: v[f.key] == o ? C.lime : C.chip,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: v[f.key] == o ? C.ink : C.chip, width: 1.5),
                ),
                child: Text(o, style: t(13, w: w5)),
              ),
            ),
        ]);
      case F.toggle:
        return Row(children: [
          Expanded(child: Text(f.hint.isEmpty ? f.label : f.hint, style: t(14, c: C.muted))),
          Toggle(on: v[f.key] == true, label: f.label, onChanged: (x) => setState(() => v[f.key] = x)),
        ]);
    }
  }

  Widget _tapBox(String text, IconData icon, VoidCallback onTap) => Material(
        color: C.chip,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [Icon(icon, size: 18, color: C.muted), const SizedBox(width: 10), Text(text, style: t(15))]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: const Color(0xFFDAD8DF), borderRadius: BorderRadius.circular(5)))),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: Text(widget.title, style: t(22, w: w6, ls: -0.4))),
              if (widget.onDelete != null)
                SmallPill('Delete', fg: C.warn, onTap: () {
                  Navigator.pop(context);
                  widget.onDelete!();
                }),
            ]),
            const SizedBox(height: 16),
            for (final f in widget.fields) ...[
              if (f.type != F.toggle) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(f.label, style: t(13, w: w5, c: C.muted))),
              _field(f),
              const SizedBox(height: 14),
            ],
            if (error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(error!, style: t(13, c: C.warn))),
            PillButton(widget.save, bg: C.ink, fg: C.white, onTap: _submit),
          ]),
        ),
      ),
    );
  }
}

String dayKeyOf(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
