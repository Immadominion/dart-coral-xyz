/// Accounts Coder Factory
///
/// Picks the correct [AccountsCoder] implementation based on the IDL format:
/// - **Anchor** → [BorshAccountsCoder] (Borsh deserialization)
/// - **Quasar** → [ZeroCopyAccountsCoder] (`#[repr(C)]` byte-offset reads)
/// - **Manual** → defaults to [ZeroCopyAccountsCoder]
library;

import '../idl/idl.dart';
import 'borsh_accounts_coder.dart';
import 'zero_copy_coder.dart';

/// Create the appropriate accounts coder for the given IDL.
///
/// ```dart
/// final coder = AccountsCoderFactory.create(idl);
/// final account = coder.decode('MyAccount', data);
/// ```
class AccountsCoderFactory {
  AccountsCoderFactory._();

  /// Auto-detect and create the right accounts coder.
  static AccountsCoder<String> create(Idl idl) {
    switch (idl.format) {
      case IdlFormat.anchor:
        return BorshAccountsCoder<String>(idl);
      case IdlFormat.quasar:
        return ZeroCopyAccountsCoder<String>(idl);
      case IdlFormat.manual:
      case IdlFormat.codama:
        // Manual/Codama IDLs are typically for Pinocchio/custom programs — use
        // zero-copy by default since it handles both fixed and dynamic types.
        return ZeroCopyAccountsCoder<String>(idl);
    }
  }

  /// Force a specific coder regardless of IDL format.
  static AccountsCoder<String> borsh(Idl idl) =>
      BorshAccountsCoder<String>(idl);

  static AccountsCoder<String> zeroCopy(Idl idl) =>
      ZeroCopyAccountsCoder<String>(idl);
}
