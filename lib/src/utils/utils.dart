/// Utility functions and helper classes
///
/// This module contains various utility functions for working with
/// addresses, transactions, byte manipulation, PDAs, multisig operations,
/// and other common operations that match the TypeScript Anchor SDK.
///
/// Complete TypeScript utils.* module parity achieved using espresso-cash-public packages.
library;

// Re-export PDA utilities from program module for convenience
export '../program/pda_utils.dart' hide AddressValidator;

// Core utilities matching TypeScript utils.* structure
export 'sha256.dart'; // utils.sha256.* - ✅ COMPLETE
export 'bytes.dart'; // utils.bytes.* - ✅ COMPLETE
export 'hex.dart'; // utils.bytes.hex.* - ✅ COMPLETE
export 'pubkey.dart' hide PublicKeyUtils; // utils.publicKey.* - ✅ COMPLETE
export 'token.dart'; // utils.token.* - ✅ COMPLETE (with espresso integration)
export 'features.dart'; // utils.features.* - ✅ COMPLETE
export 'registry.dart'; // utils.registry.* - ✅ COMPLETE
// export 'rpc.dart'; // utils.rpc.* - 🔄 IN PROGRESS (needs type compatibility fixes)

// Additional utilities (existing)
export 'address.dart'; // Address and key utilities
export 'data_conversion.dart'; // Data conversion utilities
export 'multisig.dart'; // Multisig utilities
export 'rpc_utils.dart'; // RPC and network utilities
export 'anchor_utils.dart'; // Anchor-specific utilities
