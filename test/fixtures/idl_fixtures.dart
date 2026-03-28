/// Test IDL fixtures loaded from real Anchor IDL files.
library;

import 'dart:convert';
import 'dart:io';

/// Loads and caches IDL JSON from test fixture files.
class IdlFixtures {
  IdlFixtures._();

  static Map<String, dynamic>? _anchorFull;
  static Map<String, dynamic>? _oldFormat;

  /// Modern Anchor IDL (spec 0.1.0) with all features:
  /// instructions, accounts, events, errors, types, constants,
  /// nested accounts, defined types, enums, zero-copy, etc.
  ///
  /// Source: anchor/tests/idl/idls/new.json
  static Map<String, dynamic> get anchorFull {
    _anchorFull ??= _loadFixture('anchor_idl_full.json');
    return Map<String, dynamic>.from(_anchorFull!);
  }

  /// Old-format Anchor IDL (v0.x) without discriminators, address, or metadata.
  /// Uses isMut/isSigner instead of writable/signer, and has inline account types.
  ///
  /// Source: coral-xyz-examples/basic_counter/assets/idl.json
  static Map<String, dynamic> get oldFormatCounter {
    _oldFormat ??= _loadFixture('old_format_counter.json');
    return Map<String, dynamic>.from(_oldFormat!);
  }

  /// A minimal valid modern IDL for simple tests.
  static Map<String, dynamic> get minimal => {
    'address': 'Min11111111111111111111111111111111111111111',
    'metadata': {'name': 'minimal', 'version': '0.1.0', 'spec': '0.1.0'},
    'instructions': [
      {
        'name': 'initialize',
        'discriminator': [175, 175, 109, 31, 13, 152, 155, 237],
        'accounts': [],
        'args': [],
      },
    ],
  };

  static Map<String, dynamic> _loadFixture(String filename) {
    final dir = _fixtureDir();
    final file = File('$dir/$filename');
    if (!file.existsSync()) {
      throw StateError('Fixture file not found: ${file.path}');
    }
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  static String _fixtureDir() {
    // When running via `dart test`, the working directory is the package root.
    final candidates = ['test/fixtures', '../test/fixtures'];
    for (final c in candidates) {
      if (Directory(c).existsSync()) return c;
    }
    throw StateError(
      'Cannot find test/fixtures directory. '
      'Run tests from the package root.',
    );
  }
}
