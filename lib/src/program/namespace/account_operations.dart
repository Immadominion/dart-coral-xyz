/// Comprehensive Account Operations Manager
///
/// This module provides a unified interface for all account management
/// operations including fetching, caching, subscriptions, creation helpers,
/// debugging tools, and relationship tracking.

library;

import 'dart:async';
import 'dart:typed_data';

import 'package:coral_xyz_anchor/src/types/public_key.dart';
import 'package:coral_xyz_anchor/src/types/commitment.dart';
import 'package:coral_xyz_anchor/src/types/transaction.dart';
import 'package:coral_xyz_anchor/src/types/keypair.dart';
import 'package:coral_xyz_anchor/src/coder/main_coder.dart';
import 'package:coral_xyz_anchor/src/idl/idl.dart';
import 'package:coral_xyz_anchor/src/provider/anchor_provider.dart';
import 'package:coral_xyz_anchor/src/error/account_errors.dart';
import 'package:coral_xyz_anchor/src/native/system_program.dart';
import 'package:coral_xyz_anchor/src/program/namespace/account_cache_manager.dart';
import 'package:coral_xyz_anchor/src/program/namespace/account_subscription_manager.dart';

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
  String toString() => 'AccountRelationship(publicKey: $publicKey, type: $type, verified: $isVerified)';
}

/// Account creation parameters
class AccountCreationParams {

  const AccountCreationParams({
    required this.space,
    this.lamports,
    this.owner,
    this.keypair,
    this.executable = false,
    this.initData,
  });
  /// Size of the account in bytes
  final int space;

  /// Lamports to allocate for rent exemption
  final int? lamports;

  /// Owner program ID (defaults to current program)
  final PublicKey? owner;

  /// Account keypair (if null, a new one will be generated)
  final Keypair? keypair;

  /// Whether to make account executable
  final bool executable;

  /// Additional initialization data
  final Map<String, dynamic>? initData;
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
  String toString() => 'AccountDebugInfo(publicKey: $publicKey, size: $size, owner: $owner, lamports: $lamports)';
}

/// Comprehensive account operations manager
class AccountOperationsManager<T> {

  AccountOperationsManager({
    required IdlAccount idlAccount,
    required Coder coder,
    required PublicKey programId,
    required AnchorProvider provider,
    AccountCacheConfig? cacheConfig,
    AccountSubscriptionConfig? subscriptionConfig,
  })  : _idlAccount = idlAccount,
        _coder = coder,
        _programId = programId,
        _provider = provider,
        _cacheManager = AccountCacheManager<T>(config: cacheConfig),
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
  final AccountCacheManager<T> _cacheManager;

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
      int lamports = params.lamports ?? 0;
      if (lamports == 0) {
        lamports = await _provider.connection.getMinimumBalanceForRentExemption(
          params.space,
        );
      }

      // Get fee payer (usually the provider's wallet)
      final wallet = _provider.wallet;
      if (wallet == null) {
        throw Exception(
            'Provider wallet is not set. Cannot determine fee payer.',);
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
            'Provider wallet is not set. Cannot determine fee payer.',);
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
  List<AccountRelationship> getRelationships(PublicKey account) => _relationships[account.toBase58()] ?? [];

  /// Validate account size against expected size
  bool validateAccountSize(PublicKey address, int expectedSize) {
    // This would need to be implemented with actual account info
    // For now, return true as a stub
    return true;
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
    final results = <T?>[];

    // For now, fetch sequentially
    // TODO: Implement true batch fetching when RPC supports it
    for (final address in addresses) {
      try {
        final result = await fetchNullable(
          address,
          commitment: commitment,
          useCache: useCache,
        );
        results.add(result);
      } catch (e) {
        results.add(null);
      }
    }

    return results;
  }

  /// Get cache statistics
  CacheStatistics getCacheStatistics() => _cacheManager.getStatistics();

  /// Get subscription statistics
  Map<String, dynamic> getSubscriptionStatistics() => _subscriptionManager.getManagerStats();

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
