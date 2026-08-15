/// Shared spacing and sizing tokens.
///
/// Screens previously hand-coded their own `SizedBox`/`EdgeInsets` values
/// (24/16/12/8 in one screen, 48/24/16 in another, ...) which drifted apart
/// over time. Use these constants instead of new magic numbers so spacing
/// stays consistent across the app.
class AppSpacing {
  AppSpacing._();

  /// 4dp — tight spacing between closely related elements (e.g. an icon and
  /// its label).
  static const double xs = 4;

  /// 8dp — spacing between related items within a group (list rows, chips).
  static const double sm = 8;

  /// 16dp — the default gap between sections/cards and standard content
  /// padding.
  static const double md = 16;

  /// 24dp — spacing between major sections on a screen.
  static const double lg = 24;

  /// 32dp — large separation, e.g. above/below a page's primary action.
  static const double xl = 32;

  /// 48dp — hero/intro spacing (e.g. above a logo on an auth screen).
  static const double xxl = 48;

  /// Minimum recommended touch-target size (dp) for tappable controls.
  /// Material's default `IconButton` size (~40dp) is borderline small for
  /// this app's low-tech-literacy, all-ages audience — enforce a real floor
  /// instead of relying on every call site to remember to set one.
  static const double minTapTarget = 48;
}
