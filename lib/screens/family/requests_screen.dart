import 'package:flutter/material.dart';

import '../../services/supabase_service.dart';
import '../../widgets/common_widgets.dart';

/// Approver inbox for match-found claim requests (migration 017). Lists
/// pending requests the current user is eligible to approve, each with a
/// large Approve / Reject action. Reached from the dashboard [RequestsAction]
/// badge.
class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  List<ClaimRequest>? _requests;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await SupabaseService.pendingClaimRequests();
      if (mounted) setState(() => _requests = list);
    } catch (_) {
      if (mounted) setState(() => _requests = []);
    }
  }

  Future<void> _act(
    ClaimRequest req, {
    required bool approve,
  }) async {
    final l10n = context.l10n;
    if (approve) {
      final confirmed = await showConfirmDialog(
        context: context,
        title: l10n.approve,
        message: l10n.approveClaimConfirm(req.target.fullNameEn),
        confirmText: l10n.approve,
      );
      if (!confirmed) return;
    }
    setState(() => _busy = true);
    try {
      if (approve) {
        await SupabaseService.approveClaimRequest(req.requestId);
      } else {
        await SupabaseService.rejectClaimRequest(req.requestId);
      }
      if (!mounted) return;
      setState(() {
        _requests?.removeWhere((r) => r.requestId == req.requestId);
        _busy = false;
      });
      showAppSnackBar(
        context,
        approve ? l10n.claimApproved : l10n.claimRejected,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showAppSnackBar(context, friendlyErrorMessage(context, e), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final requests = _requests;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.requestsTitle)),
      body: requests == null
          ? const Center(child: CircularProgressIndicator())
          : requests.isEmpty
              ? AppWidgets.empty(
                  message: l10n.noPendingRequests,
                  icon: Icons.inbox_outlined,
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: requests.length,
                    itemBuilder: (_, i) {
                      final req = requests[i];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                req.target.fullNameEn,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.claimRequestPrompt,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _busy
                                          ? null
                                          : () => _act(req, approve: false),
                                      child: Text(l10n.reject),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: _busy
                                          ? null
                                          : () => _act(req, approve: true),
                                      child: Text(l10n.approve),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

/// Dashboard app-bar action: an inbox icon badged with the pending-request
/// count. Hidden entirely when there are none, so it never adds clutter for
/// the common case. Refreshes its count after returning from the inbox.
class RequestsAction extends StatefulWidget {
  const RequestsAction({super.key});

  @override
  State<RequestsAction> createState() => _RequestsActionState();
}

class _RequestsActionState extends State<RequestsAction> {
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final list = await SupabaseService.pendingClaimRequests();
      if (mounted) setState(() => _count = list.length);
    } catch (_) {
      // Non-critical surface — leave the count as-is on error.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_count == 0) return const SizedBox.shrink();
    final l10n = context.l10n;
    return IconButton(
      tooltip: l10n.requestsTitle,
      icon: Badge(
        label: Text('$_count'),
        child: const Icon(Icons.how_to_reg),
      ),
      onPressed: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RequestsScreen()),
        );
        _refresh();
      },
    );
  }
}
