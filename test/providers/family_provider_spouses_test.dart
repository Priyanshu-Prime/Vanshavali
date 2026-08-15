// Tests for FamilyProvider's synchronous spouse-resolution logic:
//   - spousesInNetwork
//   - spouses / spouse
//   - getSpousesOf (network-only fast path; the SupabaseService/
//     LocalStorageService fallback path is NOT covered here — see note at
//     bottom of file)
//
// FamilyProvider's real data-loading path (loadEgoNetwork) is tightly
// coupled to static SupabaseService / LocalStorageService / SyncService
// calls that require either a live Supabase project or an initialized Hive
// box — neither of which is available in a pure `flutter test` run without
// a live backend. To make the pure resolution logic testable anyway, a
// small `@visibleForTesting` seam (`debugSetNetworkForTesting`) was added to
// FamilyProvider so a fixture ego network + spouse-links list can be
// injected directly, bypassing the network/cache entirely.

import 'package:flutter_test/flutter_test.dart';
import 'package:vanshavali/models/family_member.dart';
import 'package:vanshavali/providers/family_provider.dart';

FamilyMember _member({
  required String id,
  String? fatherId,
  String? motherId,
  String gender = 'Male',
  String firstName = 'Test',
}) {
  return FamilyMember(
    id: id,
    createdAt: DateTime(2020, 1, 1),
    fatherId: fatherId,
    motherId: motherId,
    firstNameEn: firstName,
    lastNameEn: 'Person',
    gender: gender,
  );
}

void main() {
  group('FamilyProvider.spousesInNetwork', () {
    test('returns empty list when there are no spouse links', () {
      final provider = FamilyProvider();
      final a = _member(id: 'a');
      provider.debugSetNetworkForTesting(egoNetwork: [a], spouseLinks: const []);
      expect(provider.spousesInNetwork('a'), isEmpty);
    });

    test('resolves a single linked spouse regardless of link direction', () {
      final provider = FamilyProvider();
      final a = _member(id: 'a', gender: 'Male');
      final b = _member(id: 'b', gender: 'Female');
      provider.debugSetNetworkForTesting(
        egoNetwork: [a, b],
        spouseLinks: const [SpouseLink(memberId: 'a', spouseId: 'b')],
      );
      expect(provider.spousesInNetwork('a').map((m) => m.id), ['b']);
      // Same link, looked up from the other side.
      expect(provider.spousesInNetwork('b').map((m) => m.id), ['a']);
    });

    test(
      'resolves multiple spouses for a member with 2+ linked spouses '
      '(remarriage support)',
      () {
        final provider = FamilyProvider();
        final a = _member(id: 'a', gender: 'Male');
        final b = _member(id: 'b', gender: 'Female');
        final c = _member(id: 'c', gender: 'Female');
        provider.debugSetNetworkForTesting(
          egoNetwork: [a, b, c],
          spouseLinks: const [
            SpouseLink(memberId: 'a', spouseId: 'b'),
            SpouseLink(memberId: 'a', spouseId: 'c'),
          ],
        );
        final ids = provider.spousesInNetwork('a').map((m) => m.id).toSet();
        expect(ids, {'b', 'c'});
      },
    );

    test('a spouse link to a member not present in the ego network is '
        'silently dropped (nothing to render)', () {
      final provider = FamilyProvider();
      final a = _member(id: 'a');
      provider.debugSetNetworkForTesting(
        egoNetwork: [a],
        spouseLinks: const [SpouseLink(memberId: 'a', spouseId: 'not-loaded')],
      );
      expect(provider.spousesInNetwork('a'), isEmpty);
    });
  });

  group('FamilyProvider.spouses / spouse (center-member accessors)', () {
    test('spouses is empty when there is no center member', () {
      final provider = FamilyProvider();
      expect(provider.spouses, isEmpty);
    });

    test('spouses returns all linked spouses of the center member', () {
      final provider = FamilyProvider();
      final a = _member(id: 'a', gender: 'Male');
      final b = _member(id: 'b', gender: 'Female');
      final c = _member(id: 'c', gender: 'Female');
      provider.debugSetNetworkForTesting(
        egoNetwork: [a, b, c],
        spouseLinks: const [
          SpouseLink(memberId: 'a', spouseId: 'b'),
          SpouseLink(memberId: 'a', spouseId: 'c'),
        ],
        centerMember: a,
      );
      expect(provider.spouses.map((m) => m.id).toSet(), {'b', 'c'});
    });

    test('spouse returns the first linked spouse when one or more exist', () {
      final provider = FamilyProvider();
      final a = _member(id: 'a', gender: 'Male');
      final b = _member(id: 'b', gender: 'Female');
      provider.debugSetNetworkForTesting(
        egoNetwork: [a, b],
        spouseLinks: const [SpouseLink(memberId: 'a', spouseId: 'b')],
        centerMember: a,
      );
      expect(provider.spouse?.id, 'b');
    });

    test(
      'spouse falls back to co-parent inference (via shared children) when '
      'no explicit spouse link exists yet — legacy/incomplete-data '
      'compatibility',
      () {
        final provider = FamilyProvider();
        final a = _member(id: 'a', gender: 'Male');
        final coParent = _member(id: 'co', gender: 'Female');
        final child = _member(id: 'child', fatherId: 'a', motherId: 'co');
        provider.debugSetNetworkForTesting(
          egoNetwork: [a, coParent, child],
          spouseLinks: const [], // no explicit link
          centerMember: a,
        );
        expect(provider.spouse?.id, 'co');
      },
    );

    test('spouse is null when there is no link and no shared children', () {
      final provider = FamilyProvider();
      final a = _member(id: 'a');
      provider.debugSetNetworkForTesting(
        egoNetwork: [a],
        spouseLinks: const [],
        centerMember: a,
      );
      expect(provider.spouse, isNull);
    });
  });

  group('FamilyProvider.getSpousesOf (network-only fast path)', () {
    test('resolves explicit spouse links without any network/cache call',
        () async {
      final provider = FamilyProvider();
      final a = _member(id: 'a', gender: 'Male');
      final b = _member(id: 'b', gender: 'Female');
      provider.debugSetNetworkForTesting(
        egoNetwork: [a, b],
        spouseLinks: const [SpouseLink(memberId: 'a', spouseId: 'b')],
      );
      final result = await provider.getSpousesOf('a');
      expect(result.map((m) => m.id), ['b']);
    });

    test(
      'multi-spouse case: getSpousesOf returns every linked spouse for a '
      'remarried member',
      () async {
        final provider = FamilyProvider();
        final a = _member(id: 'a', gender: 'Male');
        final b = _member(id: 'b', gender: 'Female');
        final c = _member(id: 'c', gender: 'Female');
        provider.debugSetNetworkForTesting(
          egoNetwork: [a, b, c],
          spouseLinks: const [
            SpouseLink(memberId: 'a', spouseId: 'b'),
            SpouseLink(memberId: 'a', spouseId: 'c'),
          ],
        );
        final result = await provider.getSpousesOf('a');
        expect(result.map((m) => m.id).toSet(), {'b', 'c'});
      },
    );

    test(
      'co-parent-inference fallback: a shared child with no explicit spouse '
      'link still surfaces the co-parent',
      () async {
        final provider = FamilyProvider();
        final a = _member(id: 'a', gender: 'Male');
        final coParent = _member(id: 'co', gender: 'Female');
        final child = _member(id: 'child', fatherId: 'a', motherId: 'co');
        provider.debugSetNetworkForTesting(
          egoNetwork: [a, coParent, child],
          spouseLinks: const [],
        );
        final result = await provider.getSpousesOf('a');
        expect(result.map((m) => m.id), ['co']);
      },
    );

    test(
      'combines an explicit spouse link with a co-parent-inferred one '
      'without duplicating a member present in both',
      () async {
        final provider = FamilyProvider();
        final a = _member(id: 'a', gender: 'Male');
        final b = _member(id: 'b', gender: 'Female'); // explicit link
        final child = _member(id: 'child', fatherId: 'a', motherId: 'b');
        provider.debugSetNetworkForTesting(
          egoNetwork: [a, b, child],
          spouseLinks: const [SpouseLink(memberId: 'a', spouseId: 'b')],
        );
        final result = await provider.getSpousesOf('a');
        expect(result.map((m) => m.id).toList(), ['b']);
      },
    );
  });

  // NOTE (finding, not a gap silently skipped): getSpousesOf's *fallback*
  // branch — reached only when both the explicit-link and co-parent-
  // inference lookups come back empty — calls `SyncService.isOnline()` and
  // then either `SupabaseService.getSpousesOf` or
  // `LocalStorageService.getSpouseIdsOf`. Both are static calls with no
  // injectable seam, so that branch is entangled with a live backend /
  // initialized Hive box and is intentionally NOT exercised here. Every
  // fixture above returns via the network-only fast path so the fallback is
  // never reached.
}
