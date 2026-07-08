/// Parsed response from the gateway (config) endpoint.
///
/// Wire format is `{ok, url, expires, message}`. The field names here
/// deliberately differ from the JSON keys so the compiled binary does
/// not contain the raw contract vocabulary as Dart symbols.
class GateVerdict {
  const GateVerdict({
    required this.granted,
    this.destination,
    this.remark,
    this.validUntil,
    this.isTransportError = false,
  });

  /// Backend `ok` — true means route to the WebView with [destination].
  final bool granted;

  /// Backend `url` — the content link to load.
  final String? destination;

  /// Backend `message` — diagnostic note (`"organic"`, `"blocked"`, …).
  final String? remark;

  /// Backend `expires` — unix seconds after which [destination] must be
  /// re-queried before being reused.
  final int? validUntil;

  /// True when the failure was a network / HTTP error rather than an
  /// intentional rejection from the server. Transport errors must NOT
  /// persist `PortalKind.native` — the next launch should retry.
  final bool isTransportError;

  factory GateVerdict.fromWire(Map<String, dynamic> map) {
    return GateVerdict(
      granted: map['ok'] as bool? ?? false,
      destination: map['url'] as String?,
      remark: map['message'] as String?,
      validUntil: map['expires'] as int?,
    );
  }

  factory GateVerdict.rejected(String remark) =>
      GateVerdict(granted: false, remark: remark);

  factory GateVerdict.transportError(String remark) =>
      GateVerdict(granted: false, remark: remark, isTransportError: true);

  bool get hasDestination =>
      destination != null && destination!.isNotEmpty;
}
