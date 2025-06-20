/// External package wrappers and adapters
///
/// This module provides a consistent interface to external packages
/// and ensures that the core library is not tightly coupled to specific
/// implementations. It allows for easy replacement or upgrade of external
/// dependencies without affecting the rest of the codebase.
library;

export 'solana_rpc_wrapper.dart';
export 'borsh_wrapper.dart';
export 'crypto_wrapper.dart';
export 'encoding_wrapper.dart';
