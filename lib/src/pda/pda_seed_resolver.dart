/// Quasar PDA Seed Resolver
///
/// Resolves PDA seeds from Quasar IDL definitions into concrete byte arrays
/// for PDA derivation. Quasar IDL uses:
///   - `const` seeds: literal byte arrays (e.g. `[101, 115, 99, 114, 111, 119]` for "escrow")
///   - `account` seeds: references to account public keys by path (e.g. `maker`)
///   - `arg` seeds: references to instruction arguments by path
library;

import 'dart:typed_data';

import '../idl/idl.dart';
import '../types/public_key.dart' hide PdaResult;
import 'pda_derivation_engine.dart';

/// Resolves Quasar/Anchor IDL PDA definitions into derivable seed byte arrays.
///
/// ```dart
/// final seeds = PdaSeedResolver.resolveSeeds(
///   pda.seeds,
///   accounts: {'maker': makerPubkey},
///   args: {'id': 42},
/// );
/// final result = PdaDerivationEngine.findProgramAddress(seeds, programId);
/// ```
class PdaSeedResolver {
  PdaSeedResolver._();

  /// Resolve a list of [IdlSeed]s into [PdaSeed] objects ready for derivation.
  ///
  /// [seeds] — the PDA seed definitions from the IDL.
  /// [accounts] — a map of account name → [PublicKey] for `account` seeds.
  /// [args] — a map of argument name → value for `arg` seeds.
  static List<PdaSeed> resolveSeeds(
    List<IdlSeed> seeds, {
    Map<String, PublicKey> accounts = const {},
    Map<String, dynamic> args = const {},
  }) {
    return seeds.map((seed) => _resolveSeed(seed, accounts, args)).toList();
  }

  /// Resolve seeds and derive the PDA in one call.
  static PdaResult derivePda(
    IdlPda pda,
    PublicKey programId, {
    Map<String, PublicKey> accounts = const {},
    Map<String, dynamic> args = const {},
  }) {
    final resolved = resolveSeeds(pda.seeds, accounts: accounts, args: args);
    return PdaDerivationEngine.findProgramAddress(resolved, programId);
  }

  static PdaSeed _resolveSeed(
    IdlSeed seed,
    Map<String, PublicKey> accounts,
    Map<String, dynamic> args,
  ) {
    switch (seed) {
      case IdlSeedConst():
        return BytesSeed(Uint8List.fromList(seed.value));

      case IdlSeedAccount():
        final key = accounts[seed.path];
        if (key == null) {
          throw PdaDerivationException(
            'Missing account for PDA seed: "${seed.path}". '
            'Available accounts: ${accounts.keys.join(', ')}',
          );
        }
        return PublicKeySeed(key);

      case IdlSeedArg():
        final value = args[seed.path];
        if (value == null) {
          throw PdaDerivationException(
            'Missing argument for PDA seed: "${seed.path}". '
            'Available args: ${args.keys.join(', ')}',
          );
        }
        if (seed.type == null) {
          throw PdaDerivationException(
            'PDA seed "${seed.path}" has no type information. '
            'Provide the seed type in the IDL or use explicit PDA derivation.',
          );
        }
        return _argToSeed(value, seed.type!, seed.path);

      default:
        throw PdaDerivationException('Unknown seed kind: ${seed.kind}');
    }
  }

  /// Convert an instruction argument value to a PDA seed based on its IDL type.
  static PdaSeed _argToSeed(dynamic value, IdlType type, String path) {
    switch (type.kind) {
      case 'u8':
        return NumberSeed(value as int, byteLength: 1);
      case 'u16' || 'i16':
        return NumberSeed(value as int, byteLength: 2);
      case 'u32' || 'i32':
        return NumberSeed(value as int, byteLength: 4);
      case 'u64' || 'i64':
        final v = value is BigInt ? value.toInt() : value as int;
        return NumberSeed(v, byteLength: 8);
      case 'string' || 'dynString':
        return StringSeed(value as String);
      case 'publicKey' || 'pubkey':
        if (value is PublicKey) return PublicKeySeed(value);
        if (value is Uint8List) {
          return PublicKeySeed(PublicKeyUtils.fromBytes(value));
        }
        throw PdaDerivationException(
          'Arg "$path" of type publicKey must be PublicKey or Uint8List',
        );
      case 'bool':
        return BytesSeed(Uint8List.fromList([(value as bool) ? 1 : 0]));
      default:
        // For unknown types, try common conversions
        if (value is Uint8List) return BytesSeed(value);
        if (value is List<int>) {
          return BytesSeed(Uint8List.fromList(value));
        }
        if (value is String) return StringSeed(value);
        throw PdaDerivationException(
          'Cannot convert arg "$path" of type "${type.kind}" to PDA seed',
        );
    }
  }
}
