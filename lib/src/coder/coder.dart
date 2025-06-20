/// Borsh serialization and encoding/decoding system
///
/// This module provides comprehensive Borsh serialization support for
/// encoding and decoding Anchor program data, instructions, and accounts.
library coder;

// Borsh serialization system (Phase 3.1 - COMPLETED)
export 'borsh_types.dart';
export 'borsh_utils.dart';

// Anchor-specific Borsh extensions (Phase 3.2 - COMPLETED)
export 'anchor_borsh.dart';

// Main coder interface
export 'main_coder.dart';

// Coders (Phase 5 - COMPLETED)
export 'instruction_coder.dart'; // Phase 5.1 - COMPLETED
export 'account_coder.dart'; // Phase 5.2 - COMPLETED
export 'event_coder.dart'; // Phase 5.3 - COMPLETED
export 'types_coder.dart'; // Phase 5.3 - COMPLETED
