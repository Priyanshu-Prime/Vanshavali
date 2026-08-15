import 'package:flutter/material.dart';
import '../services/translation_service.dart';
import 'common_widgets.dart';

/// Shows a bottom sheet letting the user pick or type the correct Gujarati
/// spelling for an English name.
///
/// [englishText] – the current English value (used to generate alternatives).
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
  late TextEditingController _manualController;
  String? _autoTranslation;
  String? _transliteration;
  bool _loading = true;
  String? _selected;

  @override
  void initState() {
    super.initState();
    _manualController = TextEditingController(text: widget.currentGujarati);
    _selected = widget.currentGujarati;
    _loadAlternatives();
  }

  Future<void> _loadAlternatives() async {
    final english = widget.englishText.trim();
    if (english.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    // Generate alternatives in parallel
    final futures = await Future.wait([
      TranslationService.translateToGujarati(english),
    ]);
    final auto = futures[0];
    final translit = TranslationService.transliterateToGujarati(english);

    if (mounted) {
      setState(() {
        _autoTranslation = auto;
        _transliteration = translit;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

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
          // Header
          Row(
            children: [
              const Icon(Icons.translate, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.editGujaratiSpelling,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            // Option 1: Auto-translation from Google
            if (_autoTranslation != null && _autoTranslation!.isNotEmpty)
              _OptionTile(
                label: l10n.autoTranslation,
                value: _autoTranslation!,
                selected: _selected == _autoTranslation,
                onTap: () => setState(() {
                  _selected = _autoTranslation;
                  _manualController.text = _autoTranslation!;
                }),
              ),

            // Option 2: Basic transliteration
            if (_transliteration != null &&
                _transliteration!.isNotEmpty &&
                _transliteration != _autoTranslation)
              _OptionTile(
                label: l10n.transliteration,
                value: _transliteration!,
                selected: _selected == _transliteration,
                onTap: () => setState(() {
                  _selected = _transliteration;
                  _manualController.text = _transliteration!;
                }),
              ),

            const SizedBox(height: 12),

            // Option 3: Manual text input
            Text(
              l10n.typeManually,
              style: Theme.of(context).textTheme.bodySmall,
            ),
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

            // Apply button
            FilledButton(
              onPressed: () {
                final text = _manualController.text.trim();
                Navigator.pop(context, text.isNotEmpty ? text : null);
              },
              child: Text(l10n.apply),
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: selected
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
      child: ListTile(
        dense: true,
        title: Text(value, style: const TextStyle(fontSize: 18)),
        subtitle: Text(label),
        trailing: selected
            ? Icon(Icons.check_circle,
                color: Theme.of(context).colorScheme.primary)
            : null,
        onTap: onTap,
      ),
    );
  }
}
