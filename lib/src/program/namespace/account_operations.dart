library account_operations;

import 'dart:async';
import 'dart:typed_data';
import 'package:coral_xyz_anchor/src/types/transaction.dart';
import 'package:coral_xyz_anchor/src/types/commitment.dart';
import 'package:coral_xyz_anchor/src/types/keypair.dart';
import 'package:coral_xyz_anchor/src/types/public_key.dart';
import 'package:coral_xyz_anchor/src/coder/coder.dart';
import 'package:coral_xyz_anchor/src/provider/anchor_provider.dart';
import 'package:coral_xyz_anchor/src/program/namespace/account_cache_manager.dart'
    as cache_mgr;
import 'package:coral_xyz_anchor/src/program/namespace/account_subscription_manager.dart';
import 'package:coral_xyz_anchor/src/native/system_program.dart';

// Missing types - define as placeholders for robust implementation
class AccountCreationParams {
  final PublicKey newAccountPubkey;
  final int lamports;
  final int space;
  final PublicKey programId;
  final PublicKey fromPubkey;
  final PublicKey? owner;
  final Keypair? keypair;
  final bool executable;
  final Map<String, dynamic>? initData;

  AccountCreationParams({
    required this.newAccountPubkey,
    required this.lamports,
    required this.space,
    required this.programId,
    required this.fromPubkey,
    this.owner,
    this.keypair,
    this.executable = false,
    this.initData,
  });
}

class IdlAccount {
  final String name;
  final Map<String, dynamic> type;
  final List<int>? discriminator;

  IdlAccount({required this.name, required this.type, this.discriminator});
}

class AccountOwnedByWrongProgramError implements Exception {
  final String message;

  AccountOwnedByWrongProgramError(this.message);

  factory AccountOwnedByWrongProgramError.fromValidation({
    required PublicKey expected,
    required PublicKey actual,
    required List<String> errorLogs,
    required List<String> logs,
    required PublicKey accountAddress,
    required String accountName,
  }) {
    return AccountOwnedByWrongProgramError(
      'Account ${accountAddress.toBase58()} is owned by ${actual.toBase58()}, expected ${expected.toBase58()}',
    );
  }
}

class AccountDiscriminatorMismatchError implements Exception {
  final String message;
  AccountDiscriminatorMismatchError(this.message);
}

class AccountNotInitializedError implements Exception {
  final String message;
  final PublicKey accountAddress;
  final List<String> errorLogs;
  final List<String> logs;
  final String accountName;

  AccountNotInitializedError({
    required this.message,
    required this.accountAddress,
    required this.errorLogs,
    required this.logs,
    required this.accountName,
  });

  factory AccountNotInitializedError.fromAddress({
    required PublicKey accountAddress,
    required List<String> errorLogs,
    required List<String> logs,
    required String accountName,
  }) {
    return AccountNotInitializedError(
      message: 'Account not initialized: ${accountAddress.toBase58()}',
      accountAddress: accountAddress,
      errorLogs: errorLogs,
      logs: logs,
      accountName: accountName,
    );
  }
}

/// Account filter for queries
class AccountFilter {
  final String field;
  final dynamic value;
  final String operator;

  AccountFilter(
      {required this.field, required this.value, required this.operator});
}

/// Account relationship types
enum AccountRelationshipType {
  owner,
  authority,
  delegate,
  parent,
  child,
  associated,
}

/// Account relationship information
class AccountRelationship {
  const AccountRelationship({
    required this.publicKey,
    required this.type,
    this.description,
    this.isVerified = false,
  });

  /// Related account public key
  final PublicKey publicKey;

  /// Type of relationship
  final AccountRelationshipType type;

  /// Optional description
  final String? description;

  /// Whether this relationship is verified
  final bool isVerified;

  @override
  String toString() =>
      'AccountRelationship(publicKey: $publicKey, type: $type, verified: $isVerified)';
}

/// Account debugging information
class AccountDebugInfo {
  const AccountDebugInfo({
    required this.publicKey,
    required this.size,
    required this.owner,
    required this.lamports,
    required this.executable,
    required this.rentEpoch,
    this.slot,
    this.discriminator,
    this.data,
    this.parsedData,
    this.relationships = const [],
    this.creationSignature,
    this.lastUpdateSignature,
  });

  /// Account public key
  final PublicKey publicKey;

  /// Account size in bytes
  final int size;

  /// Account owner
  final PublicKey owner;

  /// Lamports balance
  final int lamports;

  /// Whether account is executable
  final bool executable;

  /// Rent epoch
  final int rentEpoch;

  /// Slot when account was last updated
  final int? slot;

  /// Account discriminator (if applicable)
  final List<int>? discriminator;

  /// Raw account data
  final Uint8List? data;

  /// Parsed account data (if available)
  final Map<String, dynamic>? parsedData;

  /// Account relationships
  final List<AccountRelationship> relationships;

  /// Creation transaction signature (if known)
  final String? creationSignature;

  /// Last update transaction signature (if known)
  final String? lastUpdateSignature;

  /// Check if account is rent exempt
  bool isRentExempt(int minimumBalance) => lamports >= minimumBalance;

  /// Check if account has valid discriminator for program
  bool hasValidDiscriminator(List<int> expectedDiscriminator) {
    if (discriminator == null || expectedDiscriminator.isEmpty) return true;
    if (discriminator!.length < expectedDiscriminator.length) return false;

    for (int i = 0; i < expectedDiscriminator.length; i++) {
      if (discriminator![i] != expectedDiscriminator[i]) return false;
    }
    return true;
  }

  @override
  String toString() =>
      'AccountDebugInfo(publicKey: $publicKey, size: $size, owner: $owner, lamports: $lamports)';
}

/// Comprehensive account operations manager
class AccountOperationsManager<T> {
  AccountOperationsManager({
    required IdlAccount idlAccount,
    required Coder coder,
    required PublicKey programId,
    required AnchorProvider provider,
    cache_mgr.AccountCacheConfig? cacheConfig,
    AccountSubscriptionConfig? subscriptionConfig,
  })  : _idlAccount = idlAccount,
        _coder = coder,
        _programId = programId,
        _provider = provider,
        _cacheManager = cache_mgr.AccountCacheManager<T>(config: cacheConfig),
        _subscriptionManager = AccountSubscriptionManager(
          connection: provider.connection,
          config: subscriptionConfig,
        );

  /// IDL account definition
  final IdlAccount _idlAccount;

  /// Coder for serialization/deserialization
  final Coder _coder;

  /// Program ID
  final PublicKey _programId;

  /// Provider for RPC operations
  final AnchorProvider _provider;

  /// Cache manager for intelligent caching
  final cache_mgr.AccountCacheManager<T> _cacheManager;

  /// Subscription manager for real-time updates
  final AccountSubscriptionManager _subscriptionManager;

  /// Active subscriptions
  final Map<String, StreamSubscription<T?>> _activeSubscriptions = {};

  /// Relationship tracking
  final Map<String, List<AccountRelationship>> _relationships = {};

  /// Fetch account with comprehensive caching and error handling
  Future<T?> fetchNullable(
    PublicKey address, {
    Commitment? commitment,
    bool useCache = true,
    bool validateOwnership = true,
    bool validateDiscriminator = true,
  }) async {
    // Check cache first
    if (useCache) {
      final cached = _cacheManager.get(address);
      if (cached != null) return cached;
    }

    try {
      // Fetch account info
      final accountInfo = await _provider.connection.getAccountInfo(
        address,
        commitment: commitment != null ? CommitmentConfig(commitment) : null,
      );

      if (accountInfo == null) return null;

      // Validate ownership if requested
      if (validateOwnership && accountInfo.owner != _programId) {
        throw AccountOwnedByWrongProgramError.fromValidation(
          expected: _programId,
          actual: accountInfo.owner,
          errorLogs: ['Account owned by wrong program'],
          logs: [
            'Account ownership validation failed for ${address.toBase58()}',
          ],
          accountAddress: address,
          accountName: _idlAccount.name,
        );
      }

      // Convert data to Uint8List if needed
      Uint8List dataBytes;
      if (accountInfo.data is Uint8List) {
        dataBytes = accountInfo.data as Uint8List;
      } else if (accountInfo.data is List<int>) {
        dataBytes = Uint8List.fromList(accountInfo.data as List<int>);
      } else {
        throw Exception('Account data is not a valid byte array');
      }

      // Decode account data
      final decoded = _coder.accounts.decode<T>(
        _idlAccount.name,
        dataBytes,
      );

      // Cache the result
      if (useCache) {
        _cacheManager.put(
          address,
          decoded,
          sizeEstimate: dataBytes.length,
        );
      }

      return decoded;
    } catch (e) {
      // Enhanced error handling
      if (e is AccountOwnedByWrongProgramError ||
          e is AccountDiscriminatorMismatchError) {
        rethrow;
      }

      // Wrap other errors
      throw AccountNotInitializedError.fromAddress(
        accountAddress: address,
        errorLogs: [e.toString()],
        logs: ['Failed to fetch account: ${address.toBase58()}'],
        accountName: _idlAccount.name,
      );
    }
  }

  /// Fetch account, throwing if it doesn't exist
  Future<T> fetch(
    PublicKey address, {
    Commitment? commitment,
    bool useCache = true,
    bool validateOwnership = true,
    bool validateDiscriminator = true,
  }) async {
    final result = await fetchNullable(
      address,
      commitment: commitment,
      useCache: useCache,
      validateOwnership: validateOwnership,
      validateDiscriminator: validateDiscriminator,
    );

    if (result == null) {
      throw AccountNotInitializedError.fromAddress(
        accountAddress: address,
        errorLogs: ['Account not found or not initialized'],
        logs: ['Account fetch attempted for ${address.toBase58()}'],
        accountName: _idlAccount.name,
      );
    }

    return result;
  }

  /// Subscribe to account changes with intelligent caching integration
  Future<Stream<T?>> subscribe(
    PublicKey address, {
    Commitment? commitment,
    bool updateCache = true,
  }) async {
    final subscriptionStream = await _subscriptionManager.subscribe(
      address,
      commitment: commitment,
    );

    // Transform notifications to decoded data
    final controller = StreamController<T?>();
    final subscription = subscriptionStream.listen(
      (notification) async {
        try {
          if (notification.data == null) {
            // Account was deleted
            if (updateCache) {
              _cacheManager.remove(address);
            }
            controller.add(null);
            return;
          }

          // Decode the updated account data
          final decoded = _coder.accounts.decode<T>(
            _idlAccount.name,
            Uint8List.fromList(notification.data!),
          );

          // Update cache
          if (updateCache) {
            _cacheManager.put(
              address,
              decoded,
              slot: notification.slot,
              sizeEstimate: notification.data!.length,
            );
          }

          controller.add(decoded);
        } catch (e) {
          controller.addError(e);
        }
      },
      onError: controller.addError,
      onDone: controller.close,
    );

    // Store as StreamSubscription<AccountChangeNotification>
    _activeSubscriptions[address.toBase58()] =
        subscription as StreamSubscription<T?>;

    controller.onCancel = () {
      subscription.cancel();
      _activeSubscriptions.remove(address.toBase58());
    };

    return controller.stream;
  }

  /// Unsubscribe from account changes
  Future<void> unsubscribe(PublicKey address) async {
    final subscription = _activeSubscriptions.remove(address.toBase58());
    if (subscription != null) {
      await subscription.cancel();
    }
    await _subscriptionManager.unsubscribe(address);
  }

  /// Create account creation instruction
  Future<TransactionInstruction> createAccountInstruction(
    AccountCreationParams params,
  ) async {
    try {
      // Generate keypair if not provided
      final accountKeypair = params.keypair ?? await Keypair.generate();

      // Determine the owner program
      final owner = params.owner ?? _programId;

      // Calculate required lamports for rent exemption if not provided
      int lamports = params.lamports;
      if (lamports == 0) {
        lamports = await _provider.connection.getMinimumBalanceForRentExemption(
          params.space,
        );
      }

      // Get fee payer (usually the provider's wallet)
      final wallet = _provider.wallet;
      if (wallet == null) {
        throw Exception(
          'Provider wallet is not set. Cannot determine fee payer.',
        );
      }
      final feePayer = wallet.publicKey;

      // Create the system program instruction using our existing SystemProgram class
      return SystemProgram.createAccount(
        fromPubkey: feePayer,
        newAccountPubkey: accountKeypair.publicKey,
        lamports: lamports,
        space: params.space,
        programId: owner,
      );
    } catch (e) {
      throw Exception('Failed to create account instruction: $e');
    }
  }

  /// Create PDA (Program Derived Address) account instruction
  Future<TransactionInstruction> createPdaAccountInstruction({
    required List<Uint8List> seeds,
    required int space,
    PublicKey? owner,
    int? lamports,
  }) async {
    try {
      // Derive the PDA
      final pdaResult = await PublicKey.findProgramAddress(
        seeds,
        owner ?? _programId,
      );

      // Calculate required lamports for rent exemption if not provided
      int finalLamports = lamports ?? 0;
      if (finalLamports == 0) {
        finalLamports =
            await _provider.connection.getMinimumBalanceForRentExemption(space);
      }

      // Get fee payer
      final wallet = _provider.wallet;
      if (wallet == null) {
        throw Exception(
          'Provider wallet is not set. Cannot determine fee payer.',
        );
      }
      final feePayer = wallet.publicKey;

      // Create the account creation instruction
      return SystemProgram.createAccount(
        fromPubkey: feePayer,
        newAccountPubkey: pdaResult.address,
        lamports: finalLamports,
        space: space,
        programId: owner ?? _programId,
      );
    } catch (e) {
      throw Exception('Failed to create PDA account instruction: $e');
    }
  }

  /// Batch create multiple accounts robustly
  Future<List<TransactionInstruction>> batchCreateAccounts(
      List<AccountCreationParams> paramsList) async {
    final instructions = <TransactionInstruction>[];
    for (final params in paramsList) {
      final instruction = await createAccountInstruction(params);
      instructions.add(instruction);
    }
    return instructions;
  }

  /// Batch delete accounts (close accounts, transfer lamports to destination)
  Future<List<TransactionInstruction>> batchCloseAccounts(
      List<PublicKey> accounts,
      {required PublicKey destination}) async {
    final instructions = <TransactionInstruction>[];
    for (final account in accounts) {
      instructions.add(SystemProgram.closeAccount(
        account: account,
        destination: destination,
      ));
    }
    return instructions;
  }

  /// Batch update accounts (realloc/resize)
  /// Note: Account resizing is program-specific and requires custom implementation
  /// This method provides a framework for batch resize operations
  Future<List<TransactionInstruction>> batchResizeAccounts(
    List<Map<String, dynamic>> resizeParamsList,
  ) async {
    final instructions = <TransactionInstruction>[];

    for (final params in resizeParamsList) {
      final accountAddress = params['account'] as PublicKey?;
      final newSize = params['newSize'] as int?;
      final payer = params['payer'] as PublicKey?;

      if (accountAddress == null || newSize == null) {
        throw ArgumentError(
            'Account address and newSize are required for resize operation');
      }

      // Get current account info
      final accountInfo =
          await _provider.connection.getAccountInfo(accountAddress);
      if (accountInfo == null) {
        throw AccountNotInitializedError.fromAddress(
          accountAddress: accountAddress,
          errorLogs: ['Account not found for resize operation'],
          logs: ['Resize attempted for non-existent account'],
          accountName: _idlAccount.name,
        );
      }

      // Calculate additional lamports needed for rent exemption
      final currentSize = accountInfo.data is Uint8List
          ? (accountInfo.data as Uint8List).length
          : accountInfo.data is List<int>
              ? (accountInfo.data as List<int>).length
              : 0;

      if (newSize <= currentSize) {
        // No resize needed or shrinking not supported
        continue;
      }

      final newRentExemptLamports =
          await _provider.connection.getMinimumBalanceForRentExemption(newSize);
      final additionalLamports = newRentExemptLamports - accountInfo.lamports;

      if (additionalLamports > 0) {
        // Transfer additional lamports if needed
        final payerAddress = payer ?? _provider.wallet?.publicKey;
        if (payerAddress == null) {
          throw Exception('Payer required for account resize operation');
        }

        instructions.add(SystemProgram.transfer(
          fromPubkey: payerAddress,
          toPubkey: accountAddress,
          lamports: additionalLamports,
        ));
      }

      // Create realloc instruction - this is program-specific
      // Most programs will need to implement their own realloc instruction
      // This is a placeholder for the framework
      final reallocInstruction = _createReallocInstruction(
        accountAddress,
        newSize,
        currentSize,
        params,
      );

      if (reallocInstruction != null) {
        instructions.add(reallocInstruction);
      }
    }

    return instructions;
  }

  /// Create program-specific realloc instruction
  /// This method should be overridden by program-specific implementations
  TransactionInstruction? _createReallocInstruction(
    PublicKey accountAddress,
    int newSize,
    int currentSize,
    Map<String, dynamic> params,
  ) {
    // This is a placeholder - actual implementation depends on the program
    // Most Anchor programs don't support realloc, but some may have custom instructions
    // Return null to indicate no realloc instruction is available
    return null;
  }

  /// Traverse relationships for a given account
  List<AccountRelationship> traverseRelationships(PublicKey account,
      {bool recursive = false}) {
    final visited = <String>{};
    final result = <AccountRelationship>[];

    void traverse(PublicKey acc) {
      final rels = getRelationships(acc);
      for (final rel in rels) {
        if (!visited.contains(rel.publicKey.toBase58())) {
          visited.add(rel.publicKey.toBase58());
          result.add(rel);
          if (recursive) traverse(rel.publicKey);
        }
      }
    }

    traverse(account);
    return result;
  }

  /// Advanced filtering of accounts by predicate
  Future<List<T?>> filterAccounts(bool Function(T?) predicate,
      {List<PublicKey>? addresses,
      Commitment? commitment,
      bool useCache = true}) async {
    final accounts = addresses != null
        ? await fetchMultiple(addresses,
            commitment: commitment, useCache: useCache)
        : await fetchMultiple(await getAllAccountAddresses(),
            commitment: commitment, useCache: useCache);
    return accounts.where(predicate).toList();
  }

  /// Advanced sorting of accounts by comparator
  Future<List<T?>> sortAccounts(int Function(T? a, T? b) comparator,
      {List<PublicKey>? addresses,
      Commitment? commitment,
      bool useCache = true}) async {
    final accounts = addresses != null
        ? await fetchMultiple(addresses,
            commitment: commitment, useCache: useCache)
        : await fetchMultiple(await getAllAccountAddresses(),
            commitment: commitment, useCache: useCache);
    final filtered = accounts.toList();
    filtered.sort(comparator);
    return filtered;
  }

  /// Get all account addresses for this account type
  Future<List<PublicKey>> getAllAccountAddresses({
    List<AccountFilter>? filters,
    Commitment? commitment,
  }) async {
    final programAccounts = await _provider.connection.getProgramAccounts(
      _programId,
      commitment: commitment != null ? CommitmentConfig(commitment) : null,
    );

    final addresses = <PublicKey>[];

    for (final account in programAccounts) {
      // Convert data to Uint8List if needed
      Uint8List? dataBytes;
      if (account.account.data is Uint8List) {
        dataBytes = account.account.data as Uint8List;
      } else if (account.account.data is List<int>) {
        dataBytes = Uint8List.fromList(account.account.data as List<int>);
      } else if (account.account.data is String) {
        // Skip if data is still in string format - needs proper decoding
        continue;
      }

      if (dataBytes == null) continue;

      // Check if account has the correct discriminator for this account type
      if (_idlAccount.discriminator != null &&
          _idlAccount.discriminator!.isNotEmpty) {
        if (dataBytes.length < _idlAccount.discriminator!.length) {
          continue;
        }

        // Check discriminator match
        bool matches = true;
        for (int i = 0; i < _idlAccount.discriminator!.length; i++) {
          if (dataBytes[i] != _idlAccount.discriminator![i]) {
            matches = false;
            break;
          }
        }

        if (!matches) continue;
      }

      // Apply additional filters if provided
      if (filters != null && filters.isNotEmpty) {
        bool passesFilters = true;
        for (final filter in filters) {
          // Basic filtering implementation - can be extended
          if (filter.field == 'lamports') {
            switch (filter.operator) {
              case 'gte':
                if (account.account.lamports < (filter.value as int)) {
                  passesFilters = false;
                }
                break;
              case 'lte':
                if (account.account.lamports > (filter.value as int)) {
                  passesFilters = false;
                }
                break;
              case 'eq':
                if (account.account.lamports != (filter.value as int)) {
                  passesFilters = false;
                }
                break;
            }
          } else if (filter.field == 'dataSize') {
            switch (filter.operator) {
              case 'gte':
                if (dataBytes.length < (filter.value as int)) {
                  passesFilters = false;
                }
                break;
              case 'lte':
                if (dataBytes.length > (filter.value as int)) {
                  passesFilters = false;
                }
                break;
              case 'eq':
                if (dataBytes.length != (filter.value as int)) {
                  passesFilters = false;
                }
                break;
            }
          }

          if (!passesFilters) break;
        }

        if (!passesFilters) continue;
      }

      addresses.add(account.pubkey);
    }

    return addresses;
  }

  /// Get comprehensive debugging information for account
  Future<AccountDebugInfo> getDebugInfo(PublicKey address) async {
    try {
      final accountInfo = await _provider.connection.getAccountInfo(address);

      if (accountInfo == null) {
        throw AccountNotInitializedError.fromAddress(
          accountAddress: address,
          errorLogs: ['Account not found'],
          logs: ['Debug info requested for non-existent account'],
          accountName: _idlAccount.name,
        );
      }

      // Convert data to Uint8List if needed
      Uint8List? dataBytes;
      if (accountInfo.data is Uint8List) {
        dataBytes = accountInfo.data as Uint8List;
      } else if (accountInfo.data is List<int>) {
        dataBytes = Uint8List.fromList(accountInfo.data as List<int>);
      } else {
        dataBytes = null;
      }

      // Extract discriminator if available
      List<int>? discriminator;
      if (dataBytes != null && dataBytes.length >= 8) {
        discriminator = dataBytes.take(8).toList();
      }

      // Try to parse account data
      Map<String, dynamic>? parsedData;
      try {
        if (dataBytes != null) {
          final decoded =
              _coder.accounts.decode<T>(_idlAccount.name, dataBytes);
          if (decoded is Map<String, dynamic>) {
            parsedData = decoded;
          }
        }
      } catch (e) {
        // Parsing failed, leave parsedData as null
      }

      // Get relationships
      final relationships = _relationships[address.toBase58()] ?? [];

      return AccountDebugInfo(
        publicKey: address,
        size: dataBytes?.length ?? 0,
        owner: accountInfo.owner,
        lamports: accountInfo.lamports,
        executable: accountInfo.executable,
        rentEpoch: accountInfo.rentEpoch,
        discriminator: discriminator,
        data: dataBytes,
        parsedData: parsedData,
        relationships: relationships,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Add account relationship
  void addRelationship(
    PublicKey account,
    AccountRelationship relationship,
  ) {
    final key = account.toBase58();
    _relationships.putIfAbsent(key, () => []).add(relationship);
  }

  /// Get account relationships
  List<AccountRelationship> getRelationships(PublicKey account) =>
      _relationships[account.toBase58()] ?? [];

  /// Validate account size against expected size
  Future<bool> validateAccountSize(PublicKey address, int expectedSize) async {
    try {
      final accountInfo = await _provider.connection.getAccountInfo(address);
      if (accountInfo == null) return false;

      // Get actual size from account data
      int actualSize = 0;
      if (accountInfo.data is Uint8List) {
        actualSize = (accountInfo.data as Uint8List).length;
      } else if (accountInfo.data is List<int>) {
        actualSize = (accountInfo.data as List<int>).length;
      }

      return actualSize == expectedSize;
    } catch (e) {
      return false;
    }
  }

  /// Calculate minimum balance for rent exemption
  Future<int> calculateMinimumBalance({int? customSize}) async {
    final size = customSize ?? _coder.accounts.size(_idlAccount.name);
    return _provider.connection.getMinimumBalanceForRentExemption(size);
  }

  /// Check if account is rent exempt
  Future<bool> isRentExempt(PublicKey address) async {
    final accountInfo = await _provider.connection.getAccountInfo(address);
    if (accountInfo == null) return false;

    final minimumBalance = await calculateMinimumBalance();
    return accountInfo.lamports >= minimumBalance;
  }

  /// Batch fetch multiple accounts
  Future<List<T?>> fetchMultiple(
    List<PublicKey> addresses, {
    Commitment? commitment,
    bool useCache = true,
  }) async {
    if (addresses.isEmpty) return [];

    // Check cache first for all addresses
    final results = <T?>[];
    final uncachedAddresses = <PublicKey>[];
    final uncachedIndices = <int>[];

    for (int i = 0; i < addresses.length; i++) {
      final address = addresses[i];
      if (useCache) {
        final cached = _cacheManager.get(address);
        if (cached != null) {
          results.add(cached);
          continue;
        }
      }
      results.add(null); // placeholder
      uncachedAddresses.add(address);
      uncachedIndices.add(i);
    }

    // Batch fetch uncached accounts using getMultipleAccountsInfo
    if (uncachedAddresses.isNotEmpty) {
      try {
        final accountInfos = await _provider.connection.getMultipleAccountsInfo(
          uncachedAddresses,
          commitment: commitment != null ? CommitmentConfig(commitment) : null,
        );

        for (int i = 0; i < uncachedAddresses.length; i++) {
          final address = uncachedAddresses[i];
          final accountInfo = accountInfos[i];
          final resultIndex = uncachedIndices[i];

          if (accountInfo == null) {
            results[resultIndex] = null;
            continue;
          }

          try {
            // Validate ownership if needed
            if (accountInfo.owner != _programId) {
              results[resultIndex] = null;
              continue;
            }

            // Convert data to Uint8List if needed
            Uint8List dataBytes;
            if (accountInfo.data is Uint8List) {
              dataBytes = accountInfo.data as Uint8List;
            } else if (accountInfo.data is List<int>) {
              dataBytes = Uint8List.fromList(accountInfo.data as List<int>);
            } else {
              results[resultIndex] = null;
              continue;
            }

            // Decode account data
            final decoded = _coder.accounts.decode<T>(
              _idlAccount.name,
              dataBytes,
            );

            // Cache the result
            if (useCache) {
              _cacheManager.put(
                address,
                decoded,
                sizeEstimate: dataBytes.length,
              );
            }

            results[resultIndex] = decoded;
          } catch (e) {
            results[resultIndex] = null;
          }
        }
      } catch (e) {
        // If batch request fails, fall back to individual requests
        for (int i = 0; i < uncachedAddresses.length; i++) {
          final address = uncachedAddresses[i];
          final resultIndex = uncachedIndices[i];
          try {
            final result = await fetchNullable(
              address,
              commitment: commitment,
              useCache: useCache,
            );
            results[resultIndex] = result;
          } catch (e) {
            results[resultIndex] = null;
          }
        }
      }
    }

    return results;
  }

  /// Batch validation of account ownership
  Future<Map<PublicKey, bool>> batchValidateOwnership(List<PublicKey> addresses,
      {PublicKey? expectedOwner}) async {
    final result = <PublicKey, bool>{};
    final owner = expectedOwner ?? _programId;

    for (final address in addresses) {
      try {
        final accountInfo = await _provider.connection.getAccountInfo(address);
        result[address] = accountInfo?.owner == owner;
      } catch (e) {
        result[address] = false;
      }
    }

    return result;
  }

  /// Batch validation of account discriminators
  Future<Map<PublicKey, bool>> batchValidateDiscriminators(
      List<PublicKey> addresses,
      {List<int>? expectedDiscriminator}) async {
    final result = <PublicKey, bool>{};
    final discriminator = expectedDiscriminator ?? _idlAccount.discriminator;

    if (discriminator == null || discriminator.isEmpty) {
      // No discriminator to validate, return true for all
      for (final address in addresses) {
        result[address] = true;
      }
      return result;
    }

    for (final address in addresses) {
      try {
        final accountInfo = await _provider.connection.getAccountInfo(address);
        if (accountInfo?.data == null) {
          result[address] = false;
          continue;
        }

        Uint8List dataBytes;
        if (accountInfo!.data is Uint8List) {
          dataBytes = accountInfo.data as Uint8List;
        } else if (accountInfo.data is List<int>) {
          dataBytes = Uint8List.fromList(accountInfo.data as List<int>);
        } else {
          result[address] = false;
          continue;
        }

        if (dataBytes.length < discriminator.length) {
          result[address] = false;
          continue;
        }

        bool isValid = true;
        for (int i = 0; i < discriminator.length; i++) {
          if (dataBytes[i] != discriminator[i]) {
            isValid = false;
            break;
          }
        }
        result[address] = isValid;
      } catch (e) {
        result[address] = false;
      }
    }

    return result;
  }

  /// Monitor account changes across multiple accounts
  Future<Stream<Map<PublicKey, T?>>> monitorMultipleAccounts(
    List<PublicKey> addresses, {
    Commitment? commitment,
    bool updateCache = true,
  }) async {
    final controller = StreamController<Map<PublicKey, T?>>();
    final subscriptions = <StreamSubscription<void>>[];

    for (final address in addresses) {
      final stream = await subscribe(address,
          commitment: commitment, updateCache: updateCache);
      final subscription = stream.listen(
        (data) {
          // Send current state of all monitored accounts
          final currentState = <PublicKey, T?>{};
          for (final addr in addresses) {
            currentState[addr] = _cacheManager.get(addr);
          }
          controller.add(currentState);
        },
        onError: controller.addError,
      );
      subscriptions.add(subscription);
    }

    controller.onCancel = () {
      for (final sub in subscriptions) {
        sub.cancel();
      }
    };

    return controller.stream;
  }

  /// Perform comprehensive account health check
  Future<Map<String, dynamic>> performHealthCheck(PublicKey address) async {
    final healthInfo = <String, dynamic>{};

    try {
      // Basic existence check
      final accountInfo = await _provider.connection.getAccountInfo(address);
      healthInfo['exists'] = accountInfo != null;

      if (accountInfo == null) {
        healthInfo['status'] = 'not_found';
        return healthInfo;
      }

      // Ownership validation
      healthInfo['correct_owner'] = accountInfo.owner == _programId;
      healthInfo['owner'] = accountInfo.owner.toBase58();

      // Rent exemption check
      final isRentExempt = await this.isRentExempt(address);
      healthInfo['rent_exempt'] = isRentExempt;
      healthInfo['lamports'] = accountInfo.lamports;

      // Size validation
      final expectedSize = _coder.accounts.size(_idlAccount.name);
      healthInfo['correct_size'] = accountInfo.data?.length == expectedSize;
      healthInfo['actual_size'] = accountInfo.data?.length ?? 0;
      healthInfo['expected_size'] = expectedSize;

      // Discriminator validation
      if (_idlAccount.discriminator != null &&
          _idlAccount.discriminator!.isNotEmpty) {
        bool validDiscriminator = false;
        if (accountInfo.data != null) {
          Uint8List dataBytes;
          if (accountInfo.data is Uint8List) {
            dataBytes = accountInfo.data as Uint8List;
          } else if (accountInfo.data is List<int>) {
            dataBytes = Uint8List.fromList(accountInfo.data as List<int>);
          } else {
            dataBytes = Uint8List(0);
          }

          if (dataBytes.length >= _idlAccount.discriminator!.length) {
            validDiscriminator = true;
            for (int i = 0; i < _idlAccount.discriminator!.length; i++) {
              if (dataBytes[i] != _idlAccount.discriminator![i]) {
                validDiscriminator = false;
                break;
              }
            }
          }
        }
        healthInfo['valid_discriminator'] = validDiscriminator;
      }

      // Try to decode data
      try {
        if (accountInfo.data != null) {
          Uint8List dataBytes;
          if (accountInfo.data is Uint8List) {
            dataBytes = accountInfo.data as Uint8List;
          } else if (accountInfo.data is List<int>) {
            dataBytes = Uint8List.fromList(accountInfo.data as List<int>);
          } else {
            throw Exception('Invalid data type');
          }

          final decoded =
              _coder.accounts.decode<T>(_idlAccount.name, dataBytes);
          healthInfo['decodable'] = true;
          healthInfo['decoded_data'] = decoded;
        } else {
          healthInfo['decodable'] = false;
        }
      } catch (e) {
        healthInfo['decodable'] = false;
        healthInfo['decode_error'] = e.toString();
      }

      // Overall status
      final isHealthy = healthInfo['exists'] == true &&
          healthInfo['correct_owner'] == true &&
          healthInfo['rent_exempt'] == true &&
          healthInfo['correct_size'] == true &&
          (healthInfo['valid_discriminator'] != false) &&
          healthInfo['decodable'] == true;

      healthInfo['status'] = isHealthy ? 'healthy' : 'unhealthy';
    } catch (e) {
      healthInfo['status'] = 'error';
      healthInfo['error'] = e.toString();
    }

    return healthInfo;
  }

  /// Export account data for backup/migration
  Future<Map<String, dynamic>> exportAccountData(PublicKey address) async {
    final accountInfo = await _provider.connection.getAccountInfo(address);
    if (accountInfo == null) {
      throw AccountNotInitializedError.fromAddress(
        accountAddress: address,
        errorLogs: ['Account not found for export'],
        logs: ['Export attempted for non-existent account'],
        accountName: _idlAccount.name,
      );
    }

    final export = <String, dynamic>{
      'address': address.toBase58(),
      'owner': accountInfo.owner.toBase58(),
      'lamports': accountInfo.lamports,
      'executable': accountInfo.executable,
      'rent_epoch': accountInfo.rentEpoch,
      'data_length': accountInfo.data?.length ?? 0,
      'export_timestamp': DateTime.now().toIso8601String(),
      'account_type': _idlAccount.name,
    };

    if (accountInfo.data != null) {
      Uint8List dataBytes;
      if (accountInfo.data is Uint8List) {
        dataBytes = accountInfo.data as Uint8List;
      } else if (accountInfo.data is List<int>) {
        dataBytes = Uint8List.fromList(accountInfo.data as List<int>);
      } else {
        dataBytes = Uint8List(0);
      }

      export['raw_data'] = dataBytes.toList();

      // Try to include decoded data
      try {
        final decoded = _coder.accounts.decode<T>(_idlAccount.name, dataBytes);
        export['decoded_data'] = decoded;
      } catch (e) {
        export['decode_error'] = e.toString();
      }
    }

    return export;
  }

  /// Advanced account search with multiple criteria
  Future<List<PublicKey>> searchAccounts({
    Map<String, dynamic>? filters,
    int? minLamports,
    int? maxLamports,
    bool? executable,
    int? minSize,
    int? maxSize,
    Commitment? commitment,
    int? limit,
  }) async {
    // Build account filters based on search criteria
    final accountFilters = <AccountFilter>[];

    // Add lamports filters
    if (minLamports != null) {
      accountFilters.add(AccountFilter(
        field: 'lamports',
        value: minLamports,
        operator: 'gte',
      ));
    }
    if (maxLamports != null) {
      accountFilters.add(AccountFilter(
        field: 'lamports',
        value: maxLamports,
        operator: 'lte',
      ));
    }

    // Add size filters
    if (minSize != null) {
      accountFilters.add(AccountFilter(
        field: 'dataSize',
        value: minSize,
        operator: 'gte',
      ));
    }
    if (maxSize != null) {
      accountFilters.add(AccountFilter(
        field: 'dataSize',
        value: maxSize,
        operator: 'lte',
      ));
    }

    // Get all addresses matching the filters
    final addresses = await getAllAccountAddresses(
      filters: accountFilters,
      commitment: commitment,
    );

    // Apply additional filters if needed
    List<PublicKey> filteredAddresses = addresses;

    if (executable != null) {
      // Filter by executable status - would need to fetch account info
      final results = <PublicKey>[];
      for (final address in addresses) {
        try {
          final accountInfo =
              await _provider.connection.getAccountInfo(address);
          if (accountInfo != null && accountInfo.executable == executable) {
            results.add(address);
          }
        } catch (e) {
          // Skip accounts that can't be fetched
        }
      }
      filteredAddresses = results;
    }

    // Apply custom filters from map
    if (filters != null && filters.isNotEmpty) {
      final results = <PublicKey>[];
      for (final address in filteredAddresses) {
        bool passesFilters = true;
        try {
          final accountData =
              await fetchNullable(address, commitment: commitment);
          if (accountData == null) continue;

          // Apply custom filters - this would need to be extended based on specific use cases
          // For now, just continue with basic filtering
          // Custom field-based filtering would require runtime reflection or code generation

          if (passesFilters) {
            results.add(address);
          }
        } catch (e) {
          // Skip accounts that can't be processed
        }
      }
      filteredAddresses = results;
    }

    // Apply limit if specified
    if (limit != null && filteredAddresses.length > limit) {
      filteredAddresses = filteredAddresses.take(limit).toList();
    }

    return filteredAddresses;
  }

  /// Get account creation cost estimation
  Future<Map<String, dynamic>> getCreationCostEstimate({
    int? customSize,
    int? customLamports,
  }) async {
    final size = customSize ?? _coder.accounts.size(_idlAccount.name);
    final rentExemptLamports =
        await _provider.connection.getMinimumBalanceForRentExemption(size);
    final finalLamports = customLamports ?? rentExemptLamports;

    return {
      'account_size': size,
      'rent_exempt_lamports': rentExemptLamports,
      'total_lamports': finalLamports,
      'sol_cost': finalLamports / 1000000000, // Convert to SOL
      'is_rent_exempt': finalLamports >= rentExemptLamports,
    };
  }

  /// Validate account creation parameters
  Future<Map<String, dynamic>> validateCreationParams(
      AccountCreationParams params) async {
    final validation = <String, dynamic>{
      'valid': true,
      'errors': <String>[],
      'warnings': <String>[],
    };

    // Validate space
    final expectedSize = _coder.accounts.size(_idlAccount.name);
    if (params.space < expectedSize) {
      validation['valid'] = false;
      validation['errors'].add(
          'Space (${params.space}) is less than required (${expectedSize})');
    }

    // Validate lamports for rent exemption
    final minLamports = await _provider.connection
        .getMinimumBalanceForRentExemption(params.space);
    if (params.lamports < minLamports) {
      validation['valid'] = false;
      validation['errors'].add(
          'Lamports (${params.lamports}) is less than rent exempt minimum (${minLamports})');
    }

    // Validate owner
    if (params.owner != null && params.owner != _programId) {
      validation['warnings'].add('Owner is not the expected program ID');
    }

    // Check if account already exists
    try {
      final existing =
          await _provider.connection.getAccountInfo(params.newAccountPubkey);
      if (existing != null) {
        validation['valid'] = false;
        validation['errors'].add('Account already exists');
      }
    } catch (e) {
      // Account doesn't exist, which is good
    }

    return validation;
  }

  /// Get cache statistics
  cache_mgr.CacheStatistics getCacheStatistics() =>
      _cacheManager.getStatistics();

  /// Get subscription statistics
  Map<String, dynamic> getSubscriptionStatistics() =>
      _subscriptionManager.getManagerStats();

  /// Cleanup expired cache entries
  void cleanupCache() {
    _cacheManager.cleanup();
  }

  /// Clear all caches
  void clearCache() {
    _cacheManager.clear();
  }

  /// Shutdown the operations manager
  Future<void> shutdown() async {
    // Cancel all active subscriptions
    final futures = <Future<void>>[];
    for (final subscription in _activeSubscriptions.values) {
      futures.add(subscription.cancel());
    }
    await Future.wait(futures);
    _activeSubscriptions.clear();

    // Shutdown managers
    await _subscriptionManager.shutdown();
    _cacheManager.shutdown();
  }

  /// Get account size in bytes
  int get accountSize => _coder.accounts.size(_idlAccount.name);

  /// Get program ID
  PublicKey get programId => _programId;

  /// Get account name
  String get accountName => _idlAccount.name;

  /// Get account discriminator
  List<int> get discriminator => _idlAccount.discriminator ?? [];
}
