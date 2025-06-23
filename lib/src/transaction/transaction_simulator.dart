import 'dart:convert';
import 'dart:typed_data';

import '../types/public_key.dart';
import '../types/transaction.dart' as transaction_types;
import '../types/keypair.dart';
import '../provider/anchor_provider.dart';
import '../utils/rpc_utils.dart';
import '../provider/connection.dart';
import 'preflight_validator.dart';
import 'simulation_result_processor.dart';

/// Transaction simulation configuration
class TransactionSimulationConfig {
  /// Commitment level for simulation
  final String? commitment;

  /// Whether to include account information in response
  final bool includeAccounts;

  /// Specific accounts to include in response
  final List<PublicKey>? accountsToInclude;

  /// Whether to verify signatures during simulation
  final bool sigVerify;

  /// Whether to replace recent blockhash with simulation blockhash
  final bool replaceRecentBlockhash;

  /// Account encoding format (base58, base64, jsonParsed)
  final String encoding;

  /// Minimum context slot for simulation
  final int? minContextSlot;

  const TransactionSimulationConfig({
    this.commitment,
    this.includeAccounts = false,
    this.accountsToInclude,
    this.sigVerify = false,
    this.replaceRecentBlockhash = false,
    this.encoding = 'base64',
    this.minContextSlot,
  });

  /// Create default configuration
  factory TransactionSimulationConfig.defaultConfig() {
    return const TransactionSimulationConfig();
  }

  /// Create configuration for account inclusion
  factory TransactionSimulationConfig.withAccounts(List<PublicKey> accounts) {
    return TransactionSimulationConfig(
      includeAccounts: true,
      accountsToInclude: accounts,
    );
  }

  /// Create configuration with signature verification
  factory TransactionSimulationConfig.withSigVerify() {
    return const TransactionSimulationConfig(
      sigVerify: true,
    );
  }

  /// Convert to RPC parameters
  Map<String, dynamic> toRpcParams() {
    final params = <String, dynamic>{
      'encoding': encoding,
    };

    if (commitment != null) {
      params['commitment'] = commitment;
    }

    if (includeAccounts && accountsToInclude != null) {
      params['accounts'] = {
        'encoding': encoding,
        'addresses': accountsToInclude!.map((pk) => pk.toBase58()).toList(),
      };
    }

    if (sigVerify) {
      params['sigVerify'] = true;
    }

    if (replaceRecentBlockhash) {
      params['replaceRecentBlockhash'] = true;
    }

    if (minContextSlot != null) {
      params['minContextSlot'] = minContextSlot;
    }

    return params;
  }
}

/// Transaction simulation result with comprehensive error analysis
class TransactionSimulationResult {
  /// Whether the simulation was successful
  final bool success;

  /// Program logs from simulation
  final List<String> logs;

  /// Error information if simulation failed
  final TransactionSimulationError? error;

  /// Compute units consumed during simulation
  final int? unitsConsumed;

  /// Accounts information if requested
  final Map<String, dynamic>? accounts;

  /// Return data from program execution
  final TransactionReturnData? returnData;

  /// Inner instructions executed during simulation
  final List<Map<String, dynamic>>? innerInstructions;

  const TransactionSimulationResult({
    required this.success,
    required this.logs,
    this.error,
    this.unitsConsumed,
    this.accounts,
    this.returnData,
    this.innerInstructions,
  });

  /// Create from RPC response
  factory TransactionSimulationResult.fromRpcResponse(
      Map<String, dynamic> response) {
    final value = response['value'] as Map<String, dynamic>;
    final err = value['err'];

    if (err != null) {
      return TransactionSimulationResult(
        success: false,
        logs: List<String>.from(value['logs'] ?? []),
        error: TransactionSimulationError.fromRpcError(err),
        unitsConsumed: value['unitsConsumed'] as int?,
        accounts: value['accounts'] as Map<String, dynamic>?,
      );
    }

    return TransactionSimulationResult(
      success: true,
      logs: List<String>.from(value['logs'] ?? []),
      unitsConsumed: value['unitsConsumed'] as int?,
      accounts: value['accounts'] as Map<String, dynamic>?,
      returnData: value['returnData'] != null
          ? TransactionReturnData.fromJson(value['returnData'])
          : null,
      innerInstructions: value['innerInstructions'] != null
          ? List<Map<String, dynamic>>.from(value['innerInstructions'])
          : null,
    );
  }

  @override
  String toString() {
    return 'TransactionSimulationResult(success: $success, '
        'logs: ${logs.length}, error: $error, unitsConsumed: $unitsConsumed)';
  }
}

/// Transaction simulation error with detailed context
class TransactionSimulationError {
  /// Error type (e.g., InstructionError, InvalidAccountData)
  final String type;

  /// Error details specific to the error type
  final dynamic details;

  /// Instruction index where error occurred (for InstructionError)
  final int? instructionIndex;

  /// Custom error code (for Custom errors)
  final int? customErrorCode;

  const TransactionSimulationError({
    required this.type,
    this.details,
    this.instructionIndex,
    this.customErrorCode,
  });

  /// Create from RPC error response
  factory TransactionSimulationError.fromRpcError(dynamic error) {
    if (error is Map<String, dynamic>) {
      // Handle instruction errors
      if (error.containsKey('InstructionError')) {
        final instructionError = error['InstructionError'] as List;
        final index = instructionError[0] as int;
        final errorDetails = instructionError[1];

        if (errorDetails is Map<String, dynamic> &&
            errorDetails.containsKey('Custom')) {
          return TransactionSimulationError(
            type: 'InstructionError',
            instructionIndex: index,
            customErrorCode: errorDetails['Custom'] as int,
            details: errorDetails,
          );
        }

        return TransactionSimulationError(
          type: 'InstructionError',
          instructionIndex: index,
          details: errorDetails,
        );
      }

      // Handle other error types
      final errorType = error.keys.first;
      return TransactionSimulationError(
        type: errorType,
        details: error[errorType],
      );
    }

    // Handle string errors
    return TransactionSimulationError(
      type: 'Unknown',
      details: error.toString(),
    );
  }

  @override
  String toString() {
    if (instructionIndex != null) {
      return 'TransactionSimulationError(type: $type, '
          'instructionIndex: $instructionIndex, details: $details)';
    }
    return 'TransactionSimulationError(type: $type, details: $details)';
  }
}

/// Return data from program execution
class TransactionReturnData {
  /// Program ID that returned the data
  final String programId;

  /// Returned data (base64 encoded)
  final String data;

  const TransactionReturnData({
    required this.programId,
    required this.data,
  });

  /// Create from JSON
  factory TransactionReturnData.fromJson(Map<String, dynamic> json) {
    return TransactionReturnData(
      programId: json['programId'] as String,
      data: json['data'] as String,
    );
  }

  /// Decode the returned data
  Uint8List get decodedData => base64Decode(data);

  @override
  String toString() {
    return 'TransactionReturnData(programId: $programId, data: ${data.length} bytes)';
  }
}

/// Core transaction simulation engine matching TypeScript's capabilities
class TransactionSimulator {
  final AnchorProvider _provider;
  final PreflightValidator _preflightValidator;
  final Map<String, TransactionSimulationResult> _cache = {};
  static const int _maxCacheSize = 1000;

  TransactionSimulator(this._provider)
      : _preflightValidator = PreflightValidator(_provider);

  /// Simulate a transaction with comprehensive error analysis
  Future<TransactionSimulationResult> simulate(
    transaction_types.Transaction transaction, {
    List<Keypair>? signers,
    TransactionSimulationConfig? config,
  }) async {
    config ??= TransactionSimulationConfig.defaultConfig();

    try {
      // Prepare transaction for simulation
      final preparedTransaction = await _prepareTransaction(transaction);

      // Sign transaction if signers provided
      if (signers != null && signers.isNotEmpty) {
        for (final signer in signers) {
          // TODO: Implement transaction signing when available
          // preparedTransaction = preparedTransaction.sign(signer);
          // For now, just acknowledge the signer parameter
          signer.publicKey; // Use the signer to avoid unused warning
        }
      }

      // Check cache first
      final cacheKey = _generateCacheKey(preparedTransaction, config);
      if (_cache.containsKey(cacheKey)) {
        return _cache[cacheKey]!;
      }

      // Perform simulation via RPC
      final result = await _performSimulation(preparedTransaction, config);

      // Cache result
      _addToCache(cacheKey, result);

      return result;
    } catch (error) {
      return TransactionSimulationResult(
        success: false,
        logs: ['Program log: Simulation failed'],
        error: TransactionSimulationError(
          type: 'SimulationError',
          details: error.toString(),
        ),
      );
    }
  }

  /// Simulate transaction with account state validation
  Future<TransactionSimulationResult> simulateWithAccountValidation(
    transaction_types.Transaction transaction, {
    List<Keypair>? signers,
    List<PublicKey>? requiredAccounts,
  }) async {
    final config = TransactionSimulationConfig.withAccounts(
      requiredAccounts ?? [],
    );

    return simulate(transaction, signers: signers, config: config);
  }

  /// Simulate transaction with signature verification
  Future<TransactionSimulationResult> simulateWithSigVerify(
    transaction_types.Transaction transaction, {
    List<Keypair>? signers,
  }) async {
    final config = TransactionSimulationConfig.withSigVerify();

    return simulate(transaction, signers: signers, config: config);
  }

  /// Batch simulate multiple transactions
  Future<List<TransactionSimulationResult>> simulateBatch(
    List<transaction_types.Transaction> transactions, {
    List<List<Keypair>?>? signersPerTransaction,
    TransactionSimulationConfig? config,
  }) async {
    final results = <TransactionSimulationResult>[];

    for (int i = 0; i < transactions.length; i++) {
      final signers =
          signersPerTransaction != null && i < signersPerTransaction.length
              ? signersPerTransaction[i]
              : null;

      final result = await simulate(
        transactions[i],
        signers: signers,
        config: config,
      );

      results.add(result);
    }

    return results;
  }

  /// Simulate transaction with comprehensive pre-flight validation
  Future<TransactionSimulationResult> simulateWithPreflightValidation(
    transaction_types.Transaction transaction, {
    List<Keypair>? signers,
    TransactionSimulationConfig? config,
    PreflightValidationConfig? preflightConfig,
    Map<PublicKey, PublicKey>? expectedOwners,
  }) async {
    config ??= TransactionSimulationConfig.defaultConfig();
    preflightConfig ??= PreflightValidationConfig.defaultConfig();

    try {
      // Perform pre-flight validation first
      final preflightResult = await _preflightValidator.validateTransaction(
        transaction,
        config: preflightConfig,
        expectedOwners: expectedOwners,
      );

      // If pre-flight validation fails, return simulation result with errors
      if (!preflightResult.success) {
        return TransactionSimulationResult(
          success: false,
          logs: [
            'Program log: Pre-flight validation failed',
            ...preflightResult.errors.map((e) => 'Program log: ${e.message}'),
          ],
          error: TransactionSimulationError(
            type: 'PreflightValidationError',
            details:
                'Pre-flight validation failed: ${preflightResult.errors.length} errors',
          ),
        );
      }

      // If pre-flight validation passes, proceed with normal simulation
      return await simulate(transaction, signers: signers, config: config);
    } catch (error) {
      return TransactionSimulationResult(
        success: false,
        logs: ['Program log: Pre-flight validation failed'],
        error: TransactionSimulationError(
          type: 'PreflightValidationError',
          details: error.toString(),
        ),
      );
    }
  }

  /// Get the preflight validator for advanced validation operations
  PreflightValidator get preflightValidator => _preflightValidator;

  /// Clear simulation cache
  void clearCache() {
    _cache.clear();
  }

  /// Get cache statistics
  Map<String, int> getCacheStats() {
    return {
      'size': _cache.length,
      'maxSize': _maxCacheSize,
    };
  }

  /// Prepare transaction for simulation
  Future<transaction_types.Transaction> _prepareTransaction(
    transaction_types.Transaction transaction,
  ) async {
    var prepared = transaction;

    // Set fee payer if not set
    if (transaction.feePayer == null && _provider.wallet?.publicKey != null) {
      prepared = prepared.setFeePayer(_provider.wallet!.publicKey);
    }

    // Set recent blockhash if not set
    if (transaction.recentBlockhash == null) {
      try {
        final blockhashResult = await _provider.connection.getLatestBlockhash();
        prepared = prepared.setRecentBlockhash(blockhashResult.blockhash);
      } catch (e) {
        // Use simulation blockhash if fresh fetch fails
        prepared = prepared
            .setRecentBlockhash('FwRYtTPRk5N4wUeP87rTw9kQVSwigB6kbikGzzeCMrW5');
      }
    }

    return prepared;
  }

  /// Perform the actual simulation via RPC
  Future<TransactionSimulationResult> _performSimulation(
    transaction_types.Transaction transaction,
    TransactionSimulationConfig config,
  ) async {
    try {
      // Serialize transaction for RPC call
      final transactionData = await _serializeTransaction(transaction);

      // Create Enhanced RPC client instance for this provider
      final rpcClient = EnhancedRpcClient(_provider.connection);

      // Use the existing simulateTransaction method
      final rpcResult = await rpcClient.simulateTransaction(
        base64.decode(transactionData),
        verifySignatures: config.sigVerify,
        accountsToReturn: config.accountsToInclude,
      );

      // Convert RpcSimulationResult to TransactionSimulationResult
      return _convertRpcResult(rpcResult);
    } catch (e) {
      return TransactionSimulationResult(
        success: false,
        logs: ['Program log: Simulation RPC failed'],
        error: TransactionSimulationError(
          type: 'RpcError',
          details: e.toString(),
        ),
      );
    }
  }

  /// Convert RpcSimulationResult to TransactionSimulationResult
  TransactionSimulationResult _convertRpcResult(RpcSimulationResult rpcResult) {
    if (!rpcResult.success) {
      return TransactionSimulationResult(
        success: false,
        logs: rpcResult.logs,
        error: TransactionSimulationError(
          type: 'SimulationError',
          details: rpcResult.error,
        ),
        unitsConsumed: rpcResult.computeUnits,
      );
    }

    return TransactionSimulationResult(
      success: true,
      logs: rpcResult.logs,
      unitsConsumed: rpcResult.computeUnits,
      // Convert accounts if available
      accounts: rpcResult.accounts?.isNotEmpty == true
          ? _convertAccountsInfo(rpcResult.accounts!)
          : null,
    );
  }

  /// Convert AccountInfo list to Map format
  Map<String, dynamic>? _convertAccountsInfo(List<AccountInfo?> accounts) {
    final accountsMap = <String, dynamic>{};
    for (int i = 0; i < accounts.length; i++) {
      final account = accounts[i];
      if (account != null) {
        accountsMap['account_$i'] = {
          'lamports': account.lamports,
          'owner': account.owner.toBase58(),
          'executable': account.executable,
          'rentEpoch': account.rentEpoch,
          'data': account.data,
        };
      }
    }
    return accountsMap.isNotEmpty ? accountsMap : null;
  }

  /// Serialize transaction for RPC call (placeholder implementation)
  Future<String> _serializeTransaction(
    transaction_types.Transaction transaction,
  ) async {
    // TODO: Implement actual transaction serialization
    // This is a placeholder that returns a base64-encoded mock transaction
    final mockBytes = Uint8List.fromList([
      ...utf8.encode('mock_transaction_${transaction.hashCode}'),
    ]);
    return base64Encode(mockBytes);
  }

  /// Generate cache key for simulation result
  String _generateCacheKey(
    transaction_types.Transaction transaction,
    TransactionSimulationConfig config,
  ) {
    final keyData = {
      'transaction': transaction.hashCode,
      'commitment': config.commitment,
      'includeAccounts': config.includeAccounts,
      'sigVerify': config.sigVerify,
    };
    return keyData.toString();
  }

  /// Add result to cache with LRU eviction
  void _addToCache(String key, TransactionSimulationResult result) {
    if (_cache.length >= _maxCacheSize) {
      // Remove oldest entry (simple FIFO for now)
      final oldestKey = _cache.keys.first;
      _cache.remove(oldestKey);
    }
    _cache[key] = result;
  }

  /// Simulate with comprehensive result processing and analysis
  Future<ProcessedSimulationResult> simulateDetailed(
    transaction_types.Transaction transaction, {
    List<Keypair>? signers,
    TransactionSimulationConfig? config,
    ProcessingOptions? processingOptions,
  }) async {
    // Import at method level to avoid circular dependencies
    final SimulationResultProcessor processor = SimulationResultProcessor();

    // Perform basic simulation
    final simulationResult = await simulate(
      transaction,
      signers: signers,
      config: config,
    );

    // Process the result with comprehensive analysis
    final cacheKey = _generateCacheKey(
        transaction, config ?? TransactionSimulationConfig.defaultConfig());
    return await processor.processResult(
      simulationResult,
      cacheKey: cacheKey,
      options: processingOptions,
    );
  }

  /// Simulate with account validation and detailed result processing
  Future<ProcessedSimulationResult> simulateDetailedWithPreflightValidation(
    transaction_types.Transaction transaction, {
    List<Keypair>? signers,
    TransactionSimulationConfig? config,
    PreflightValidationConfig? preflightConfig,
    ProcessingOptions? processingOptions,
  }) async {
    // Import at method level to avoid circular dependencies
    final SimulationResultProcessor processor = SimulationResultProcessor();

    // Perform simulation with preflight validation
    final simulationResult = await simulateWithPreflightValidation(
      transaction,
      signers: signers,
      config: config,
      preflightConfig: preflightConfig,
    );

    // Process the result with comprehensive analysis
    final cacheKey = _generateCacheKey(
        transaction, config ?? TransactionSimulationConfig.defaultConfig());
    return await processor.processResult(
      simulationResult,
      cacheKey: '${cacheKey}_preflight',
      options: processingOptions,
    );
  }

  /// Compare two simulation results using detailed analysis
  Future<ComparisonResult> compareSimulations(
    transaction_types.Transaction transaction1,
    transaction_types.Transaction transaction2, {
    List<Keypair>? signers1,
    List<Keypair>? signers2,
    TransactionSimulationConfig? config1,
    TransactionSimulationConfig? config2,
    ProcessingOptions? processingOptions,
  }) async {
    // Import at method level to avoid circular dependencies
    final SimulationResultProcessor processor = SimulationResultProcessor();

    // Simulate both transactions
    final result1 = await simulateDetailed(
      transaction1,
      signers: signers1,
      config: config1,
      processingOptions: processingOptions,
    );

    final result2 = await simulateDetailed(
      transaction2,
      signers: signers2,
      config: config2,
      processingOptions: processingOptions,
    );

    // Compare the processed results
    return processor.compareResults(result1, result2);
  }
}

/// Simulation optimization settings
class SimulationOptimization {
  /// Enable result caching
  final bool enableCaching;

  /// Cache size limit
  final int cacheSize;

  /// Enable batch optimization
  final bool enableBatching;

  /// Maximum batch size
  final int maxBatchSize;

  /// Parallel simulation limit
  final int parallelLimit;

  const SimulationOptimization({
    this.enableCaching = true,
    this.cacheSize = 1000,
    this.enableBatching = true,
    this.maxBatchSize = 10,
    this.parallelLimit = 5,
  });

  /// Create default optimization settings
  factory SimulationOptimization.defaultSettings() {
    return const SimulationOptimization();
  }

  /// Create performance-optimized settings
  factory SimulationOptimization.performance() {
    return const SimulationOptimization(
      enableCaching: true,
      cacheSize: 2000,
      enableBatching: true,
      maxBatchSize: 20,
      parallelLimit: 10,
    );
  }

  /// Create memory-conservative settings
  factory SimulationOptimization.conservative() {
    return const SimulationOptimization(
      enableCaching: true,
      cacheSize: 100,
      enableBatching: false,
      maxBatchSize: 5,
      parallelLimit: 2,
    );
  }
}
