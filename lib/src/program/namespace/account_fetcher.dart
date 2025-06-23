/// Account Fetching and Caching Layer for Anchor Programs
///
/// This module provides sophisticated account fetching with intelligent caching,
/// batch operations, state management, and real-time subscriptions matching
/// TypeScript Anchor's account namespace functionality.

import 'dart:async';

import '../../types/public_key.dart';
import '../../types/commitment.dart';
import '../../coder/main_coder.dart';
import '../../idl/idl.dart';
import '../../provider/anchor_provider.dart';
import '../../provider/connection.dart';
import '../../error/account_errors.dart';

/// Enhanced account fetcher with caching and batch operations
class AccountFetcher<T> {
  final IdlAccount _idlAccount;
  final Coder _coder;
  final PublicKey _programId;
  final AnchorProvider _provider;
  final AccountFetcherConfig _config;

  // Cache management
  final Map<String, CachedAccountData<T>> _cache = {};
  final Map<String, Future<T?>> _pendingFetches = {};

  // Subscription management
  final Map<String, AccountSubscription<T>> _subscriptions = {};

  /// Create a new account fetcher
  AccountFetcher({
    required IdlAccount idlAccount,
    required Coder coder,
    required PublicKey programId,
    required AnchorProvider provider,
    AccountFetcherConfig? config,
  })  : _idlAccount = idlAccount,
        _coder = coder,
        _programId = programId,
        _provider = provider,
        _config = config ?? AccountFetcherConfig();

  /// Get the account size in bytes
  int get size => _coder.accounts.size(_idlAccount.name);

  /// Get the program ID
  PublicKey get programId => _programId;

  /// Get the provider
  AnchorProvider get provider => _provider;

  /// Get the coder
  Coder get coder => _coder;

  /// Fetch a single account, returning null if it doesn't exist
  Future<T?> fetchNullable(
    PublicKey address, {
    Commitment? commitment,
    bool useCache = true,
  }) async {
    final addressStr = address.toBase58();

    // Check cache first if enabled
    if (useCache && _config.enableCaching) {
      final cached = _cache[addressStr];
      if (cached != null && !cached.isExpired(_config.cacheTimeout)) {
        return cached.data;
      }
    }

    // Check if fetch is already pending to avoid duplicate requests
    if (_pendingFetches.containsKey(addressStr)) {
      return await _pendingFetches[addressStr];
    }

    // Create pending fetch future
    final future = _performFetch(address, commitment);
    _pendingFetches[addressStr] = future;

    try {
      final result = await future;

      // Update cache if enabled and data is valid
      if (useCache && _config.enableCaching && result != null) {
        _cache[addressStr] = CachedAccountData<T>(
          data: result,
          timestamp: DateTime.now(),
          slot: null, // TODO: Get slot from account info
        );
      }

      return result;
    } finally {
      _pendingFetches.remove(addressStr);
    }
  }

  /// Fetch a single account, throwing if it doesn't exist
  Future<T> fetch(
    PublicKey address, {
    Commitment? commitment,
    bool useCache = true,
  }) async {
    final result = await fetchNullable(
      address,
      commitment: commitment,
      useCache: useCache,
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

  /// Fetch account with RPC context information
  Future<AccountWithContext<T?>> fetchNullableAndContext(
    PublicKey address, {
    Commitment? commitment,
    bool useCache = true,
  }) async {
    // For now, use regular fetch and create a mock context
    // TODO: Implement getAccountInfoAndContext when available
    final data = await fetchNullable(
      address,
      commitment: commitment,
      useCache: useCache,
    );

    return AccountWithContext<T?>(
      data: data,
      context: RpcResponseContext(slot: 0), // Mock context
    );
  }

  /// Fetch account with RPC context, throwing if it doesn't exist
  Future<AccountWithContext<T>> fetchAndContext(
    PublicKey address, {
    Commitment? commitment,
    bool useCache = true,
  }) async {
    final result = await fetchNullableAndContext(
      address,
      commitment: commitment,
      useCache: useCache,
    );

    if (result.data == null) {
      throw AccountNotInitializedError.fromAddress(
        accountAddress: address,
        errorLogs: ['Account not found or not initialized'],
        logs: ['Account fetch attempted for ${address.toBase58()}'],
        accountName: _idlAccount.name,
      );
    }

    return AccountWithContext<T>(
      data: result.data!,
      context: result.context,
    );
  }

  /// Fetch multiple accounts in batch
  Future<List<T?>> fetchMultiple(
    List<PublicKey> addresses, {
    Commitment? commitment,
    bool useCache = true,
  }) async {
    if (addresses.isEmpty) return [];

    // Check cache for any existing data
    final results = <T?>[];
    final uncachedAddresses = <PublicKey>[];
    final uncachedIndices = <int>[];

    for (int i = 0; i < addresses.length; i++) {
      final address = addresses[i];
      final addressStr = address.toBase58();

      if (useCache && _config.enableCaching) {
        final cached = _cache[addressStr];
        if (cached != null && !cached.isExpired(_config.cacheTimeout)) {
          results.add(cached.data);
          continue;
        }
      }

      results.add(null); // Placeholder
      uncachedAddresses.add(address);
      uncachedIndices.add(i);
    }

    // Fetch uncached accounts
    if (uncachedAddresses.isNotEmpty) {
      final commitmentConfig =
          commitment != null ? CommitmentConfig(commitment) : null;

      final accountInfos = await _provider.connection.getMultipleAccountsInfo(
        uncachedAddresses,
        commitment: commitmentConfig,
      );

      for (int i = 0; i < accountInfos.length; i++) {
        final accountInfo = accountInfos[i];
        final address = uncachedAddresses[i];
        final resultIndex = uncachedIndices[i];

        if (accountInfo == null || accountInfo.data.isEmpty) {
          results[resultIndex] = null;
          continue;
        }

        // Validate account ownership
        if (accountInfo.owner.toBase58() != _programId.toBase58()) {
          results[resultIndex] = null;
          continue;
        }

        try {
          // Decode account data
          final decodedData = _coder.accounts.decode<T>(
            _idlAccount.name,
            accountInfo.data,
          );

          results[resultIndex] = decodedData;

          // Update cache if enabled
          if (useCache && _config.enableCaching) {
            _cache[address.toBase58()] = CachedAccountData<T>(
              data: decodedData,
              timestamp: DateTime.now(),
              slot: null, // TODO: Get slot from multiple accounts response
            );
          }
        } catch (e) {
          // If decoding fails, treat as null account
          results[resultIndex] = null;
        }
      }
    }

    return results;
  }

  /// Fetch multiple accounts with context information
  Future<List<AccountWithContext<T>?>> fetchMultipleAndContext(
    List<PublicKey> addresses, {
    Commitment? commitment,
  }) async {
    if (addresses.isEmpty) return [];

    // For now, use regular batch fetch and create mock contexts
    // TODO: Implement getMultipleAccountsInfoAndContext when available
    final results = await fetchMultiple(addresses, commitment: commitment);

    return results.map((data) {
      if (data == null) return null;
      return AccountWithContext<T>(
        data: data,
        context: RpcResponseContext(slot: 0), // Mock context
      );
    }).toList();
  }

  /// Fetch all accounts of this type from the program
  Future<List<ProgramAccount<T>>> all({
    List<AccountFilter>? filters,
    Commitment? commitment,
  }) async {
    // Create discriminator filter
    final memcmpFilter = _coder.accounts.memcmp(_idlAccount.name);
    final allFilters = <AccountFilter>[];

    // Add discriminator filter
    if (memcmpFilter.containsKey('offset') &&
        memcmpFilter.containsKey('bytes')) {
      allFilters.add(MemcmpFilter(
        offset: memcmpFilter['offset'] as int,
        bytes: memcmpFilter['bytes'] as String,
      ));
    }

    // Add size filter if available
    if (memcmpFilter.containsKey('dataSize')) {
      allFilters.add(DataSizeFilter(
        memcmpFilter['dataSize'] as int,
      ));
    }

    // Add user-provided filters
    if (filters != null) {
      allFilters.addAll(filters);
    }

    final commitmentConfig =
        commitment != null ? CommitmentConfig(commitment) : null;

    // Fetch program accounts
    final accounts = await _provider.connection.getProgramAccounts(
      _programId,
      filters: allFilters,
      commitment: commitmentConfig,
    );

    // Decode accounts
    final results = <ProgramAccount<T>>[];
    for (final account in accounts) {
      try {
        final decodedData = _coder.accounts.decode<T>(
          _idlAccount.name,
          account.account.data,
        );

        results.add(ProgramAccount<T>(
          publicKey: account.pubkey,
          account: decodedData,
        ));
      } catch (e) {
        // Skip accounts that fail to decode
        continue;
      }
    }

    return results;
  }

  /// Subscribe to account changes
  Stream<T> subscribe(
    PublicKey address, {
    Commitment? commitment,
  }) {
    final addressStr = address.toBase58();

    // Return existing subscription if available
    final existing = _subscriptions[addressStr];
    if (existing != null) {
      return existing.stream;
    }

    // Create new subscription using real account subscription manager
    final controller = StreamController<T>.broadcast();
    final subscription = AccountSubscription<T>(
      address: address,
      controller: controller,
      commitment: commitment,
    );

    _subscriptions[addressStr] = subscription;

    // TODO: Integrate with real AccountSubscriptionManager when available
    // For now, create a mock subscription
    controller.onCancel = () {
      _subscriptions.remove(addressStr);
      subscription.cancel();
    };

    return controller.stream;
  }

  /// Unsubscribe from account changes
  Future<void> unsubscribe(PublicKey address) async {
    final addressStr = address.toBase58();
    final subscription = _subscriptions.remove(addressStr);
    if (subscription != null) {
      await subscription.cancel();
    }
  }

  /// Clear account cache
  void clearCache() {
    _cache.clear();
  }

  /// Remove expired entries from cache
  void cleanCache() {
    final now = DateTime.now();
    _cache.removeWhere(
        (key, value) => now.difference(value.timestamp) > _config.cacheTimeout);
  }

  /// Get cache statistics
  CacheStatistics getCacheStatistics() {
    final now = DateTime.now();
    int valid = 0;
    int expired = 0;

    for (final entry in _cache.values) {
      if (now.difference(entry.timestamp) <= _config.cacheTimeout) {
        valid++;
      } else {
        expired++;
      }
    }

    return CacheStatistics(
      totalEntries: _cache.length,
      validEntries: valid,
      expiredEntries: expired,
    );
  }

  /// Perform the actual account fetch
  Future<T?> _performFetch(PublicKey address, Commitment? commitment) async {
    final commitmentConfig =
        commitment != null ? CommitmentConfig(commitment) : null;

    final accountInfo = await _provider.connection.getAccountInfo(
      address,
      commitment: commitmentConfig,
    );

    if (accountInfo == null || accountInfo.data.isEmpty) {
      return null;
    }

    // Validate account ownership
    if (accountInfo.owner.toBase58() != _programId.toBase58()) {
      throw AccountOwnedByWrongProgramError.fromValidation(
        accountAddress: address,
        accountName: _idlAccount.name,
        expected: _programId,
        actual: accountInfo.owner,
        errorLogs: ['Account owned by wrong program'],
        logs: [
          'Expected: ${_programId.toBase58()}, Actual: ${accountInfo.owner.toBase58()}'
        ],
      );
    }

    // Decode account data
    return _coder.accounts.decode<T>(_idlAccount.name, accountInfo.data);
  }

  /// Dispose of the account fetcher
  void dispose() {
    // Cancel all subscriptions
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();

    // Clear cache
    _cache.clear();
  }
}

/// Configuration for account fetcher behavior
class AccountFetcherConfig {
  /// Whether to enable caching
  final bool enableCaching;

  /// Cache timeout duration
  final Duration cacheTimeout;

  /// Maximum cache size (number of entries)
  final int maxCacheSize;

  /// Batch fetch delay for optimization
  final Duration batchDelay;

  /// Maximum batch size
  final int maxBatchSize;

  const AccountFetcherConfig({
    this.enableCaching = true,
    this.cacheTimeout = const Duration(minutes: 5),
    this.maxCacheSize = 1000,
    this.batchDelay = const Duration(milliseconds: 50),
    this.maxBatchSize = 100,
  });
}

/// Cached account data with metadata
class CachedAccountData<T> {
  final T data;
  final DateTime timestamp;
  final int? slot;

  const CachedAccountData({
    required this.data,
    required this.timestamp,
    this.slot,
  });

  bool isExpired(Duration timeout) {
    return DateTime.now().difference(timestamp) > timeout;
  }
}

/// Account data with RPC context
class AccountWithContext<T> {
  final T data;
  final RpcResponseContext context;

  const AccountWithContext({
    required this.data,
    required this.context,
  });
}

/// Program account with address and data
class ProgramAccount<T> {
  final PublicKey publicKey;
  final T account;

  const ProgramAccount({
    required this.publicKey,
    required this.account,
  });

  @override
  String toString() {
    return 'ProgramAccount(publicKey: $publicKey, account: $account)';
  }
}

/// Account subscription management
class AccountSubscription<T> {
  final PublicKey address;
  final StreamController<T> controller;
  final Commitment? commitment;
  late final Stream<T> stream;

  AccountSubscription({
    required this.address,
    required this.controller,
    this.commitment,
  }) {
    stream = controller.stream;
  }

  Future<void> cancel() async {
    await controller.close();
  }
}

/// Cache performance statistics
class CacheStatistics {
  final int totalEntries;
  final int validEntries;
  final int expiredEntries;

  const CacheStatistics({
    required this.totalEntries,
    required this.validEntries,
    required this.expiredEntries,
  });

  double get hitRate {
    if (totalEntries == 0) return 0.0;
    return validEntries / totalEntries;
  }

  @override
  String toString() {
    return 'CacheStatistics(total: $totalEntries, valid: $validEntries, '
        'expired: $expiredEntries, hitRate: ${(hitRate * 100).toStringAsFixed(1)}%)';
  }
}

/// RPC response context information
class RpcResponseContext {
  final int slot;

  const RpcResponseContext({
    required this.slot,
  });
}
