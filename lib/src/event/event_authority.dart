/// EventAuthority PDA utility for Quasar CPI-based events
///
/// Quasar programs use a deterministic `EventAuthority` PDA to prevent event
/// spoofing when emitting events via CPI (`emit_cpi!`). The on-chain handler
/// verifies that the CPI caller is the program's own `EventAuthority` PDA
/// before logging the event data.
///
/// The PDA is derived from the seed `"__event_authority"` and the program ID.
library;

import '../pda/pda_derivation_engine.dart';
import '../types/public_key.dart' hide PdaResult;

/// Utility for deriving and working with EventAuthority PDAs.
///
/// Usage:
/// ```dart
/// final authority = EventAuthority.derive(programId);
/// print(authority.address);  // PublicKey
/// print(authority.bump);     // int
/// ```
class EventAuthority {
  const EventAuthority._({required this.address, required this.bump});

  /// The seed used to derive the EventAuthority PDA.
  static const String seed = '__event_authority';

  /// The EventAuthority public key.
  final PublicKey address;

  /// The bump seed used in the PDA derivation.
  final int bump;

  /// Derive the EventAuthority PDA for a given [programId].
  ///
  /// This mirrors Quasar's compile-time derivation:
  /// ```rust
  /// const __PDA: (Address, u8) = find_program_address_const(
  ///     &[b"__event_authority"],
  ///     &crate::ID,
  /// );
  /// ```
  static EventAuthority derive(PublicKey programId) {
    final result = PdaDerivationEngine.findProgramAddress([
      StringSeed(seed),
    ], programId);
    return EventAuthority._(address: result.address, bump: result.bump);
  }

  /// Check whether [accountAddress] matches the EventAuthority for [programId].
  static bool verify(PublicKey accountAddress, PublicKey programId) {
    final authority = derive(programId);
    return authority.address == accountAddress;
  }

  @override
  String toString() =>
      'EventAuthority(address: ${address.toBase58()}, bump: $bump)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventAuthority && address == other.address && bump == other.bump;

  @override
  int get hashCode => address.hashCode ^ bump.hashCode;
}
