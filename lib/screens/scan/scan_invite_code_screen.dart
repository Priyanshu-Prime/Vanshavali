import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../theme/app_spacing.dart';
import '../../utils/invite_code_parser.dart';
import '../../widgets/common_widgets.dart';

/// Full-screen QR scanner for invite codes.
///
/// Pops with the normalized 6-character invite code (a `String`) on a
/// successful scan, or `null` if the user backs out / chooses to type the
/// code by hand. Manual entry always remains available on the calling screen —
/// this is purely an optional shortcut, never a required step.
class ScanInviteCodeScreen extends StatefulWidget {
  const ScanInviteCodeScreen({super.key});

  @override
  State<ScanInviteCodeScreen> createState() => _ScanInviteCodeScreenState();
}

class _ScanInviteCodeScreenState extends State<ScanInviteCodeScreen> {
  final MobileScannerController _controller = MobileScannerController(
    // Only QR codes carry invite codes; ignore other symbologies.
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  // Guard so a burst of detections (or a re-detection while we're already
  // popping) can't pop the route twice or fire multiple snackbars.
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;

    for (final barcode in capture.barcodes) {
      final code = parseInviteCode(barcode.rawValue);
      if (code != null) {
        _handled = true;
        Navigator.of(context).pop(code);
        return;
      }
    }

    // A QR was read but it did not contain a valid invite code — tell the user
    // and keep scanning rather than silently doing nothing.
    if (capture.barcodes.isNotEmpty) {
      showAppSnackBar(context, context.l10n.scanInvalidCode, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(l10n.scanInviteCode),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              // The message ("camera access needed, you can still type it")
              // fits any start-up failure, permission-denied being the common
              // one; either way the escape hatch is manual entry.
              errorBuilder: (context, error) => _PermissionOrError(
                message: l10n.cameraPermissionNeeded,
                buttonLabel: l10n.enterManually,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          // Bottom instruction banner — high contrast on the dark camera view.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: Colors.black.withValues(alpha: 0.6),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.lg,
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.scanQrInstruction,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // Manual-entry escape hatch is always one large tap away.
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.keyboard, color: Colors.white),
                      label: Text(
                        l10n.enterManually,
                        style: const TextStyle(color: Colors.white),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        side: const BorderSide(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-bleed message shown when the camera can't start (most commonly a denied
/// camera permission). Keeps a large, obvious way back to manual entry.
class _PermissionOrError extends StatelessWidget {
  final String message;
  final String buttonLabel;
  final VoidCallback onPressed;

  const _PermissionOrError({
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(AppSpacing.lg),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.no_photography, color: Colors.white70, size: 64),
          const SizedBox(height: AppSpacing.lg),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.keyboard),
            label: Text(buttonLabel),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
          ),
        ],
      ),
    );
  }
}
