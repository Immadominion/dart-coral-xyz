/// Program constants and ELF loading helpers for the Quasar SVM.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../types/public_key.dart';

// ---------------------------------------------------------------------------
// Program IDs
// ---------------------------------------------------------------------------

/// SPL Token program ID.
final PublicKey splTokenProgramId = PublicKeyUtils.fromBase58(
  'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',
);

/// SPL Token-2022 program ID.
final PublicKey splToken2022ProgramId = PublicKeyUtils.fromBase58(
  'TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb',
);

/// SPL Associated Token Account program ID.
final PublicKey splAssociatedTokenProgramId = PublicKeyUtils.fromBase58(
  'ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL',
);

/// System program ID.
final PublicKey systemProgramId = PublicKeyUtils.fromBase58(
  '11111111111111111111111111111111',
);

// ---------------------------------------------------------------------------
// Loader versions
// ---------------------------------------------------------------------------

/// BPF Loader v2 (used by SPL Token, SPL Associated Token).
const int loaderV2 = 2;

/// BPF Loader v3 (used by most programs, including SPL Token-2022).
const int loaderV3 = 3;

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/// Lamports per SOL.
const int lamportsPerSol = 1000000000;

// ---------------------------------------------------------------------------
// ELF loading
// ---------------------------------------------------------------------------

/// Load a program ELF file by name from the known program directory.
///
/// Search order:
/// 1. `<cwd>/quasar-svm/svm/programs/<name>`
/// 2. `<cwd>/../quasar-svm/svm/programs/<name>`
/// 3. `<cwd>/programs/<name>` (for CI/custom setups)
Uint8List loadElf(String name) {
  final candidates = [
    p.join(p.current, 'quasar-svm', 'svm', 'programs', name),
    p.join(p.current, '..', 'quasar-svm', 'svm', 'programs', name),
    p.join(p.current, 'programs', name),
  ];

  for (final path in candidates) {
    final file = File(path);
    if (file.existsSync()) {
      return file.readAsBytesSync();
    }
  }

  throw StateError(
    'Could not find program ELF "$name". Searched:\n'
    '${candidates.map((c) => '  - $c').join('\n')}\n'
    '\n'
    'The .so files should be in quasar-svm/svm/programs/',
  );
}
