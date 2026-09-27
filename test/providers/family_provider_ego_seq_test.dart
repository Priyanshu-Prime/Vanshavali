// loadEgoNetwork stale-response guard: overlapping loads must resolve to the
// LATEST requested center, with network + spouseLinks + center all from that
// same load, and the spinner cleared only by that load.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanshavali/models/family_member.dart';
import 'package:vanshavali/providers/family_provider.dart';

FamilyMember _m(String id) => FamilyMember(
    id: id, createdAt: DateTime(2020), firstNameEn: id, lastNameEn: 'T');

typedef _Ego = ({List<FamilyMember> network, List<SpouseLink> links});

void main() {
  late FamilyProvider fp;
  late Map<String, Completer<_Ego>> pending;
  _Ego egoOf(String id) => (
        network: [_m(id), _m('$id-spouse')],
        links: [SpouseLink(memberId: id, spouseId: '$id-spouse')],
      );

  setUp(() {
    fp = FamilyProvider();
    pending = {};
    fp.debugEgoFetcherForTesting =
        (id) => (pending[id] = Completer<_Ego>()).future;
  });

  void expectCenteredOn(String id) {
    expect(fp.centerMember?.id, id);
    expect(fp.egoNetwork.map((m) => m.id), [id, '$id-spouse']);
    expect(fp.spouseLinks.single.memberId, id);
    expect(fp.spouses.map((m) => m.id), ['$id-spouse']);
    expect(fp.isLoading, isFalse);
  }

  test('older load finishing LAST is dropped', () async {
    final a = fp.loadEgoNetwork('a');
    final b = fp.loadEgoNetwork('b');
    pending['b']!.complete(egoOf('b'));
    await b;
    expectCenteredOn('b');
    pending['a']!.complete(egoOf('a'));
    await a;
    expectCenteredOn('b');
  });

  test('older load finishing FIRST neither publishes nor clears the spinner',
      () async {
    final a = fp.loadEgoNetwork('a');
    final b = fp.loadEgoNetwork('b');
    pending['a']!.complete(egoOf('a'));
    await a;
    expect(fp.isLoading, isTrue);
    expect(fp.egoNetwork, isEmpty);
    pending['b']!.complete(egoOf('b'));
    await b;
    expectCenteredOn('b');
  });

  test('clearSearch clears a loading flag an invalidated search left set', () {
    fp.debugSetNetworkForTesting(egoNetwork: const [], isLoading: true);
    fp.clearSearch();
    expect(fp.isLoading, isFalse);
  });
}
