import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import 'common_widgets.dart';

/// What the user chose in the duplicate-match sheet. Either "create a new
/// entry" (no duplicate) or "this candidate is the same person".
class DuplicateMatchResult {
  final bool createNew;
  final DuplicateCandidate? selected;

  const DuplicateMatchResult.createNew() : createNew = true, selected = null;
  const DuplicateMatchResult.same(this.selected) : createNew = false;
}

/// Shows the bilingual "Is this the same person?" sheet listing possible
/// duplicates. Returns the user's choice, or null if they dismissed it
/// (treated by callers as "cancel the save" — never a silent create).
///
/// Reused by both fire points (self-onboarding and add-relative); the caller
/// decides what "same person" means (claim request vs. link-existing).
Future<DuplicateMatchResult?> showDuplicateMatchSheet({
  required BuildContext context,
  required List<DuplicateCandidate> candidates,
}) {
  final l10n = context.l10n;
  return showModalBottomSheet<DuplicateMatchResult>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(l10n.duplicateSheetTitle, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                l10n.duplicateSheetSubtitle,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final c = candidates[i];
                    final m = c.member;
                    final details = <String>[
                      if (m.villageOrigin != null &&
                          m.villageOrigin!.trim().isNotEmpty)
                        m.villageOrigin!,
                      if (m.dob != null) l10n.duplicateBornYear(m.dob!.year),
                    ].join(' · ');
                    return Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        // Genealogical symbols: box = male, circle = female.
                        leading: Icon(
                          m.gender == 'Male'
                              ? Icons.square_outlined
                              : m.gender == 'Female'
                                  ? Icons.circle_outlined
                                  : Icons.person_outline,
                          size: 32,
                          color: theme.colorScheme.primary,
                        ),
                        title: Text(m.fullNameEn),
                        subtitle: Text(
                          [
                            if (m.firstNameGu != null) m.fullNameGu,
                            if (details.isNotEmpty) details,
                          ].join('\n'),
                        ),
                        isThreeLine:
                            m.firstNameGu != null && details.isNotEmpty,
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => Navigator.pop(
                          ctx,
                          DuplicateMatchResult.same(c),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: () => Navigator.pop(
                    ctx,
                    const DuplicateMatchResult.createNew(),
                  ),
                  child: Text(l10n.duplicateCreateNewButton),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
