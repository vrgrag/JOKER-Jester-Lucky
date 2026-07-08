/// Which experience the shell locked onto for this install.
///
/// - [web]     → previously routed to the WebView (gray).
/// - [native]  → previously routed to the game (white).
/// - [pending] → first launch, decision not yet committed.
enum PortalKind {
  web,
  native,
  pending;

  static PortalKind decode(String? raw) {
    switch (raw) {
      case 'gray':
        return PortalKind.web;
      case 'white':
        return PortalKind.native;
      default:
        return PortalKind.pending;
    }
  }

  /// Persisted form. Deliberately different literals from `.name` so a
  /// prefs dump does not leak the "web / native" wording verbatim.
  String encode() {
    switch (this) {
      case PortalKind.web:
        return 'gray';
      case PortalKind.native:
        return 'white';
      case PortalKind.pending:
        return 'idle';
    }
  }
}
