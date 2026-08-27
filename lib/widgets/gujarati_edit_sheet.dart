import 'dart:async';

import 'package:flutter/material.dart';
import '../services/transliteration_service.dart';
import 'common_widgets.dart';

/// Shows a bottom sheet for choosing the correct Gujarati spelling of a name.
///
/// The user types the name in English (Latin) and picks from live phonetic
/// Gujarati candidates — no keyboard switching, and no accidental *translation*
/// of real-word names (that was the old Google-Translate behaviour). A manual
/// Gujarati field is still available for fine-tuning or direct entry.
///
/// [englishText] – the current English value, used to seed the suggestions.
/// [currentGujarati] – the currently-set Gujarati value.
///
/// Returns the chosen Gujarati string, or `null` if dismissed.
Future<String?> showGujaratiEditSheet({
  required BuildContext context,
  required String englishText,
  required String currentGujarati,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _GujaratiEditSheetBody(
      englishText: englishText,
      currentGujarati: currentGujarati,
    ),
  );
}

class _GujaratiEditSheetBody extends StatefulWidget {
  final String englishText;
  final String currentGujarati;

  const _GujaratiEditSheetBody({
    required this.englishText,
    required this.currentGujarati,
  });

  @override
  State<_GujaratiEditSheetBody> createState() => _GujaratiEditSheetBodyState();
}

class _GujaratiEditSheetBodyState extends State<_GujaratiEditSheetBody> {
  late final TextEditingController _latinController;
  late final TextEditingController _manualController;
  List<String> _candidates = [];
  bool _loading = false;
  String? _selected;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _latinController = TextEditingController(text: widget.englishText);
    _manualController = TextEditingController(text: widget.currentGujarati);
    _selected = widget.currentGujarati.isEmpty ? null : widget.currentGujarati;
    _fetchCandidates(widget.englishText);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _latinController.dispose();
    _manualController.dispose();
    super.dispose();
  }

  void _onLatinChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _fetchCandidates(value);
    });
  }

  Future<void> _fetchCandidates(String latin) async {
    if (latin.trim().isEmpty) {
      if (mounted) setState(() => _candidates = []);
      return;
    }
    setState(() => _loading = true);
    final results = await TransliterationService.candidates(latin, num: 6);
    if (!mounted) return;
    setState(() {
      _candidates = results;
      _loading = false;
    });
  }

  void _choose(String value) {
    setState(() {
      _selected = value;
      _manualController.text = value;
      _manualController.selection = TextSelection.fromPosition(
        TextPosition(offset: value.length),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.keyboard, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.editGujaratiSpelling,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),

          // Type the name in English (Latin) — candidates update live.
          TextField(
            controller: _latinController,
            autofocus: widget.currentGujarati.isEmpty,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: l10n.typeNameInEnglish,
              prefixIcon: const Icon(Icons.edit),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: _onLatinChanged,
          ),
          const SizedBox(height: 12),

          Text(l10n.gujaratiSpellingOptions,
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_candidates.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                l10n.noSpellingSuggestions,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _candidates.map((c) {
                final selected = _selected == c;
                return ChoiceChip(
                  label: Text(c, style: const TextStyle(fontSize: 18)),
                  selected: selected,
                  onSelected: (_) => _choose(c),
                );
              }).toList(),
            ),

          const SizedBox(height: 16),

          // Manual fine-tuning / direct Gujarati entry.
          Text(l10n.typeManually, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          TextField(
            controller: _manualController,
            decoration: InputDecoration(
              hintText: l10n.typeManually,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _selected = v),
          ),

          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              final text = _manualController.text.trim();
              Navigator.pop(context, text.isNotEmpty ? text : null);
            },
            child: Text(l10n.apply),
          ),
        ],
      ),
    );
  }
}
