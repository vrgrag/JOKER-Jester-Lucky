import 'dart:typed_data';

// ============================================================
// SCRAMBLER — per-project string obfuscator
// ============================================================
// Sensitive strings (config endpoint, attribution key, messaging
// project id, User-Agent version fragments) live inside the binary
// as encoded byte lists — never plaintext. Store-scanner grep tools
// can trivially link two APKs that share the same domain / dev-key
// string, so we hide the ones that matter behind a project-unique
// XOR keystream.
//
// Algorithm (project-unique — deliberately different shape from the
// reference template's FNV+xorshift):
//   1. A seed phrase seeds an SDBM-style rolling hash → 64-bit state.
//   2. The state feeds a splitmix-style mixer that emits [_padLen]
//      bytes of keystream (low byte per round).
//   3. Each byte is XOR'd with `stream[i % _padLen]` and a positional
//      rotor `((i * 131 + 7) & 0xFF)` so identical plaintext bytes
//      at different offsets do NOT round-trip to the same cipher byte.
//
// The transform is symmetric — `disguise()` and `revive()` reuse it.
//
// [FINGERPRINT] change BOTH `_seedPhrase` AND `_padLen` on every fresh
// project. Do not copy either value across siblings.
// ============================================================

// Project-unique 12-char opaque token — not a dictionary word tied to
// the theme, keeps grep-based clustering off the trail.
const String _seedPhrase = 'q7X_p3Vm!2Nz';

// Deliberately different from the reference template (24). Kept inside
// the recommended 16–48 range.
const int _padLen = 34;

Uint8List _weaveStream() {
  // SDBM rolling hash — different from FNV so the initial state does
  // not match anything a scanner might pattern-match on.
  int state = 0;
  for (final int c in _seedPhrase.codeUnits) {
    state = (c + (state << 6) + (state << 16) - state) & 0xFFFFFFFFFFFFFFFF;
  }
  if (state == 0) {
    state = 0xA5A5A5A5A5A5A5A5;
  }

  final Uint8List pad = Uint8List(_padLen);
  int mixer = state;
  for (int i = 0; i < _padLen; i++) {
    // Splitmix-like advance.
    mixer = (mixer + 0x9E3779B97F4A7C15) & 0xFFFFFFFFFFFFFFFF;
    int x = mixer;
    x = (x ^ (x >> 30)) * 0xBF58476D1CE4E5B7 & 0xFFFFFFFFFFFFFFFF;
    x = (x ^ (x >> 27)) * 0x94D049BB133111EB & 0xFFFFFFFFFFFFFFFF;
    x = x ^ (x >> 31);
    pad[i] = (x & 0xFF);
  }
  return pad;
}

final Uint8List _pad = _weaveStream();

int _rotor(int i) => ((i * 131) + 7) & 0xFF;

/// Encode a plaintext string into a byte list. Used only by the
/// packing script (kept private to the shell).
List<int> disguise(String input) {
  final List<int> raw = input.codeUnits;
  final List<int> out = List<int>.filled(raw.length, 0);
  for (int i = 0; i < raw.length; i++) {
    out[i] = (raw[i] ^ _pad[i % _padLen] ^ _rotor(i)) & 0xFF;
  }
  return out;
}

/// Decode a previously packed byte list back into the original string.
/// Returns an empty string for empty input — this is the safe path the
/// shell takes until the manager delivers real credentials.
String revive(List<int> packed) {
  if (packed.isEmpty) return '';
  final Uint8List out = Uint8List(packed.length);
  for (int i = 0; i < packed.length; i++) {
    out[i] = (packed[i] ^ _pad[i % _padLen] ^ _rotor(i)) & 0xFF;
  }
  return String.fromCharCodes(out);
}
