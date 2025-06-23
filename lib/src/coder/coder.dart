/// Borsh serialization and encoding/decoding system
///
/// This module provides comprehensive Borsh serialization support for
/// encoding and decoding Anchor program data, instructions, and accounts.
library coder;

// Core discriminator computation engine (Phase 1.1 - COMPLETED)
export 'discriminator_computer.dart';

// Discriminator caching and performance layer (Phase 1.2 - COMPLETED)
export 'discriminator_cache.dart';

// Discriminator validation framework (Phase 1.3 - COMPLETED)
export 'discriminator_validator.dart';

// Account ownership validation engine (Phase 1.4 - COMPLETED)
export 'account_ownership_validator.dart';

// Account size and structure validation (Phase 1.5 - COMPLETED)
export 'account_size_validator.dart';

// BorshAccountsCoder core implementation (Phase 2.2 - COMPLETED)
export 'borsh_accounts_coder.dart';

// Borsh serialization system (Phase 3.1 - COMPLETED)
export 'borsh_types.dart';
export 'borsh_utils.dart';

// Anchor-specific Borsh extensions (Phase 3.2 - COMPLETED)
export 'anchor_borsh.dart';

// Main coder interface
export 'main_coder.dart';

// Coders (Phase 5 - COMPLETED)
export 'instruction_coder.dart'; // Phase 5.1 - COMPLETED
// account_coder.dart removed - using borsh_accounts_coder.dart as canonical implementation
export 'event_coder.dart'; // Phase 5.3 - COMPLETED
export 'types_coder.dart'; // Phase 5.3 - COMPLETED
