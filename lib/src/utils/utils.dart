/// Utility functions and helper classes
///
/// Matches TypeScript Anchor SDK utils.* module structure.
/// Uses espresso-cash-public packages for proven implementations.
library;

// Re-export PDA utilities from program module for convenience
export '../program/pda_utils.dart' hide AddressValidator;

// Core utilities matching TypeScript utils.* structure
export 'address.dart'; // Address, seed, and PDA utilities
export 'binary_reader.dart'; // Borsh deserialization
export 'binary_writer.dart'; // Borsh serialization
export 'features.dart'; // Feature flag management
export 'registry.dart'; // Anchor registry and verified builds
export 'token.dart'; // SPL Token utilities (via espresso-cash)
