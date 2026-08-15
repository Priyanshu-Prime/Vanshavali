import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:graphview/GraphView.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/family_member.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/deep_link_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import 'add_family_member_screen.dart';
import 'member_detail_screen.dart';

// ─────────────────────────────────────────────────────────
//  View mode enums
// ─────────────────────────────────────────────────────────
enum _ViewMode { defaultView, pedigree }

// Pedigree view box/spacing constants. Box size matches _PersonBox's fixed
// dimensions exactly (the pedigree view reuses _PersonBox directly, one
// person per box, no couple-unit merging — see buildPedigreeAhnentafel).
const double _pedigreeBoxWidth = 136;
const double _pedigreeBoxHeight = 152;
const double _pedigreeColGap = 64;
const double _pedigreeRowGap = 24;

/// Sorts members eldest → youngest (unknown DOB sorts last), matching the
/// reading order genealogical charts conventionally use for siblings/children.
List<FamilyMember> _sortedByDob(List<FamilyMember> members) {
  final sorted = [...members];
  sorted.sort((a, b) {
    if (a.dob == null && b.dob == null) return 0;
    if (a.dob == null) return 1;
    if (b.dob == null) return -1;
    return a.dob!.compareTo(b.dob!);
  });
  return sorted;
}

String _focusUnitId(String memberId) => 'f:$memberId';

// ─────────────────────────────────────────────────────────
//  Graph node content — what a rendered unit actually shows.
//  Each unit is one visual "couple box" (a person + 0..n spouses), which is
//  how a genealogical chart's two-parents-converge-on-a-child shape gets
//  adapted to graphview's single-parent-per-node tree algorithm.
//
//  Public (not underscore-prefixed): these are read by [buildTreeData], a
//  top-level pure function extracted below so the default-view graph-
//  building logic can be unit tested without a widget tree or a
//  FamilyProvider. A private class can't cross the test file's library
//  boundary, so these were promoted from `_NodeContent`/`_UnitContent`/
//  `_SiblingsBadgeContent` as part of that extraction.
// ─────────────────────────────────────────────────────────
abstract class TreeNodeContent {
  const TreeNodeContent();
}

class TreeUnitContent extends TreeNodeContent {
  final FamilyMember primary;
  final List<FamilyMember> spouses;
  const TreeUnitContent(this.primary, this.spouses);
}

class SiblingsBadgeContent extends TreeNodeContent {
  final int count;
  const SiblingsBadgeContent(this.count);
}

/// Builds the graphview [Graph] structure for the default/immediate-family
/// tree view: an optional parents unit (father + his own spouse(s), so a
/// remarried parent's other spouse(s) still render coherently) as root, the
/// focus unit (center + all of the center's spouses) and siblings as its
/// children, and the center's own children as the focus unit's children.
///
/// Pure and deterministic — takes explicit relation data instead of reading
/// from a `FamilyProvider`/widget `State`, so it can be unit tested directly
/// (see `test/screens/family/family_tree_data_test.dart`). Extracted from
/// `_FamilyTreeScreenState._buildTreeData`, which now just forwards to this
/// function with data pulled from the provider/widget state; behavior is
/// unchanged.
///
/// [spousesOf] mirrors `FamilyProvider.spousesInNetwork(id)` — every spouse
/// (or inferred co-parent) of the given member found in the currently
/// loaded ego network.
({
  Graph graph,
  Map<String, TreeNodeContent> contents,
  String initialNodeId,
}) buildTreeData({
  required FamilyMember focus,
  required List<FamilyMember> focusSpouses,
  FamilyMember? father,
  FamilyMember? mother,
  required List<FamilyMember> children,
  required List<FamilyMember> siblings,
  required List<FamilyMember> Function(String memberId) spousesOf,
  required bool showSiblings,
}) {
  final sortedChildren = _sortedByDob(children);
  final sortedSiblings = _sortedByDob(siblings);

  final graph = Graph()..isTree = true;
  final contents = <String, TreeNodeContent>{};
  final nodeMap = <String, Node>{};

  Node ensure(String id, TreeNodeContent content) {
    return nodeMap.putIfAbsent(id, () {
      contents[id] = content;
      final n = Node.Id(id);
      graph.addNode(n);
      return n;
    });
  }

  Node? parentNode;
  if (father != null || mother != null) {
    final primaryParent = father ?? mother!;
    final otherParent = father != null ? mother : null;
    final unitSpouses = <FamilyMember>[];
    final seenSpouseIds = <String>{};
    for (final s in spousesOf(primaryParent.id)) {
      if (seenSpouseIds.add(s.id)) unitSpouses.add(s);
    }
    if (otherParent != null && seenSpouseIds.add(otherParent.id)) {
      unitSpouses.add(otherParent);
    }
    parentNode = ensure(
      'p:${primaryParent.id}',
      TreeUnitContent(primaryParent, unitSpouses),
    );
  }

  final focusUnitId = _focusUnitId(focus.id);
  final focusNode = ensure(focusUnitId, TreeUnitContent(focus, focusSpouses));

  if (parentNode != null) {
    graph.addEdge(parentNode, focusNode);

    if (showSiblings) {
      for (final sib in sortedSiblings) {
        final sibNode = ensure(
          's:${sib.id}',
          TreeUnitContent(sib, spousesOf(sib.id)),
        );
        graph.addEdge(parentNode, sibNode);
      }
    } else if (sortedSiblings.isNotEmpty) {
      final badgeNode =
          ensure('siblings_badge', SiblingsBadgeContent(sortedSiblings.length));
      graph.addEdge(parentNode, badgeNode);
    }
  }

  for (final child in sortedChildren) {
    final childNode = ensure(
      'c:${child.id}',
      TreeUnitContent(child, spousesOf(child.id)),
    );
    graph.addEdge(focusNode, childNode);
  }

  return (graph: graph, contents: contents, initialNodeId: focusUnitId);
}

/// Builds an ahnentafel (Sosa-Stradonitz) map of [focus]'s ancestors:
/// index 1 is [focus] itself, index `2n` is the father of index `n`, index
/// `2n+1` is the mother of index `n` — the standard numbering used by real
/// pedigree charts, where every person has exactly two parents (unlike the
/// default tree view's siblings/children, ancestry never converges back
/// down, so there's no "single-parent-per-node" layout-algorithm problem to
/// work around here — each ancestor gets their own box, full stop).
///
/// Only includes indices actually resolvable from [pool] — a missing/
/// unknown ancestor simply has no entry, and neither do any of *their*
/// ancestors (nothing to walk further from). Pure and deterministic;
/// rendered by `_buildPedigreeView` via `_PedigreeConnectorPainter` and
/// `Positioned` `_PersonBox`es, using [pedigreeGeneration]/[pedigreeSlot]
/// for placement.
///
/// Bounded by [maxGenerations] (a fixed number of BFS rounds, not an
/// unbounded walk) — this is inherently cycle-safe by construction, unlike
/// the old linear chain-walking approach this replaced, which needed an
/// explicit visited-ids guard because it had no natural bound. A
/// father_id/mother_id cycle in bad data can, at worst, make the same
/// person appear at more than one ahnentafel index — which is exactly how
/// real genealogy software also depicts "pedigree collapse" (e.g. cousin
/// marriages), not a bug to guard against.
Map<int, FamilyMember> buildPedigreeAhnentafel({
  required FamilyMember focus,
  required List<FamilyMember> pool,
  int maxGenerations = 5,
}) {
  FamilyMember? byId(String? id) =>
      id == null ? null : pool.where((m) => m.id == id).firstOrNull;

  final result = <int, FamilyMember>{1: focus};
  var frontier = <int, FamilyMember>{1: focus};
  for (var gen = 0; gen < maxGenerations; gen++) {
    final next = <int, FamilyMember>{};
    for (final entry in frontier.entries) {
      final n = entry.key;
      final father = byId(entry.value.fatherId);
      final mother = byId(entry.value.motherId);
      if (father != null) {
        result[2 * n] = father;
        next[2 * n] = father;
      }
      if (mother != null) {
        result[2 * n + 1] = mother;
        next[2 * n + 1] = mother;
      }
    }
    if (next.isEmpty) break;
    frontier = next;
  }
  return result;
}

/// Generation of ahnentafel index [n] (focus is generation 0, parents 1,
/// grandparents 2, ...) — floor(log2(n)).
int pedigreeGeneration(int n) => n.bitLength - 1;

/// Zero-based position of ahnentafel index [n] within its own generation
/// (e.g. index 5 is slot 1 of generation 2's 4 slots: 4,5,6,7 -> 0,1,2,3).
int pedigreeSlot(int n) => n - (1 << pedigreeGeneration(n));

class FamilyTreeScreen extends StatefulWidget {
  const FamilyTreeScreen({super.key});

  @override
  State<FamilyTreeScreen> createState() => _FamilyTreeScreenState();
}

class _FamilyTreeScreenState extends State<FamilyTreeScreen> {
  _ViewMode _viewMode = _ViewMode.defaultView;
  bool _showSiblings = false;

  // Pedigree view's own pan/zoom controller — WE fully own this one
  // (create it, dispose it) since the pedigree view's InteractiveViewer is
  // plain Flutter, which never takes ownership of an externally-supplied
  // controller. Never shared with the default/graphview view — see
  // _GraphViewHost below for why sharing a controller across the two was
  // exactly what caused repeated on-device crashes.
  final TransformationController _pedigreeTransformController =
      TransformationController();
  final GlobalKey _viewportKey = GlobalKey();

  // Tracks which (focus, generation-depth) shape the pedigree view has
  // already been auto-zoomed-to-fit for, so it only refits when that
  // actually changes (switching into the view, or the ancestor chain
  // finishing a deeper fetch) — not on every incidental rebuild, which
  // would otherwise keep fighting the user's own manual zoom/pan.
  String? _pedigreeFitAppliedForKey;

  // The default (graphview) view's controller, owned by whichever
  // _GraphViewHost is currently mounted (see below) — null whenever no
  // _GraphViewHost is mounted (pedigree view active, or the single-node
  // bypass in _buildDefaultView is active). Never call .dispose() on this
  // from here; _GraphViewHost/graphview itself owns that.
  GraphViewController? _graphController;

  // Cache of the last-built graphview Graph/Node objects, invalidated only
  // when the underlying family data (or sibling-visibility) actually
  // changes. Without this, buildTreeData() ran on every widget rebuild —
  // including ones with nothing to do with the tree (an unrelated Provider
  // notifying, the app resuming from background, etc.) — constructing a
  // brand-new Graph() with brand-new Node object instances each time, even
  // though GraphView.builder's own Element persists across those rebuilds
  // (its key only changes on focus/sibling-visibility change). graphview
  // tracks node identity internally, so silently swapping every Node object
  // out from under a still-mounted GraphView on every incidental rebuild is
  // a plausible source of the Flutter framework GlobalKey/Element-lifecycle
  // assertions observed on-device ('_elements.contains(element)' on a fresh
  // profile — since fixed by the single-node bypass below — and separately
  // 'element._lifecycleState == _ElementLifecycle.inactive' when the tree
  // screen was rebuilt after the app resumed from background). Keying the
  // cache on reference equality of egoNetwork/spouseLinks (which
  // FamilyProvider only reassigns when it actually re-fetches) plus the
  // focus id and sibling-visibility flag is sufficient: every derived
  // getter (father/mother/children/siblings/spouses) reads from those same
  // two lists, so if both are unchanged the tree data is guaranteed
  // unchanged too.
  List<FamilyMember>? _cachedEgoNetwork;
  List<SpouseLink>? _cachedSpouseLinks;
  String? _cachedFocusId;
  bool? _cachedShowSiblings;
  ({
    Graph graph,
    Map<String, TreeNodeContent> contents,
    String initialNodeId,
  })? _cachedTreeData;

  ({
    Graph graph,
    Map<String, TreeNodeContent> contents,
    String initialNodeId,
  }) _buildTreeDataCached(FamilyProvider provider, FamilyMember focus) {
    if (_cachedTreeData != null &&
        identical(provider.egoNetwork, _cachedEgoNetwork) &&
        identical(provider.spouseLinks, _cachedSpouseLinks) &&
        _cachedFocusId == focus.id &&
        _cachedShowSiblings == _showSiblings) {
      return _cachedTreeData!;
    }
    final data = _buildTreeData(provider, focus);
    _cachedEgoNetwork = provider.egoNetwork;
    _cachedSpouseLinks = provider.spouseLinks;
    _cachedFocusId = focus.id;
    _cachedShowSiblings = _showSiblings;
    _cachedTreeData = data;
    return data;
  }

  // No initState() needed for the graph controller — _GraphViewHost creates
  // its own when it mounts (see below).

  @override
  void dispose() {
    // Ours to own: the pedigree view's plain InteractiveViewer never takes
    // ownership of a supplied controller, unlike graphview (see
    // _GraphViewHost). _graphController is NOT disposed here — whichever
    // _GraphViewHost currently owns it disposes it in its own dispose().
    _pedigreeTransformController.dispose();
    super.dispose();
  }

  void _focusOn(FamilyProvider provider, FamilyMember member) {
    setState(() => _showSiblings = false);
    // Re-center the ego-centric fetch on the tapped member (center + parents
    // + children + spouse only) rather than just relabeling the existing
    // in-memory network — see family-relations skill.
    provider.loadEgoNetwork(member.id);
  }

  /// The controller actually driving the currently-visible view — null if
  /// the default view's _GraphViewHost isn't mounted right now (pedigree
  /// view active, or the single-node bypass). Zoom buttons no-op rather
  /// than touch a controller that might not exist yet/anymore.
  TransformationController? get _activeTransformController {
    if (_viewMode == _ViewMode.pedigree) return _pedigreeTransformController;
    return _graphController?.transformationController;
  }

  void _zoomBy(double factor) {
    final controller = _activeTransformController;
    if (controller == null) return;

    final currentScale = controller.value.getMaxScaleOnAxis();
    final targetScale = (currentScale * factor).clamp(0.35, 2.5);
    if ((targetScale - currentScale).abs() < 0.001) return;
    final effectiveFactor = targetScale / currentScale;

    final renderBox =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    final center = renderBox != null
        ? Offset(renderBox.size.width / 2, renderBox.size.height / 2)
        : Offset.zero;

    final matrix = controller.value.clone()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..scaleByDouble(effectiveFactor, effectiveFactor, effectiveFactor, 1)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);

    controller.value = matrix;
  }

  void _zoomIn() => _zoomBy(1.25);
  void _zoomOut() => _zoomBy(0.8);

  void _resetZoom() {
    if (_viewMode == _ViewMode.defaultView && _graphController != null) {
      final focus = context.read<FamilyProvider>().centerMember;
      if (focus != null) {
        try {
          _graphController!.jumpToNode(ValueKey(_focusUnitId(focus.id)));
          return;
        } catch (_) {
          // No live GraphView to jump within — e.g. the single-node case,
          // which bypasses _GraphViewHost entirely. Fall through to the
          // plain transform reset below.
        }
      }
    }
    _activeTransformController?.value = Matrix4.identity();
  }

  /// Scales+centers _pedigreeTransformController so the whole
  /// [canvasWidth]x[canvasHeight] pedigree chart is visible in the current
  /// viewport, instead of opening at 100% zoom wherever InteractiveViewer's
  /// default identity transform happens to land (frequently cropped for
  /// anything past 2-3 generations). Never zooms IN past the chart's
  /// natural size, only out.
  void _fitPedigreeToView(double canvasWidth, double canvasHeight) {
    final renderBox =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || canvasWidth <= 0 || canvasHeight <= 0) return;

    final viewportSize = renderBox.size;
    // The pedigree content is wrapped in `Padding(all: 40)` by the caller —
    // factor that into the content's true footprint for an accurate fit.
    const contentPadding = 40.0 * 2;
    final contentWidth = canvasWidth + contentPadding;
    final contentHeight = canvasHeight + contentPadding;

    final widthScale = viewportSize.width / contentWidth;
    final heightScale = viewportSize.height / contentHeight;
    final scale = (widthScale < heightScale ? widthScale : heightScale)
        .clamp(0.35, 1.0);

    final scaledWidth = contentWidth * scale;
    final scaledHeight = contentHeight * scale;
    final dx = (viewportSize.width - scaledWidth) / 2;
    final dy = (viewportSize.height - scaledHeight) / 2;

    _pedigreeTransformController.value = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(scale, scale, scale, 1);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final familyProvider = context.watch<FamilyProvider>();
    final authProvider = context.watch<AuthProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final locale = settingsProvider.locale.languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.familyTree),
        actions: [
          IconButton(
            icon: const Icon(Icons.center_focus_strong),
            tooltip: l10n.centerOnMe,
            onPressed: () {
              if (authProvider.currentMember != null) {
                _focusOn(familyProvider, authProvider.currentMember!);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.syncData,
            onPressed: () {
              if (familyProvider.centerMember != null) {
                familyProvider
                    .loadEgoNetwork(familyProvider.centerMember!.id);
              }
            },
          ),
        ],
      ),
      body: familyProvider.isLoading
          ? AppWidgets.loading(message: l10n.loading)
          : (familyProvider.error != null && familyProvider.egoNetwork.isEmpty)
              ? AppWidgets.error(
                  context: context,
                  message: friendlyErrorMessage(context, familyProvider.error!),
                  onRetry: () {
                    if (familyProvider.centerMember != null) {
                      familyProvider.loadEgoNetwork(familyProvider.centerMember!.id);
                    } else if (authProvider.currentMember != null) {
                      _focusOn(familyProvider, authProvider.currentMember!);
                    }
                  },
                )
              : familyProvider.egoNetwork.isEmpty
              ? AppWidgets.empty(
                  message: l10n.noFamilyMembers,
                  subtitle: l10n.tapToAdd,
                  icon: Icons.account_tree_outlined,
                )
              : Column(
                  children: [
                    _buildViewModeBar(context),
                    Expanded(
                      child: Container(
                        key: _viewportKey,
                        color: Theme.of(context).colorScheme.surface,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: _viewMode == _ViewMode.defaultView
                                  ? _buildDefaultView(
                                      context, familyProvider, locale)
                                  : InteractiveViewer(
                                      transformationController:
                                          _pedigreeTransformController,
                                      constrained: false,
                                      minScale: 0.35,
                                      maxScale: 2.5,
                                      boundaryMargin:
                                          const EdgeInsets.all(160),
                                      child: Padding(
                                        padding: const EdgeInsets.all(40),
                                        child: _buildPedigreeView(
                                            context, familyProvider, locale),
                                      ),
                                    ),
                            ),
                            Positioned(
                              right: 16,
                              bottom: 16,
                              child: _ZoomControls(
                                onZoomIn: _zoomIn,
                                onZoomOut: _zoomOut,
                                onReset: _resetZoom,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  VIEW MODE TOGGLE BAR
  // ═══════════════════════════════════════════════════════
  Widget _buildViewModeBar(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SegmentedButton<_ViewMode>(
            segments: [
              ButtonSegment(
                value: _ViewMode.defaultView,
                label: Text(l10n.defaultView),
                icon: const Icon(Icons.account_tree),
              ),
              ButtonSegment(
                value: _ViewMode.pedigree,
                label: Text(l10n.pedigreeView),
                icon: const Icon(Icons.straight),
              ),
            ],
            selected: {_viewMode},
            onSelectionChanged: (v) => setState(() {
              _viewMode = v.first;
              _showSiblings = false;
              _pedigreeTransformController.value = Matrix4.identity();
              // Force _buildPedigreeView to auto-fit-to-view again every
              // time Pedigree is (re)selected, not just the first time.
              _pedigreeFitAppliedForKey = null;
            }),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  DEFAULT / IMMEDIATE FAMILY VIEW
  //
  //  Built as a graphview tree: each "couple unit" (a person + their
  //  spouse(s)) is a single node, since graphview's Buchheim-Walker layout
  //  is a single-parent-per-node algorithm and can't natively express two
  //  parents converging on a shared child. The parents row, the focus row
  //  (siblings + focus) and the children row are three tree levels hanging
  //  off a single root, so the algorithm handles all spacing/centering —
  //  no hand-rolled pixel math, which is what caused the child-drift bug.
  // ═══════════════════════════════════════════════════════
  Widget _buildDefaultView(
    BuildContext context,
    FamilyProvider provider,
    String locale,
  ) {
    final focus = provider.centerMember;
    if (focus == null) return const SizedBox();

    final data = _buildTreeDataCached(provider, focus);

    // A brand-new profile with no father/mother/spouse/children/siblings yet
    // produces a single-node, edge-less graph. graphview's
    // BuchheimWalkerAlgorithm isn't designed for a trivial 1-node tree and
    // can throw a Flutter framework GlobalKey assertion
    // ('_elements.contains(element)') when asked to lay one out — render the
    // lone unit directly instead of routing it through the graph library.
    if (data.graph.nodes.length <= 1) {
      final content = data.contents[data.initialNodeId];
      if (content is! TreeUnitContent) return const SizedBox();
      return Center(
        child: _UnitWidget(
          primary: content.primary,
          spouses: content.spouses,
          focusId: focus.id,
          locale: locale,
          onTapMember: (m) => _focusOn(provider, m),
          onLongPressMember: (m) => _showMemberOptions(context, m, provider),
        ),
      );
    }

    final configuration = BuchheimWalkerConfiguration()
      ..siblingSeparation = 28
      ..levelSeparation = 72
      ..subtreeSeparation = 48
      ..orientation = BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM
      ..useCurvedConnections = false;

    final algorithm = BuchheimWalkerAlgorithm(
        configuration, _FamilyTreeEdgeRenderer(configuration));

    return _GraphViewHost(
      // Recreates _GraphViewHost's Element (and re-triggers its initial
      // jump-to-focus-node) whenever the center member or sibling
      // visibility changes, so tapping a node to re-center always re-frames
      // the camera. See _GraphViewHost's own doc comment for why it also
      // needs to be recreated on *key-unchanged* remounts (loading-state
      // swap, single-node bypass) — that's handled automatically by tying
      // controller creation to this widget's own initState, not by this key.
      key: ValueKey('tree_${focus.id}_$_showSiblings'),
      graph: data.graph,
      algorithm: algorithm,
      initialNodeId: data.initialNodeId,
      paint: Paint()
        ..color = Theme.of(context).colorScheme.outline
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
      // Not setState() — this fires from the child's initState, which runs
      // synchronously during THIS widget's own build phase; calling
      // setState here would throw. _graphController is only read later, on
      // a button press, by which time initState will already have run.
      onControllerCreated: (c) => _graphController = c,
      // Only clear if nothing newer has already taken over — see
      // _GraphViewHost's class doc comment. A same-frame remount (e.g.
      // tapping the siblings badge, which changes _showSiblings and
      // therefore this widget's key within one setState) mounts the NEW
      // _GraphViewHost — calling onControllerCreated — before the OLD
      // one's dispose() runs this callback. Clearing unconditionally would
      // let the older instance's cleanup clobber the newer, still-valid
      // controller — silently breaking the zoom/reset buttons with no
      // crash to signal it (confirmed by an independent review that wrote
      // a reproduction test: zoom-in stopped changing the transform matrix
      // after toggling the siblings badge, with no exception thrown).
      onControllerDisposed: (c) {
        if (identical(_graphController, c)) {
          _graphController = null;
        }
      },
      builder: (node) {
        final id = node.key!.value as String;
        final content = data.contents[id];
        if (content is SiblingsBadgeContent) {
          return _SiblingsBadge(
            count: content.count,
            onTap: () => setState(() => _showSiblings = true),
          );
        }
        if (content is TreeUnitContent) {
          return _UnitWidget(
            primary: content.primary,
            spouses: content.spouses,
            focusId: focus.id,
            locale: locale,
            onTapMember: (m) => _focusOn(provider, m),
            onLongPressMember: (m) => _showMemberOptions(context, m, provider),
          );
        }
        return const SizedBox();
      },
    );
  }

  /// Pulls the relevant relation data out of [provider]/widget state and
  /// forwards to the pure, top-level [buildTreeData] (defined above), which
  /// does the actual graph construction and is what's unit tested. Kept as a
  /// thin wrapper so call sites in this State class don't change.
  ({
    Graph graph,
    Map<String, TreeNodeContent> contents,
    String initialNodeId,
  }) _buildTreeData(FamilyProvider provider, FamilyMember focus) {
    return buildTreeData(
      focus: focus,
      focusSpouses: provider.spouses,
      father: provider.father,
      mother: provider.mother,
      children: provider.children,
      siblings: provider.siblings,
      spousesOf: provider.spousesInNetwork,
      showSiblings: _showSiblings,
    );
  }

  // ═══════════════════════════════════════════════════════
  //  PEDIGREE VIEW — branching ancestor chart (both parents at every
  //  generation, per the ahnentafel numbering — see buildPedigreeAhnentafel)
  //
  //  Positions are computed deterministically from each person's
  //  ahnentafel index (no graph-layout algorithm needed or possible here —
  //  every person converges from exactly two parents, which is the one
  //  topology graphview's BuchheimWalkerAlgorithm categorically can't
  //  express without merging into couple-units, and that merging is exactly
  //  what made the OLD pedigree view's connector lines land ambiguously
  //  between partners instead of on a specific parent/child). Rendered as
  //  absolutely-positioned boxes in a Stack sized to the full ancestor
  //  chart, inside the caller's unconstrained InteractiveViewer — same
  //  pattern the default view uses for pan/zoom, just without graphview.
  // ═══════════════════════════════════════════════════════
  Widget _buildPedigreeView(
    BuildContext context,
    FamilyProvider provider,
    String locale,
  ) {
    final focus = provider.centerMember;
    if (focus == null) return const SizedBox();

    // provider.egoNetwork only ever has ONE generation of parents (by
    // design — see get_ego_network), which is nowhere near enough for a
    // pedigree chart: it would resolve father/mother and then dead-end,
    // silently hiding every earlier generation with no error. Fetch the
    // deeper ancestor set (migration 005) lazily, once per focus change —
    // guarded by ancestorChainForId so this doesn't refire every rebuild —
    // and fall back to egoNetwork (still correct, just shallower) while
    // that fetch is in flight, offline, or if it fails.
    if (!provider.isLoadingAncestors &&
        provider.ancestorChainForId != focus.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) provider.loadAncestorChain(focus.id);
      });
    }
    final pool = provider.ancestorChainForId == focus.id
        ? provider.ancestorChain
        : provider.egoNetwork;

    final ahnentafel = buildPedigreeAhnentafel(focus: focus, pool: pool);
    final maxGeneration = ahnentafel.keys
        .map(pedigreeGeneration)
        .reduce((a, b) => a > b ? a : b);

    // Each ahnentafel index is vertically centered exactly between its two
    // parents (see the class doc comment on _PedigreeConnectorPainter for
    // why that makes the connector math land cleanly with no gap/offset):
    // slotHeight halves every generation closer to the leaves, so a node's
    // center is always the midpoint of its children's slot ranges.
    const leafUnit = _pedigreeBoxHeight + _pedigreeRowGap;
    // Focus (generation 0) on the right, ancestors fanning leftward as
    // generation increases — so (maxGeneration - generation), not
    // generation directly.
    double xOf(int n) => (maxGeneration - pedigreeGeneration(n)) *
        (_pedigreeBoxWidth + _pedigreeColGap);
    double yOf(int n) {
      final slotHeight =
          (1 << (maxGeneration - pedigreeGeneration(n))) * leafUnit;
      return (pedigreeSlot(n) + 0.5) * slotHeight - _pedigreeBoxHeight / 2;
    }

    final canvasWidth =
        (maxGeneration + 1) * (_pedigreeBoxWidth + _pedigreeColGap);
    final canvasHeight = (1 << maxGeneration) * leafUnit;

    // Auto-zoom-out to fit the whole chart on entry — refit whenever the
    // shape actually changes (switching into this view, or the ancestor
    // chain finishing a deeper fetch that grows the canvas), not on every
    // rebuild, which would otherwise repeatedly fight the user's own manual
    // zoom/pan. See _pedigreeFitAppliedForKey's doc comment.
    final fitKey = '${focus.id}_$maxGeneration';
    if (_pedigreeFitAppliedForKey != fitKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _fitPedigreeToView(canvasWidth, canvasHeight);
        setState(() => _pedigreeFitAppliedForKey = fitKey);
      });
    }

    return SizedBox(
      width: canvasWidth,
      height: canvasHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _PedigreeConnectorPainter(
                ahnentafel: ahnentafel,
                xOf: xOf,
                yOf: yOf,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          for (final entry in ahnentafel.entries)
            Positioned(
              left: xOf(entry.key),
              top: yOf(entry.key),
              child: _PersonBox(
                member: entry.value,
                isFocus: entry.value.id == focus.id,
                locale: locale,
                onTap: () => _focusOn(provider, entry.value),
                onLongPress: () =>
                    _showMemberOptions(context, entry.value, provider),
              ),
            ),
        ],
      ),
    );
  }

  // ── Bottom sheet options ──
  void _showMemberOptions(
      BuildContext context, FamilyMember member, FamilyProvider provider) {
    final l10n = context.l10n;
    final authProvider = context.read<AuthProvider>();
    final isOwnProfile = member.id == authProvider.currentMember?.id;
    final canAddRelations = !member.isClaimed || isOwnProfile;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: Text(l10n.viewProfile),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => MemberDetailScreen(member: member)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.center_focus_strong),
              title: Text(l10n.centerOnMember),
              onTap: () {
                Navigator.pop(ctx);
                _focusOn(provider, member);
              },
            ),
            if (canAddRelations)
              ListTile(
                leading: const Icon(Icons.person_add),
                title: Text(l10n.addFamilyMember),
                subtitle: Text(
                  isOwnProfile
                      ? l10n.addRelativeForYourself
                      : l10n.addRelativeFor(member.firstNameEn),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _navigateToAddMember(context, member, provider);
                },
              ),
            if (!member.isClaimed)
              ListTile(
                leading: const Icon(Icons.share),
                title: Text(l10n.inviteMember),
                onTap: () {
                  Navigator.pop(ctx);
                  _inviteMember(context, member);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToAddMember(
      BuildContext context, FamilyMember member, FamilyProvider provider) async {
    final authProvider = context.read<AuthProvider>();
    final isOwnProfile = member.id == authProvider.currentMember?.id;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddFamilyMemberScreen(
          targetMember: isOwnProfile ? null : member,
        ),
      ),
    );

    // Refresh tree if a member was added
    if (result == true) {
      provider.loadEgoNetwork(provider.centerMember?.id ?? member.id);
    }
  }

  void _inviteMember(BuildContext context, FamilyMember member) {
    final settingsProvider = context.read<SettingsProvider>();
    final locale = settingsProvider.locale.languageCode;
    final l10n = context.l10n;
    final link = DeepLinkService.generateInviteLink(member.id);
    final shareText = DeepLinkService.generateInviteText(
      member.getFullName(locale),
      member.id,
      locale,
    );

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _InviteSheet(
        link: link,
        shareText: shareText,
        memberId: member.id,
        l10n: l10n,
        onSnackBar: (msg) => showAppSnackBar(context, msg),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Owns exactly one GraphViewController (and its underlying
//  TransformationController) for its own Element's lifetime — nothing else
//  in this file creates or disposes one.
//
//  Why this exists: graphview's own _GraphViewState (confirmed by reading
//  graphview-1.5.1/lib/GraphView.dart in full) sets its
//  TransformationController exactly once, in initState, from whatever
//  GraphViewController it's given — there is no didUpdateWidget to pick up
//  a replacement later. Its dispose() unconditionally disposes that
//  controller every single time its Element unmounts, for ANY reason: a
//  changed widget key, yes, but just as much a parent swapping to a
//  loading/empty state and back (this screen's isLoading branch, which
//  flips true on every re-center/refresh), a view-mode switch away and
//  back, or the single-node bypass in _buildDefaultView kicking in and
//  later reverting. Every one of those unmounts GraphView just as surely
//  as a key change does, and reusing one long-lived, externally-created
//  controller across any of them hands a NEW GraphView instance a
//  TransformationController that a PREVIOUS instance already disposed —
//  the exact "A TransformationController was used after being disposed"
//  crash reported multiple times on-device, from different trigger paths,
//  before this rewrite.
//
//  The fix isn't more bookkeeping in the parent State to track when a
//  reused controller might be stale — that bookkeeping can never cover
//  every unmount path, several of which the parent can't even observe
//  directly. Instead, controller creation is tied to THIS widget's own
//  Element lifecycle, which Flutter guarantees is fresh (initState runs
//  again) every time it's newly mounted, regardless of why the previous
//  instance went away. That structurally guarantees "always fresh, never
//  reused after dispose" without needing to enumerate every unmount cause.
//
//  Callback split (onControllerCreated / onControllerDisposed) instead of
//  one nullable callback: a same-frame remount — e.g. toggling the
//  siblings badge, which changes this widget's key within a single
//  setState — mounts the NEW instance (calling onControllerCreated)
//  *before* the OLD instance's dispose() runs. A single "pass null on
//  dispose" callback would let the old instance's cleanup clobber the new
//  instance's just-registered controller. Passing the specific controller
//  being removed lets the caller compare identity and only clear if
//  nothing newer already took over (see the call site in
//  _buildDefaultView). Found by independent review + a reproduction test,
//  not by inspection alone: this doesn't crash, it silently leaves the
//  zoom/reset buttons non-functional, which is easy to miss.
// ─────────────────────────────────────────────────────────
class _GraphViewHost extends StatefulWidget {
  final Graph graph;
  final Algorithm algorithm;
  final Paint paint;
  final String initialNodeId;
  final Widget Function(Node node) builder;
  final ValueChanged<GraphViewController> onControllerCreated;
  final ValueChanged<GraphViewController> onControllerDisposed;

  const _GraphViewHost({
    super.key,
    required this.graph,
    required this.algorithm,
    required this.paint,
    required this.initialNodeId,
    required this.builder,
    required this.onControllerCreated,
    required this.onControllerDisposed,
  });

  @override
  State<_GraphViewHost> createState() => _GraphViewHostState();
}

class _GraphViewHostState extends State<_GraphViewHost> {
  late final GraphViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        GraphViewController(transformationController: TransformationController());
    widget.onControllerCreated(_controller);
  }

  @override
  void dispose() {
    widget.onControllerDisposed(_controller);
    // Do NOT dispose the TransformationController here — graphview's own
    // GraphView/_GraphViewState.dispose() already does, unconditionally.
    // See the class doc comment above for why this controller is created
    // fresh in initState rather than reused across mount cycles.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GraphView.builder(
      controller: _controller,
      graph: widget.graph,
      algorithm: widget.algorithm,
      initialNode: ValueKey(widget.initialNodeId),
      paint: widget.paint,
      builder: widget.builder,
      // graphview's default (true) plays a "fly in from parent position"
      // animation for every node, every time this widget's underlying
      // RenderObject is freshly created — which is every single re-center
      // tap, since _GraphViewHost fully remounts on a new key each time (see
      // its class doc comment). The result was every tap replaying a visible
      // "tree builds itself again" animation instead of an instant re-center
      // — and, per graphview's own hitTestChildren, taps are ignored while
      // it plays. We already jump to the focus node without animation
      // (jumpToNode(..., animated: false) in _focusOn); this makes the node
      // layout itself consistent with that, since this app doesn't use
      // graphview's collapse/expand feature that the animation exists for.
      animated: false,
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Custom connector-line anchoring. graphview's default TreeEdgeRenderer
//  connects the geometric CENTER of one node's bounding box to the center of
//  the next — correct for a single-person node, but every node in this tree
//  can be a couple-unit (_UnitWidget: primary + spouses, growing wider to
//  the right for each spouse via _MarriageConnector).
//
//  The anchor needs to be DIFFERENT depending on which end of the edge a
//  couple-unit is on, not the same fix on both ends (an earlier version of
//  this class anchored both ends to the primary member and broke the
//  parent-side case — see the live bug report this comment replaced):
//    - As the DESTINATION (a unit receiving a line from ITS OWN parent):
//      anchor to the PRIMARY member specifically, not the merged-couple
//      center — otherwise the line lands between that person and their own
//      spouse instead of on the actual blood relative continuing the line.
//    - As the SOURCE (a unit's line going down to ITS children): anchor to
//      the TRUE CENTER of the whole merged unit — the marriage point — since
//      those children descend from BOTH people in the unit equally. This is
//      also what makes multiple children/siblings share one visual trunk
//      that splits to each of them, instead of each looking like it comes
//      from only one parent.
//  Every node type this tree renders (_PersonBox, _SiblingsBadge) starts
//  with a fixed 136px-wide box drawn first (leftmost), so that's a stable
//  anchor for the destination case, not just couple-units — no
//  per-node-type branching needed. Only X anchors change; Y/orientation
//  logic is untouched.
// ─────────────────────────────────────────────────────────
class _FamilyTreeEdgeRenderer extends TreeEdgeRenderer {
  _FamilyTreeEdgeRenderer(super.configuration);

  // Half of _PersonBox's/_SiblingsBadge's fixed width (136) — see class doc
  // comment above.
  static const double _primaryAnchorOffsetX = 68;

  @override
  void buildTopBottomPath(
    Node node,
    Node child,
    Offset parentPos,
    Offset childPos,
    double parentCenterX,
    double parentCenterY,
    double childCenterX,
    double childCenterY,
  ) {
    super.buildTopBottomPath(
      node,
      child,
      parentPos,
      childPos,
      parentCenterX, // source: true center (marriage point) — unchanged
      parentCenterY,
      childPos.dx + _primaryAnchorOffsetX, // destination: primary anchor
      childCenterY,
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Couple/family unit widget — one graphview node. Renders the primary
//  member plus every spouse (supports remarriage: can be more than one)
//  side by side, connected by a short marriage tie-line.
// ─────────────────────────────────────────────────────────
class _UnitWidget extends StatelessWidget {
  final FamilyMember primary;
  final List<FamilyMember> spouses;
  final String focusId;
  final String locale;
  final void Function(FamilyMember member) onTapMember;
  final void Function(FamilyMember member) onLongPressMember;

  const _UnitWidget({
    required this.primary,
    required this.spouses,
    required this.focusId,
    required this.locale,
    required this.onTapMember,
    required this.onLongPressMember,
  });

  @override
  Widget build(BuildContext context) {
    final people = <FamilyMember>[primary, ...spouses];
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (int i = 0; i < people.length; i++) ...[
          if (i > 0) const _MarriageConnector(),
          _PersonBox(
            member: people[i],
            isFocus: people[i].id == focusId,
            locale: locale,
            onTap: () => onTapMember(people[i]),
            onLongPress: () => onLongPressMember(people[i]),
          ),
        ],
      ],
    );
  }
}

class _MarriageConnector extends StatelessWidget {
  const _MarriageConnector();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: 26,
      height: 152,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 3,
              width: 26,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              width: 15,
              height: 15,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.7), width: 1.5),
              ),
              child: Icon(Icons.favorite, size: 8, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Single person node — box for male, rounded/circle for female (kept
//  consistent with the genealogical symbol convention used elsewhere in
//  the app). Larger text/icons than before, and the "unclaimed" state is
//  now a labeled chip instead of a bare icon.
// ─────────────────────────────────────────────────────────
class _PersonBox extends StatelessWidget {
  final FamilyMember member;
  final bool isFocus;
  final String locale;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _PersonBox({
    required this.member,
    required this.isFocus,
    required this.locale,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final color = AppTheme.getNodeColor(member.gender, member.isClaimed);
    final isFemale = member.gender == 'Female';

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: 136,
        height: 152,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.20),
              color.withValues(alpha: 0.08),
            ],
          ),
          border: Border.all(
            color: isFocus ? theme.colorScheme.primary : color.withValues(alpha: 0.7),
            width: isFocus ? 4 : 1.5,
          ),
          borderRadius: BorderRadius.circular(isFemale ? 76 : 18),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.22),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        // FittedBox + a MainAxisSize.min Column, instead of letting the
        // Column fill the fixed-height Container directly: a hardcoded
        // height card can always be pushed into overflow by a long-enough
        // name or a larger system font-size setting (a real accessibility
        // case, and especially relevant for this app's older users) —
        // confirmed live: a 2-line name + the "unclaimed" chip already
        // nearly filled the budget even before this round's visual refresh,
        // and reproduced as a genuine overflow in a widget test forcing a
        // 1.3x text scale. FittedBox scales the whole card's content down
        // uniformly if it doesn't fit, instead of erroring — the content
        // gets slightly smaller in the rare case it's tight, rather than
        // ever showing Flutter's red/yellow overflow stripe.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(
                  member.gender == 'Male'
                      ? Icons.man
                      : member.gender == 'Female'
                          ? Icons.woman
                          : Icons.person,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                member.getFullName(locale),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontSize: 15,
                  fontWeight: isFocus ? FontWeight.bold : FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (!member.isClaimed) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_add_alt,
                        size: 14, color: theme.colorScheme.outline),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        l10n.unclaimed,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 11,
                          color: theme.colorScheme.outline,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Siblings badge — a normal tree node (child of the parents unit) so it
//  participates in the same layout algorithm as everything else, instead
//  of being positioned by hand.
// ─────────────────────────────────────────────────────────
class _SiblingsBadge extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _SiblingsBadge({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 136,
        height: 152,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.4),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.18),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            Icon(Icons.people_alt_outlined, size: 34, color: theme.colorScheme.primary),
            const SizedBox(height: 6),
            Text(
              '+$count',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            Text(
              l10n.siblings,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.showSiblings,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Pedigree view connector lines — elbow/T-junction style: a stub from each
//  person's box to a joining point, a vertical spine spanning between their
//  two parents (or a plain L-bend if only one parent is known), then stubs
//  from the spine into each parent's box. Standard genealogical
//  pedigree-chart connector shape. Matches _buildPedigreeView's xOf/yOf
//  exactly: each parent pair's midpoint always falls precisely on the
//  child's own vertical center (by construction of the ahnentafel
//  slot-centering math), so the horizontal stub from the child always lands
//  exactly on the spine with no gap or offset to account for here.
//
//  Ancestors are laid out to the LEFT of their descendants (focus is the
//  rightmost box, generation increases leftward — see xOf), so a child
//  connects out its LEFT edge toward its parents' RIGHT edge, not the other
//  way around.
// ─────────────────────────────────────────────────────────
class _PedigreeConnectorPainter extends CustomPainter {
  final Map<int, FamilyMember> ahnentafel;
  final double Function(int n) xOf;
  final double Function(int n) yOf;
  final Color color;

  _PedigreeConnectorPainter({
    required this.ahnentafel,
    required this.xOf,
    required this.yOf,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final n in ahnentafel.keys) {
      final father = ahnentafel[2 * n];
      final mother = ahnentafel[2 * n + 1];
      if (father == null && mother == null) continue;

      final childLeftX = xOf(n);
      final childCenterY = yOf(n) + _pedigreeBoxHeight / 2;
      final parentRightX =
          xOf(2 * n) + _pedigreeBoxWidth; // same generation as 2n+1 — same x
      final joinX = (childLeftX + parentRightX) / 2;

      canvas.drawLine(
        Offset(childLeftX, childCenterY),
        Offset(joinX, childCenterY),
        paint,
      );

      if (father != null) {
        final fatherY = yOf(2 * n) + _pedigreeBoxHeight / 2;
        canvas.drawLine(
            Offset(joinX, childCenterY), Offset(joinX, fatherY), paint);
        canvas.drawLine(
            Offset(joinX, fatherY), Offset(parentRightX, fatherY), paint);
      }
      if (mother != null) {
        final motherY = yOf(2 * n + 1) + _pedigreeBoxHeight / 2;
        canvas.drawLine(
            Offset(joinX, childCenterY), Offset(joinX, motherY), paint);
        canvas.drawLine(
            Offset(joinX, motherY), Offset(parentRightX, motherY), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PedigreeConnectorPainter oldDelegate) {
    return !identical(oldDelegate.ahnentafel, ahnentafel);
  }
}

// ─────────────────────────────────────────────────────────
//  Explicit zoom controls — a simpler alternative to pinch gestures for a
//  low-tech-literacy audience. Large (48dp) touch targets.
// ─────────────────────────────────────────────────────────
class _ZoomControls extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;

  const _ZoomControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ZoomButton(icon: Icons.add, tooltip: l10n.zoomIn, onPressed: onZoomIn),
        const SizedBox(height: 8),
        _ZoomButton(icon: Icons.remove, tooltip: l10n.zoomOut, onPressed: onZoomOut),
        const SizedBox(height: 8),
        _ZoomButton(
          icon: Icons.center_focus_strong,
          tooltip: l10n.resetView,
          onPressed: onReset,
        ),
      ],
    );
  }
}

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _ZoomButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: theme.colorScheme.surface,
        shape: const CircleBorder(),
        elevation: 3,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon, color: theme.colorScheme.primary, size: 26),
          ),
        ),
      ),
    );
  }
}

/// Stateful invite bottom sheet that generates an invite code async
class _InviteSheet extends StatefulWidget {
  final String link;
  final String shareText;
  final String memberId;
  final dynamic l10n;
  final void Function(String) onSnackBar;

  const _InviteSheet({
    required this.link,
    required this.shareText,
    required this.memberId,
    required this.l10n,
    required this.onSnackBar,
  });

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  String? _inviteCode;
  bool _loadingCode = true;

  @override
  void initState() {
    super.initState();
    _generateCode();
  }

  Future<void> _generateCode() async {
    try {
      final code = await SupabaseService.generateInviteCode(widget.memberId);
      if (mounted) setState(() { _inviteCode = code; _loadingCode = false; });
    } catch (e) {
      if (mounted) setState(() => _loadingCode = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.inviteMember,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.inviteDescription,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),

          // ── Invite Code ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  l10n.inviteCode,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 8),
                if (_loadingCode)
                  const SizedBox(
                    height: 36,
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else if (_inviteCode != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _inviteCode!,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 6,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _inviteCode!));
                          widget.onSnackBar(l10n.codeCopied);
                        },
                        icon: const Icon(Icons.copy, size: 20),
                        tooltip: l10n.inviteCode,
                      ),
                    ],
                  ),
                const SizedBox(height: 4),
                Text(
                  l10n.inviteCodeDesc,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          // ── Invite Link ──
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.link,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: widget.link));
                    Navigator.pop(context);
                    widget.onSnackBar(l10n.linkCopied);
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: Text(l10n.copyInviteLink),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    final codeText = _inviteCode != null
                        ? '\n\nInvite Code: $_inviteCode'
                        : '';
                    SharePlus.instance.share(ShareParams(text: widget.shareText + codeText));
                  },
                  icon: const Icon(Icons.share, size: 18),
                  label: Text(l10n.share),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
