import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../pact/manifest.dart';
import '../signals/gate_verdict.dart';
import 'agent_forge.dart';
import 'depot.dart';

/// Posts the merged attribution body to the gateway endpoint and
/// interprets the verdict. A missing endpoint or any transport failure
/// yields a rejected verdict, which routes the user to the native game.
///
/// Successful verdicts cache the destination + expiry so the returning
/// launch can fall back to the last-known-good on a transient outage.
class GatewayRelay {
  GatewayRelay(this._depot);

  final Depot _depot;

  Future<GateVerdict> query(Map<String, dynamic> body) async {
    final String endpoint = JesterManifest.gatewayEndpoint;
    debugPrint('[Jester][Gateway] endpoint=$endpoint');
    debugPrint('[Jester][Gateway] body=${jsonEncode(body)}');
    if (endpoint.isEmpty) {
      debugPrint('[Jester][Gateway] endpoint empty -> rejected');
      return GateVerdict.rejected('unset-endpoint');
    }

    try {
      final response = await jesterNet
          .post(
            Uri.parse(endpoint),
            headers: const <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('[Jester][Gateway] status=${response.statusCode}');
      debugPrint('[Jester][Gateway] body<-${response.body}');

      if (response.statusCode != 200) {
        return GateVerdict.rejected('http-${response.statusCode}');
      }

      final Map<String, dynamic> raw =
          jsonDecode(response.body) as Map<String, dynamic>;
      final GateVerdict verdict = GateVerdict.fromWire(raw);
      debugPrint(
        '[Jester][Gateway] verdict granted=${verdict.granted} '
        'dest=${verdict.destination} remark=${verdict.remark}',
      );

      if (verdict.granted && verdict.hasDestination) {
        await _depot.writeCachedDestination(verdict.destination!);
        if (verdict.validUntil != null) {
          await _depot.writeLinkExpiry(verdict.validUntil!);
        }
      }
      return verdict;
    } catch (err, stack) {
      debugPrint('[Jester][Gateway] transport error: $err');
      debugPrint('[Jester][Gateway] stack: $stack');
      return GateVerdict.rejected(err.toString());
    }
  }

  Future<String?> lastKnownDestination() => _depot.readCachedDestination();
}
