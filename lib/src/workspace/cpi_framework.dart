/// Cross-Program Invocation (CPI) framework for complex program interactions.
///
/// This module provides comprehensive CPI support matching TypeScript's
/// cross-program invocation capabilities and patterns, including account
/// dependency tracking, signer propagation, and transaction composition.
library;

import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import '../types/public_key.dart';
import '../types/keypair.dart';
import '../types/transaction.dart';
import '../program/program_class.dart';
import '../provider/provider.dart';
import '../error/anchor_error.dart';
import 'program_manager.dart';

/// Exception thrown during CPI operations.
class CpiException extends AnchorError {
  CpiException(String message, {ErrorCode? errorCode, FileLine? fileLine})
      : super(
          error: ErrorInfo(
            errorCode: errorCode ?? ErrorCode(code: 'CpiError', number: 6000),
            errorMessage: message,
            origin: fileLine != null ? FileLineOrigin(fileLine) : null,
          ),
          errorLogs: [message],
          logs: [message],
        );
}

/// Authority delegation information for CPI calls.
class CpiAuthority {
  /// The authority public key.
  final PublicKey publicKey;

  /// Whether this authority is a signer.
  final bool isSigner;

  /// Whether this authority is mutable.
  final bool isMutable;

  /// Seeds for PDA authorities.
  final List<List<int>>? seeds;

  /// Program ID for PDA authorities.
  final PublicKey? programId;

  const CpiAuthority({
    required this.publicKey,
    this.isSigner = false,
    this.isMutable = false,
    this.seeds,
    this.programId,
  });

  /// Create a signer authority.
  factory CpiAuthority.signer(PublicKey publicKey) {
    return CpiAuthority(publicKey: publicKey, isSigner: true);
  }

  /// Create a mutable authority.
  factory CpiAuthority.mutable(PublicKey publicKey) {
    return CpiAuthority(publicKey: publicKey, isMutable: true);
  }

  /// Create a PDA authority.
  factory CpiAuthority.pda({
    required PublicKey publicKey,
    required List<List<int>> seeds,
    required PublicKey programId,
    bool isSigner = false,
    bool isMutable = false,
  }) {
    return CpiAuthority(
      publicKey: publicKey,
      isSigner: isSigner,
      isMutable: isMutable,
      seeds: seeds,
      programId: programId,
    );
  }

  /// Check if this is a PDA authority.
  bool get isPda => seeds != null && programId != null;

  @override
  String toString() {
    final flags = <String>[];
    if (isSigner) flags.add('signer');
    if (isMutable) flags.add('mutable');
    if (isPda) flags.add('pda');

    return 'CpiAuthority(${publicKey.toBase58()}${flags.isNotEmpty ? ', ${flags.join(', ')}' : ''})';
  }
}

/// Account dependency information for CPI calls.
class CpiAccountDependency {
  /// The account public key.
  final PublicKey publicKey;

  /// The program that owns this account.
  final PublicKey? owner;

  /// Whether this account is required.
  final bool isRequired;

  /// Whether this account should be validated.
  final bool shouldValidate;

  /// Expected account data size.
  final int? expectedSize;

  /// Account discriminator for validation.
  final List<int>? discriminator;

  const CpiAccountDependency({
    required this.publicKey,
    this.owner,
    this.isRequired = true,
    this.shouldValidate = true,
    this.expectedSize,
    this.discriminator,
  });

  @override
  String toString() => 'CpiAccountDependency(${publicKey.toBase58()})';
}

/// Configuration for CPI operations.
class CpiConfig {
  /// Maximum number of nested CPI calls allowed.
  final int maxDepth;

  /// Enable automatic account validation.
  final bool enableAccountValidation;

  /// Enable signer propagation.
  final bool enableSignerPropagation;

  /// Enable transaction composition optimization.
  final bool enableOptimization;

  /// Enable CPI debugging and tracing.
  final bool enableDebugging;

  /// Maximum number of accounts per CPI call.
  final int maxAccountsPerCall;

  const CpiConfig({
    this.maxDepth = 10,
    this.enableAccountValidation = true,
    this.enableSignerPropagation = true,
    this.enableOptimization = true,
    this.enableDebugging = false,
    this.maxAccountsPerCall = 255,
  });

  /// Default configuration for most use cases.
  static const CpiConfig defaultConfig = CpiConfig();

  /// Production configuration with optimizations.
  static const CpiConfig production = CpiConfig(
    enableAccountValidation: true,
    enableSignerPropagation: true,
    enableOptimization: true,
    enableDebugging: false,
  );

  /// Development configuration with debugging.
  static const CpiConfig development = CpiConfig(
    enableAccountValidation: true,
    enableSignerPropagation: true,
    enableOptimization: false,
    enableDebugging: true,
  );
}

/// CPI invocation context with account and authority information.
class CpiInvocationContext {
  /// The target program for the CPI call.
  final PublicKey programId;

  /// The instruction to invoke.
  final String instructionName;

  /// Instruction arguments.
  final Map<String, dynamic> arguments;

  /// Account dependencies.
  final List<CpiAccountDependency> accounts;

  /// Authority information.
  final List<CpiAuthority> authorities;

  /// Signers for this invocation.
  final List<Keypair> signers;

  /// Nested CPI contexts.
  final List<CpiInvocationContext> nestedInvocations;

  /// Additional metadata.
  final Map<String, dynamic> metadata;

  const CpiInvocationContext({
    required this.programId,
    required this.instructionName,
    this.arguments = const {},
    this.accounts = const [],
    this.authorities = const [],
    this.signers = const [],
    this.nestedInvocations = const [],
    this.metadata = const {},
  });

  /// Create a copy with modified properties.
  CpiInvocationContext copyWith({
    PublicKey? programId,
    String? instructionName,
    Map<String, dynamic>? arguments,
    List<CpiAccountDependency>? accounts,
    List<CpiAuthority>? authorities,
    List<Keypair>? signers,
    List<CpiInvocationContext>? nestedInvocations,
    Map<String, dynamic>? metadata,
  }) {
    return CpiInvocationContext(
      programId: programId ?? this.programId,
      instructionName: instructionName ?? this.instructionName,
      arguments: arguments ?? this.arguments,
      accounts: accounts ?? this.accounts,
      authorities: authorities ?? this.authorities,
      signers: signers ?? this.signers,
      nestedInvocations: nestedInvocations ?? this.nestedInvocations,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Get the total depth of nested invocations.
  int get depth {
    if (nestedInvocations.isEmpty) return 1;
    return 1 +
        nestedInvocations
            .map((ctx) => ctx.depth)
            .reduce((a, b) => a > b ? a : b);
  }

  /// Get all account dependencies including nested ones.
  List<CpiAccountDependency> get allAccounts {
    final allAccounts = List<CpiAccountDependency>.from(accounts);
    for (final nested in nestedInvocations) {
      allAccounts.addAll(nested.allAccounts);
    }
    return allAccounts;
  }

  /// Get all authorities including nested ones.
  List<CpiAuthority> get allAuthorities {
    final allAuthorities = List<CpiAuthority>.from(authorities);
    for (final nested in nestedInvocations) {
      allAuthorities.addAll(nested.allAuthorities);
    }
    return allAuthorities;
  }

  /// Get all signers including nested ones.
  List<Keypair> get allSigners {
    final allSigners = List<Keypair>.from(signers);
    for (final nested in nestedInvocations) {
      allSigners.addAll(nested.allSigners);
    }
    return allSigners;
  }

  @override
  String toString() {
    return 'CpiInvocationContext(${programId.toBase58()}::$instructionName, depth: $depth)';
  }
}

/// Result of CPI validation.
class CpiValidationResult {
  /// Whether the validation passed.
  final bool isValid;

  /// Validation errors.
  final List<String> errors;

  /// Validation warnings.
  final List<String> warnings;

  /// Validation metadata.
  final Map<String, dynamic> metadata;

  const CpiValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
    this.metadata = const {},
  });

  /// Create a successful validation result.
  factory CpiValidationResult.success({
    List<String>? warnings,
    Map<String, dynamic>? metadata,
  }) {
    return CpiValidationResult(
      isValid: true,
      warnings: warnings ?? [],
      metadata: metadata ?? {},
    );
  }

  /// Create a failed validation result.
  factory CpiValidationResult.failure({
    required List<String> errors,
    List<String>? warnings,
    Map<String, dynamic>? metadata,
  }) {
    return CpiValidationResult(
      isValid: false,
      errors: errors,
      warnings: warnings ?? [],
      metadata: metadata ?? {},
    );
  }

  @override
  String toString() {
    final status = isValid ? 'VALID' : 'INVALID';
    final errorCount = errors.length;
    final warningCount = warnings.length;
    return 'CpiValidationResult($status, errors: $errorCount, warnings: $warningCount)';
  }
}

/// Statistics for CPI operations.
class CpiStatistics {
  /// Total number of CPI calls executed.
  int totalCalls = 0;

  /// Total number of successful calls.
  int successfulCalls = 0;

  /// Total number of failed calls.
  int failedCalls = 0;

  /// Average execution time in milliseconds.
  double averageExecutionTime = 0.0;

  /// Maximum depth encountered.
  int maxDepthEncountered = 0;

  /// Total number of accounts processed.
  int totalAccountsProcessed = 0;

  /// Total number of authorities handled.
  int totalAuthoritiesHandled = 0;

  /// Get success rate as percentage.
  double get successRate {
    if (totalCalls == 0) return 0.0;
    return (successfulCalls / totalCalls) * 100.0;
  }

  /// Reset all statistics.
  void reset() {
    totalCalls = 0;
    successfulCalls = 0;
    failedCalls = 0;
    averageExecutionTime = 0.0;
    maxDepthEncountered = 0;
    totalAccountsProcessed = 0;
    totalAuthoritiesHandled = 0;
  }

  @override
  String toString() {
    return 'CpiStatistics(calls: $totalCalls, success: ${successRate.toStringAsFixed(1)}%, avg: ${averageExecutionTime.toStringAsFixed(2)}ms)';
  }
}

/// CPI instruction builder with dependency tracking and validation.
class CpiBuilder {
  /// Configuration for CPI operations.
  final CpiConfig config;

  /// Program manager for multi-program coordination.
  final ProgramManager programManager;

  /// Current invocation context being built.
  CpiInvocationContext? _currentContext;

  /// Stack of nested contexts.
  final List<CpiInvocationContext> _contextStack = [];

  /// Account dependency graph.
  final Map<PublicKey, Set<PublicKey>> _accountDependencies = {};

  /// Authority mapping.
  final Map<PublicKey, CpiAuthority> _authorities = {};

  /// Collected signers.
  final Set<Keypair> _signers = <Keypair>{};

  CpiBuilder({
    required this.programManager,
    CpiConfig? config,
  }) : config = config ?? CpiConfig.defaultConfig;

  /// Start building a CPI invocation.
  CpiBuilder invoke(
    String programName,
    String instructionName, {
    Map<String, dynamic>? arguments,
  }) {
    final program = programManager.registry.getProgram(programName);
    if (program == null) {
      throw CpiException('Program not found: $programName');
    }

    final context = CpiInvocationContext(
      programId: program.programId,
      instructionName: instructionName,
      arguments: arguments ?? {},
    );

    if (_currentContext != null) {
      _contextStack.add(_currentContext!);
    }

    _currentContext = context;
    return this;
  }

  /// Add account dependency.
  CpiBuilder account(
    String name,
    PublicKey publicKey, {
    PublicKey? owner,
    bool isRequired = true,
    bool shouldValidate = true,
    int? expectedSize,
    List<int>? discriminator,
  }) {
    if (_currentContext == null) {
      throw CpiException('No active CPI invocation context');
    }

    final dependency = CpiAccountDependency(
      publicKey: publicKey,
      owner: owner,
      isRequired: isRequired,
      shouldValidate: shouldValidate,
      expectedSize: expectedSize,
      discriminator: discriminator,
    );

    _currentContext = _currentContext!.copyWith(
      accounts: [..._currentContext!.accounts, dependency],
      arguments: {..._currentContext!.arguments, name: publicKey},
    );

    return this;
  }

  /// Add authority information.
  CpiBuilder authority(
    String name,
    CpiAuthority authority,
  ) {
    if (_currentContext == null) {
      throw CpiException('No active CPI invocation context');
    }

    _authorities[authority.publicKey] = authority;

    _currentContext = _currentContext!.copyWith(
      authorities: [..._currentContext!.authorities, authority],
      arguments: {..._currentContext!.arguments, name: authority.publicKey},
    );

    return this;
  }

  /// Add signer.
  CpiBuilder signer(Keypair keypair) {
    if (_currentContext == null) {
      throw CpiException('No active CPI invocation context');
    }

    _signers.add(keypair);

    _currentContext = _currentContext!.copyWith(
      signers: [..._currentContext!.signers, keypair],
    );

    return this;
  }

  /// Add multiple signers.
  CpiBuilder signers(List<Keypair> keypairs) {
    for (final keypair in keypairs) {
      signer(keypair);
    }
    return this;
  }

  /// Add metadata.
  CpiBuilder metadata(String key, dynamic value) {
    if (_currentContext == null) {
      throw CpiException('No active CPI invocation context');
    }

    _currentContext = _currentContext!.copyWith(
      metadata: {..._currentContext!.metadata, key: value},
    );

    return this;
  }

  /// Finish the current CPI invocation.
  CpiBuilder endInvoke() {
    if (_currentContext == null) {
      throw CpiException('No active CPI invocation context');
    }

    if (_contextStack.isNotEmpty) {
      final parentContext = _contextStack.removeLast();
      final nestedInvocations = [
        ...parentContext.nestedInvocations,
        _currentContext!
      ];

      _currentContext = parentContext.copyWith(
        nestedInvocations: nestedInvocations,
      );
    }

    return this;
  }

  /// Build the complete CPI invocation context.
  CpiInvocationContext build() {
    if (_currentContext == null) {
      throw CpiException('No CPI invocation context to build');
    }

    if (_contextStack.isNotEmpty) {
      throw CpiException(
          'Unclosed nested CPI invocations: ${_contextStack.length}');
    }

    return _currentContext!;
  }

  /// Clear the builder state.
  void clear() {
    _currentContext = null;
    _contextStack.clear();
    _accountDependencies.clear();
    _authorities.clear();
    _signers.clear();
  }
}

/// CPI coordinator for managing complex cross-program invocations.
class CpiCoordinator {
  /// Configuration for CPI operations.
  final CpiConfig config;

  /// Program manager for multi-program coordination.
  final ProgramManager programManager;

  /// Provider for transaction execution.
  final AnchorProvider provider;

  /// Statistics tracking.
  final CpiStatistics _statistics = CpiStatistics();

  CpiCoordinator({
    required this.programManager,
    required this.provider,
    CpiConfig? config,
  }) : config = config ?? CpiConfig.defaultConfig;

  /// Get current statistics.
  CpiStatistics get statistics => _statistics;

  /// Validate a CPI invocation context.
  CpiValidationResult validateInvocation(CpiInvocationContext context) {
    final errors = <String>[];
    final warnings = <String>[];

    // Check depth limit
    if (context.depth > config.maxDepth) {
      errors
          .add('CPI depth ${context.depth} exceeds maximum ${config.maxDepth}');
    }

    // Check account limit
    final totalAccounts = context.allAccounts.length;
    if (totalAccounts > config.maxAccountsPerCall) {
      errors.add(
          'Total accounts $totalAccounts exceeds maximum ${config.maxAccountsPerCall}');
    }

    // Validate program exists
    final program =
        programManager.registry.getProgram(context.programId.toBase58());
    if (program == null) {
      // Try to find by program ID
      final programsByAddress =
          programManager.registry.getProgramsById(context.programId);
      if (programsByAddress.isEmpty) {
        errors.add('Program not found: ${context.programId.toBase58()}');
      }
    }

    // Check for circular dependencies
    final visited = <PublicKey>{};
    final visiting = <PublicKey>{};

    bool hasCircularDependency(PublicKey programId) {
      if (visiting.contains(programId)) {
        return true;
      }
      if (visited.contains(programId)) {
        return false;
      }

      visiting.add(programId);

      // Check nested invocations
      for (final nested in context.nestedInvocations) {
        if (hasCircularDependency(nested.programId)) {
          return true;
        }
      }

      visiting.remove(programId);
      visited.add(programId);
      return false;
    }

    if (hasCircularDependency(context.programId)) {
      errors.add('Circular dependency detected in CPI call chain');
    }

    // Validate authorities
    for (final authority in context.allAuthorities) {
      if (authority.isPda && authority.seeds == null) {
        errors.add(
            'PDA authority missing seeds: ${authority.publicKey.toBase58()}');
      }

      if (authority.isPda && authority.programId == null) {
        errors.add(
            'PDA authority missing program ID: ${authority.publicKey.toBase58()}');
      }
    }

    // Validate account dependencies
    if (config.enableAccountValidation) {
      for (final account in context.allAccounts) {
        if (account.isRequired &&
            account.discriminator != null &&
            account.discriminator!.isEmpty) {
          warnings.add(
              'Required account has empty discriminator: ${account.publicKey.toBase58()}');
        }
      }
    }

    if (errors.isNotEmpty) {
      return CpiValidationResult.failure(
        errors: errors,
        warnings: warnings,
      );
    }

    return CpiValidationResult.success(
      warnings: warnings,
    );
  }

  /// Execute a CPI invocation.
  Future<String> executeInvocation(CpiInvocationContext context) async {
    final startTime = DateTime.now();

    try {
      _statistics.totalCalls++;

      // Validate the invocation
      final validation = validateInvocation(context);
      if (!validation.isValid) {
        throw CpiException(
            'CPI validation failed: ${validation.errors.join(', ')}');
      }

      // Update statistics
      _statistics.maxDepthEncountered =
          _statistics.maxDepthEncountered < context.depth
              ? context.depth
              : _statistics.maxDepthEncountered;
      _statistics.totalAccountsProcessed += context.allAccounts.length;
      _statistics.totalAuthoritiesHandled += context.allAuthorities.length;

      // Get the target program
      final program = _getProgram(context.programId);
      if (program == null) {
        throw CpiException(
            'Program not found: ${context.programId.toBase58()}');
      }

      // Build the instruction
      final instruction = await _buildInstruction(context, program);

      // Create transaction
      final transaction = Transaction(instructions: [instruction]);

      // Add all signers
      final allSigners = context.allSigners;

      // Execute transaction
      final signature = await provider.sendAndConfirm(
        transaction,
        signers: allSigners,
      );

      _statistics.successfulCalls++;

      return signature;
    } catch (error) {
      _statistics.failedCalls++;
      rethrow;
    } finally {
      final endTime = DateTime.now();
      final executionTime =
          endTime.difference(startTime).inMilliseconds.toDouble();

      // Update average execution time
      final totalSuccessful =
          _statistics.successfulCalls + _statistics.failedCalls;
      if (totalSuccessful > 1) {
        _statistics.averageExecutionTime =
            ((_statistics.averageExecutionTime * (totalSuccessful - 1)) +
                    executionTime) /
                totalSuccessful;
      } else {
        _statistics.averageExecutionTime = executionTime;
      }
    }
  }

  /// Create a new CPI builder.
  CpiBuilder builder() {
    return CpiBuilder(
      programManager: programManager,
      config: config,
    );
  }

  /// Execute a complex CPI transaction with multiple invocations.
  Future<List<String>> executeBatch(List<CpiInvocationContext> contexts) async {
    final signatures = <String>[];

    for (final context in contexts) {
      final signature = await executeInvocation(context);
      signatures.add(signature);
    }

    return signatures;
  }

  /// Reset statistics.
  void resetStatistics() {
    _statistics.reset();
  }

  // Private helper methods

  Program? _getProgram(PublicKey programId) {
    // First try to find by program ID
    final programs = programManager.registry.getProgramsById(programId);
    if (programs.isNotEmpty) {
      return programs.first;
    }

    // Try to find by name
    for (final name in programManager.registry.programNames) {
      final program = programManager.registry.getProgram(name);
      if (program?.programId == programId) {
        return program;
      }
    }

    return null;
  }

  Future<TransactionInstruction> _buildInstruction(
    CpiInvocationContext context,
    Program program,
  ) async {
    // This would integrate with the program's instruction builder
    // For now, create a placeholder instruction

    final accounts = <AccountMeta>[];

    // Add account metas from context
    for (final account in context.accounts) {
      final authority = context.authorities
          .where((auth) => auth.publicKey == account.publicKey)
          .firstOrNull;

      accounts.add(AccountMeta(
        pubkey: account.publicKey,
        isSigner: authority?.isSigner ?? false,
        isWritable: authority?.isMutable ?? false,
      ));
    }

    // Add authority account metas
    for (final authority in context.authorities) {
      if (!accounts.any((acc) => acc.pubkey == authority.publicKey)) {
        accounts.add(AccountMeta(
          pubkey: authority.publicKey,
          isSigner: authority.isSigner,
          isWritable: authority.isMutable,
        ));
      }
    }

    // Create instruction data (this would use the actual instruction coder)
    final data = <int>[]; // Placeholder

    return TransactionInstruction(
      accounts: accounts,
      programId: context.programId,
      data: Uint8List.fromList(data),
    );
  }
}

/// Comprehensive CPI framework for cross-program invocations.
class CpiFramework {
  /// Program manager for multi-program coordination.
  final ProgramManager programManager;

  /// Provider for transaction execution.
  final AnchorProvider provider;

  /// Configuration for CPI operations.
  final CpiConfig config;

  /// CPI coordinator instance.
  late final CpiCoordinator _coordinator;

  CpiFramework({
    required this.programManager,
    required this.provider,
    CpiConfig? config,
  }) : config = config ?? CpiConfig.defaultConfig {
    _coordinator = CpiCoordinator(
      programManager: programManager,
      provider: provider,
      config: this.config,
    );
  }

  /// Get the CPI coordinator.
  CpiCoordinator get coordinator => _coordinator;

  /// Create a new CPI builder.
  CpiBuilder builder() => _coordinator.builder();

  /// Execute a CPI invocation.
  Future<String> execute(CpiInvocationContext context) {
    return _coordinator.executeInvocation(context);
  }

  /// Execute multiple CPI invocations.
  Future<List<String>> executeBatch(List<CpiInvocationContext> contexts) {
    return _coordinator.executeBatch(contexts);
  }

  /// Validate a CPI invocation.
  CpiValidationResult validate(CpiInvocationContext context) {
    return _coordinator.validateInvocation(context);
  }

  /// Get CPI statistics.
  CpiStatistics get statistics => _coordinator.statistics;

  /// Reset statistics.
  void resetStatistics() => _coordinator.resetStatistics();
}
