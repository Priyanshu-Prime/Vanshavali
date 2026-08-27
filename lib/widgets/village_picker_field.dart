import 'package:flutter/material.dart';
import '../services/gujarat_places_service.dart';
import 'common_widgets.dart';

/// A tap-to-pick field for the ancestral village. Village is chosen from the
/// bundled Census directory (district -> taluka -> village) or found via a
/// state-wide search — never free text — so every profile's village_origin is
/// a canonical, uniform value.
class VillagePickerField extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const VillagePickerField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final has = value != null && value!.trim().isNotEmpty;
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () async {
        final picked = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (_) => const _VillagePickerSheet(),
        );
        if (picked != null) onChanged(picked.isEmpty ? null : picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: l10n.villageOrigin,
          prefixIcon: const Icon(Icons.home_outlined),
          suffixIcon: has
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => onChanged(null),
                )
              : const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          has ? value! : l10n.selectVillage,
          style: has
              ? theme.textTheme.bodyLarge
              : theme.textTheme.bodyLarge
                  ?.copyWith(color: theme.colorScheme.outline),
        ),
      ),
    );
  }
}

class _VillagePickerSheet extends StatefulWidget {
  const _VillagePickerSheet();

  @override
  State<_VillagePickerSheet> createState() => _VillagePickerSheetState();
}

class _VillagePickerSheetState extends State<_VillagePickerSheet> {
  bool _loading = true;
  GjPlace? _district;
  GjPlace? _taluka;
  final _searchController = TextEditingController();
  List<GjPlace> _searchResults = const [];

  @override
  void initState() {
    super.initState();
    GujaratPlacesService.load().then((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    setState(() => _searchResults =
        q.trim().length < 2 ? const [] : GujaratPlacesService.searchVillages(q));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    Widget body;
    if (_loading) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_searchController.text.trim().length >= 2) {
      // State-wide search results (village — Taluka handled by caller display).
      body = _list(
        _searchResults,
        (v) => Navigator.pop(context, v.name),
        emptyText: l10n.noResultsFound,
      );
    } else if (_district == null) {
      body = _list(GujaratPlacesService.districts(),
          (d) => setState(() => _district = d));
    } else if (_taluka == null) {
      body = _list(GujaratPlacesService.talukas(_district!.code),
          (t) => setState(() => _taluka = t));
    } else {
      body = _list(
        GujaratPlacesService.villages(_district!.code, _taluka!.code),
        (v) => Navigator.pop(context, v.name),
      );
    }

    // Header shows the current drill-down / lets the user step back.
    final crumbs = <String>[
      if (_district != null) _district!.name,
      if (_taluka != null) _taluka!.name,
    ];

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
              if (_district != null)
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() {
                    if (_taluka != null) {
                      _taluka = null;
                    } else {
                      _district = null;
                    }
                  }),
                ),
              Expanded(
                child: Text(
                  crumbs.isEmpty ? l10n.selectVillage : crumbs.join(' › '),
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          // Search box (state-wide village search — for when you know the name
          // but not the district).
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: l10n.searchVillage,
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            onChanged: _onSearch,
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: body,
          ),
        ],
      ),
    );
  }

  Widget _list(List<GjPlace> items, ValueChanged<GjPlace> onTap,
      {String? emptyText}) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(emptyText ?? '', textAlign: TextAlign.center),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      itemCount: items.length,
      itemBuilder: (_, i) => ListTile(
        dense: true,
        title: Text(items[i].name),
        onTap: () => onTap(items[i]),
      ),
    );
  }
}
