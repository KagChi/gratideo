import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/db.dart';
import '../data/models.dart';
import '../theme/gratideo_theme.dart';
import '../services/sync.dart';
import '../widgets/common.dart';
import '../widgets/skeleton.dart';

/// Free-form entries plus every Selah note, newest first, searchable.
class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});
  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  List<Entry> _all = [];
  bool _loading = true;
  String _q = '';
  final _draft = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _reload();
    final changed = await (SyncService.instance?.sync() ?? Future.value(false));
    if (changed) await _reload();
  }

  Future<void> _reload() async {
    final e = await Db.instance.entries();
    if (mounted) setState(() {
      _all = e;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_draft.text.trim().isEmpty) return;
    if (!await ensureCanWrite(context)) return;
    await Db.instance.addEntry(EntryKind.journal, _draft.text);
    _draft.clear();
    FocusManager.instance.primaryFocus?.unfocus();
    await _reload();
  }

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = context.g;
    if (_loading) {
      return const ScreenSkeleton(title: 'Journal', subtitle: 'What He is doing, in your own words.');
    }
    final q = _q.trim().toLowerCase();
    final items = q.isEmpty ? _all : _all.where((e) => e.text.toLowerCase().contains(q) || (e.decision ?? '').toLowerCase().contains(q)).toList();
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        children: [
          Text('Journal', style: context.display),
          Text('What He is doing, in your own words.', style: context.body.copyWith(color: g.muted)),
          const SizedBox(height: 18),
          TextField(
            controller: _draft,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(hintText: 'Tonight I noticed…'),
          ),
          const SizedBox(height: 10),
          FilledButton(onPressed: _save, child: const Text('Save entry')),
          const SizedBox(height: 22),
          TextField(
            onChanged: (v) => setState(() => _q = v),
            decoration: InputDecoration(hintText: 'Search your journal', prefixIcon: Icon(Icons.search, color: g.muted)),
          ),
          const SizedBox(height: 14),
          if (items.isEmpty) Text(q.isEmpty ? 'Your first entry will appear here.' : 'Nothing matches "$_q".', style: context.body.copyWith(color: g.muted)),
          for (final e in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: EntryCard(entry: e, onDelete: () async {
                await Db.instance.deleteEntry(e.id);
                await _reload();
              }),
            ),
        ],
      ),
    );
  }
}

class EntryCard extends StatelessWidget {
  const EntryCard({super.key, required this.entry, this.onDelete});
  final Entry entry;
  final VoidCallback? onDelete;
  @override
  Widget build(BuildContext context) {
    final g = context.g;
    final selah = entry.kind == EntryKind.selah;
    return GCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (selah) ...[Icon(Icons.radio_button_checked, size: 14, color: g.goldText), const SizedBox(width: 6)],
                    Text((selah ? 'SELAH · ' : '') + DateFormat('EEE d MMM yyyy, HH:mm').format(entry.createdAt).toUpperCase(), style: context.label.copyWith(color: selah ? g.goldText : g.muted)),
                  ],
                ),
                if (entry.decision != null && entry.decision!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Brought to Him: ${entry.decision}', style: context.small.copyWith(color: g.ink)),
                ],
                const SizedBox(height: 6),
                Text(entry.text, style: context.body),
              ],
            ),
          ),
          if (onDelete != null)
            IconButton(
              tooltip: 'Delete',
              icon: Icon(Icons.delete_outline, color: g.muted, size: 20),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete this entry?'),
                    actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'))],
                  ),
                );
                if (ok == true) onDelete!();
              },
            ),
        ],
      ),
    );
  }
}
