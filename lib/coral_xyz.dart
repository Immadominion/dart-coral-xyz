/// Dart client for Solana programs — Anchor, Quasar, and Pinocchio.
///
/// Provides runtime IDL parsing, Borsh serialization, zero-copy account
/// decoding, PDA derivation, and fluent method builders for interacting
/// with on-chain programs.
///
/// ```dart
/// import 'package:coral_xyz/coral_xyz.dart';
///
/// final idl = Idl.fromJson(jsonDecode(idlString));
/// final program = Program(idl, programId, provider);
///
/// await program.methods['initialize']!([])
///   .accounts({'counter': counterAddress})
///   .rpc();
///
/// final data = await program.account['Counter']!.fetch(counterAddress);
/// ```
library coral_xyz;

// IDL
export 'src/idl/idl.dart';
export 'src/idl/idl_utils.dart';
export 'src/idl/codama_parser.dart';

// Coders
export 'src/coder/coder.dart';
export 'src/coder/event_coder.dart';
export 'src/coder/instruction_coder.dart';
export 'src/coder/type_converter.dart';
export 'src/coder/types_coder.dart';

// Program
export 'src/program/program.dart';
export 'src/program/program_class.dart';
export 'src/program/program_interface.dart';
export 'src/program/type_safe_method_builder.dart';
export 'src/program/accounts_resolver.dart';
export 'src/program/common.dart' show ProgramCommon, NodeWallet;
export 'src/program/context.dart' hide ConfirmOptions, Context, Accounts;
export 'src/program/pda_utils.dart' show PdaUtils, AddressResolver;

// Namespaces
export 'src/program/namespace/namespace_factory.dart';
export 'src/program/namespace/account_fetcher.dart'
    show AccountFetcher, AccountFetcherConfig, ProgramAccount;
export 'src/program/namespace/account_namespace.dart'
    show AccountNamespace, AccountClient;
export 'src/program/namespace/instruction_namespace.dart'
    show InstructionNamespace;
export 'src/program/namespace/methods_namespace.dart' show MethodsNamespace;
export 'src/program/namespace/rpc_namespace.dart' show RpcNamespace;
export 'src/program/namespace/simulate_namespace.dart' show SimulateNamespace;
export 'src/program/namespace/transaction_namespace.dart'
    show TransactionNamespace;
export 'src/program/namespace/views_namespace.dart' show ViewsNamespace;
export 'src/program/namespace/types.dart'
    hide SimulationResult, TransactionInstruction, AccountMeta, Context, Accounts;

// Provider
export 'src/provider/connection.dart' show Connection;
export 'src/provider/provider.dart'
    show
        Wallet,
        KeypairWallet,
        ConfirmOptions,
        TransactionWithSigners,
        ProviderException,
        ProviderTransactionException,
        AnchorProvider;
export 'src/provider/wallet.dart'
    hide
        WalletException,
        WalletUserRejectedException,
        WalletNotConnectedException,
        WalletNotAvailableException,
        WalletAdapter,
        AdapterWallet;

// PDA
export 'src/pda/pda_derivation_engine.dart' hide PdaUtils, PdaResult;
export 'src/pda/pda_seed_resolver.dart';

// Types
export 'src/types/public_key.dart';
export 'src/types/transaction.dart'
    hide TransactionInstruction, AccountMeta, Transaction;
export 'src/types/types.dart'
    hide AccountMeta, TransactionInstruction, Transaction;

// Errors
export 'src/error/error.dart';

// Events
export 'src/event/event.dart' hide LogsNotification;
export 'src/event/event_authority.dart';
export 'src/event/types.dart'
    show EventStats, WebSocketState, EventException, EventParseException;

// Native programs
export 'src/native/system_program.dart';

// SPL
export 'src/spl/spl.dart';

// Utilities
export 'src/utils/binary_reader.dart';
export 'src/utils/binary_writer.dart';
export 'src/utils/utils.dart';
export 'src/transaction/transaction_simulator.dart'
    hide TransactionSimulationResult;

// Codegen
export 'src/codegen/annotations.dart';

// Workspace
export 'src/workspace/workspace.dart';

// Quasar SVM — in-process Solana program execution
export 'src/svm/account_factories.dart';
export 'src/svm/execution_result.dart';
export 'src/svm/programs.dart';
export 'src/svm/quasar_svm.dart';
export 'src/svm/quasar_svm_base.dart' show QuasarSvmConfig, quasarSvmConfigFull;

import 'src/provider/anchor_provider.dart';
import 'src/workspace/workspace.dart';

/// Global workspace instance for TypeScript-like lazy program loading.
///
/// ```dart
/// final program = workspace.counterProgram;
/// ```
WorkspaceProxy get workspace => WorkspaceProxy._instance;

/// Get current global provider instance.
AnchorProvider getProvider() => AnchorProvider.defaultProvider();

/// Set the global provider instance.
void setProvider(AnchorProvider provider) {
  AnchorProvider.setDefaultProvider(provider);
  workspace.reset();
}

/// Proxy that provides dynamic program access from workspace configuration.
class WorkspaceProxy {
  static final WorkspaceProxy _instance = WorkspaceProxy._();
  WorkspaceProxy._();

  AnchorProvider get _currentProvider {
    try {
      return getProvider();
    } on ProviderException {
      return AnchorProvider.defaultProvider();
    }
  }

  Workspace? _workspace;

  Workspace get _workspaceInstance {
    return _workspace ??= Workspace(_currentProvider);
  }

  void reset() {
    _workspace = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isGetter) {
      final memberName = invocation.memberName;
      final programName = _symbolToProgramName(memberName);
      return _workspaceInstance.lazyLoadProgram(programName);
    }
    return super.noSuchMethod(invocation);
  }

  String _symbolToProgramName(Symbol symbol) {
    final s = symbol.toString();
    final match = RegExp('"(.*)"').firstMatch(s);
    return match != null ? match.group(1)! : s;
  }
}

/// Package version.
const String packageVersion = '1.0.0-beta.9';

/// Supported Anchor IDL specification version.
const String supportedIdlVersion = '0.1.0';
