/// Utility functions and helper classes
///
/// This module contains various utility functions for working with
/// addresses, transactions, byte manipulation, PDAs, multisig operations,
/// and other common operations that match the TypeScript Anchor SDK.
library;

// Address and key utilities (Phase 10.1 - COMPLETED)
export 'address.dart';

// PublicKey utilities (matching TypeScript utils.publicKey)
export 'pubkey.dart';

// Multisig utilities for multisig program patterns
export 'multisig.dart';

// Data conversion utilities (Phase 10.2 - COMPLETED)
export 'data_conversion.dart';

// RPC and network utilities (Phase 10.3 - COMPLETED)
export 'rpc_utils.dart';

// Re-export PDA utilities from program module for convenience
export '../program/pda_utils.dart' hide AddressValidator;
