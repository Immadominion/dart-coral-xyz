import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';

import '../../types/public_key.dart';
import '../../coder/main_coder.dart';
import '../../idl/idl.dart';
import '../../provider/anchor_provider.dart';
import '../../provider/connection.dart';
import '../../types/transaction.dart';

/// The account namespace provides handles to AccountClient objects for each
/// account type in a program.
///
/// ## Usage
///
/// ```dart
/// final account = await program.account.accountType.fetch(address);
/// ```
class AccountNamespace {
  final Map<String, AccountClient> _clients = {};

  AccountNamespace._();

  /// Build account namespace from IDL
  static AccountNamespace build({
    required Idl idl,
    required Coder coder,
    required PublicKey programId,
    required AnchorProvider provider,
  }) {
    final namespace = AccountNamespace._();

    // Create account clients for each IDL account
    if (idl.accounts != null) {
      for (final account in idl.accounts!) {
        namespace._clients[account.name] = AccountClient(
          account: account,
          coder: coder,
          programId: programId,
          provider: provider,
        );
      }
    }

    return namespace;
  }

  /// Get an account client by name
  AccountClient? operator [](String name) => _clients[name];

  /// Get all account type names
  Iterable<String> get names => _clients.keys;

  /// Check if an account type exists
  bool contains(String name) => _clients.containsKey(name);

  @override
  String toString() {
    return 'AccountNamespace(accounts: ${_clients.keys.toList()})';
  }
}

/// Client for fetching and managing accounts of a specific type
class AccountClient {
  final IdlAccount _account;
  final Coder _coder;
  final PublicKey _programId;
  final AnchorProvider _provider;

  // Account caching
  final Map<String, _CachedAccount> _cache = {};
  final Duration _cacheTimeout;

  // Subscriptions
  final Map<String, StreamController<Map<String, dynamic>>> _subscriptions = {};

  AccountClient({
    required IdlAccount account,
    required Coder coder,
    required PublicKey programId,
    required AnchorProvider provider,
    Duration cacheTimeout = const Duration(minutes: 5),
  })  : _account = account,
        _coder = coder,
        _programId = programId,
        _provider = provider,
        _cacheTimeout = cacheTimeout;

  /// Fetch an account by its public key
  Future<Map<String, dynamic>?> fetch(
    PublicKey address, {
    bool useCache = true,
  }) async {
    try {
      // Check cache first if enabled
      if (useCache) {
        final cached = _cache[address.toBase58()];
        if (cached != null && !cached.isExpired(_cacheTimeout)) {
          return cached.data;
        }
      }

      // Fetch account data from the blockchain
      final accountInfo = await _provider.connection.getAccountInfo(address);

      if (accountInfo == null) {
        return null;
      }

      // Verify this account belongs to our program
      if (accountInfo.owner.toBase58() != _programId.toBase58()) {
        return null;
      }

      // Decode the account data
      final decodedData = accountInfo.data != null
          ? (accountInfo.data is String
              ? base64.decode(accountInfo.data as String)
              : accountInfo.data as Uint8List)
          : Uint8List(0);
      final data = _decodeAccountData(decodedData);

      // Update cache if enabled and data is valid
      if (useCache && data != null) {
        _cache[address.toBase58()] = _CachedAccount(data, DateTime.now());
      }

      return data;
    } catch (error) {
      return null;
    }
  }

  /// Fetch multiple accounts by their public keys
  Future<List<Map<String, dynamic>?>> fetchMultiple(
    List<PublicKey> addresses,
  ) async {
    try {
      // Use batch fetching for efficiency
      final accountInfos =
          await _provider.connection.getMultipleAccountsInfo(addresses);

      final results = <Map<String, dynamic>?>[];
      for (int i = 0; i < accountInfos.length; i++) {
        final accountInfo = accountInfos[i];

        if (accountInfo == null) {
          results.add(null);
          continue;
        }

        // Verify this account belongs to our program
        if (accountInfo.owner.toBase58() != _programId.toBase58()) {
          results.add(null);
          continue;
        }

        // Decode the account data
        final decodedData = accountInfo.data != null
            ? (accountInfo.data is String
                ? base64.decode(accountInfo.data as String)
                : accountInfo.data as Uint8List)
            : Uint8List(0);
        results.add(_decodeAccountData(decodedData));
      }

      return results;
    } catch (error) {
      // Return list of nulls if batch fetch fails
      return List.filled(addresses.length, null);
    }
  }

  /// Fetch all accounts of this type from the program
  ///
  /// [filters] - Optional filters to apply to the search
  /// [sort] - Optional sort comparison function
  /// [limit] - Optional limit on number of results
  Future<List<ProgramAccount>> fetchAll({
    List<AccountFilter>? filters,
    int Function(ProgramAccount a, ProgramAccount b)? sort,
    int? limit,
  }) async {
    try {
      // Build filters including discriminator
      final allFilters = <AccountFilter>[];

      // Add discriminator filter to ensure we only get accounts of this type
      final discriminator = _coder.accounts.accountDiscriminator(_account.name);
      if (discriminator.isNotEmpty) {
        allFilters.add(MemcmpFilter(
          offset: 0,
          bytes: base64.encode(discriminator),
        ));
      }

      // Add user-provided filters
      if (filters != null) {
        allFilters.addAll(filters);
      }

      // Fetch program accounts
      final programAccounts = await _provider.connection.getProgramAccounts(
        _programId,
        filters: allFilters,
      );

      // Decode and convert to ProgramAccount instances
      var results = <ProgramAccount>[];
      for (final programAccount in programAccounts) {
        final decodedData = programAccount.account.data != null
            ? (programAccount.account.data is String
                ? base64.decode(programAccount.account.data as String)
                : programAccount.account.data as Uint8List)
            : Uint8List(0);
        final accountData = _decodeAccountData(decodedData);

        if (accountData != null) {
          results.add(ProgramAccount(
            publicKey: programAccount.pubkey,
            account: accountData,
          ));
        }
      }

      // Apply sorting if provided
      if (sort != null) {
        results.sort(sort);
      }

      // Apply limit if provided
      if (limit != null && limit > 0) {
        results = results.take(limit).toList();
      }

      return results;
    } catch (error) {
      return [];
    }
  }

  /// Get the size of this account type in bytes
  int get size {
    return _coder.accounts.size(_account.name);
  }

  /// Get the discriminator for this account type
  List<int> get discriminator {
    return _coder.accounts.accountDiscriminator(_account.name);
  }

  /// Create a subscription to account changes
  Stream<Map<String, dynamic>> subscribe(PublicKey address) {
    final addressString = address.toBase58();

    // Check if subscription already exists
    if (_subscriptions.containsKey(addressString)) {
      return _subscriptions[addressString]!.stream;
    }

    // Create new subscription
    final controller = StreamController<Map<String, dynamic>>.broadcast();
    _subscriptions[addressString] = controller;

    // Set up periodic polling (in a real implementation, this would use WebSocket)
    Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final data = await fetch(address, useCache: false);
        if (data != null && !controller.isClosed) {
          controller.add(data);
        }
      } catch (error) {
        if (!controller.isClosed) {
          controller.addError(error);
        }
      }
    });

    // Handle subscription cleanup
    controller.onCancel = () {
      _subscriptions.remove(addressString);
    };

    return controller.stream;
  }

  /// Unsubscribe from account changes
  void unsubscribe(PublicKey address) {
    final addressString = address.toBase58();
    final controller = _subscriptions.remove(addressString);
    controller?.close();
  }

  /// Clear all caches
  void clearCache() {
    _cache.clear();
  }

  /// Clear expired cache entries
  void clearExpiredCache() {
    _cache.removeWhere((key, cached) => cached.isExpired(_cacheTimeout));
  }

  /// Decode account data using the account coder
  Map<String, dynamic>? _decodeAccountData(List<int> data) {
    if (data.isEmpty) return null;

    try {
      return _coder.accounts.decode(_account.name, Uint8List.fromList(data));
    } catch (error) {
      return null;
    }
  }

  /// Get the account name
  String get name => _account.name;

  /// Create an instruction for creating this account
  ///
  /// This creates a SystemProgram.createAccount instruction with the correct
  /// space allocation and rent exemption for this account type.
  ///
  /// [signer] - The keypair that will sign and own the new account
  /// [sizeOverride] - Override the default account size
  /// [fromPubkey] - The account that will pay for rent (defaults to provider wallet)
  Future<TransactionInstruction> createInstruction(
    PublicKey signer, {
    int? sizeOverride,
    PublicKey? fromPubkey,
  }) async {
    final accountSize = sizeOverride ?? size;
    final payer = fromPubkey ?? _provider.wallet?.publicKey;

    if (payer == null) {
      throw Exception(
        'Cannot create account instruction: no payer available. '
        'Provide fromPubkey parameter or ensure provider wallet has publicKey.',
      );
    }

    // Calculate rent exemption
    final rentExemptAmount = await _provider.connection
        .getMinimumBalanceForRentExemption(accountSize);

    return TransactionInstruction(
      programId: PublicKey.fromBase58(
          '11111111111111111111111111111111'), // System Program
      accounts: [
        AccountMeta(pubkey: payer, isSigner: true, isWritable: true),
        AccountMeta(pubkey: signer, isSigner: true, isWritable: true),
      ],
      data: Uint8List.fromList(_encodeCreateAccountInstruction(
        lamports: rentExemptAmount,
        space: accountSize,
        owner: _programId,
      )),
    );
  }

  /// Calculate the minimum balance required for rent exemption
  ///
  /// [sizeOverride] - Override the default account size
  Future<int> getMinimumBalanceForRentExemption([int? sizeOverride]) async {
    final accountSize = sizeOverride ?? size;
    return await _provider.connection
        .getMinimumBalanceForRentExemption(accountSize);
  }

  /// Validate that an account is owned by the expected program
  ///
  /// [address] - The account address to validate
  /// [expectedOwner] - The expected owner (defaults to this program)
  Future<bool> validateOwnership(
    PublicKey address, {
    PublicKey? expectedOwner,
  }) async {
    final accountInfo = await _provider.connection.getAccountInfo(address);
    if (accountInfo == null) {
      return false;
    }

    final owner = expectedOwner ?? _programId;
    return accountInfo.owner.toBase58() == owner.toBase58();
  }

  /// Create an instruction to close an account and transfer remaining lamports
  ///
  /// [accountToClose] - The account to close
  /// [destination] - Where to send the remaining lamports
  /// [authority] - The authority that can close the account (usually the owner)
  TransactionInstruction createCloseInstruction({
    required PublicKey accountToClose,
    required PublicKey destination,
    required PublicKey authority,
  }) {
    return TransactionInstruction(
      programId: _programId,
      accounts: [
        AccountMeta(pubkey: accountToClose, isSigner: false, isWritable: true),
        AccountMeta(pubkey: destination, isSigner: false, isWritable: true),
        AccountMeta(pubkey: authority, isSigner: true, isWritable: false),
      ],
      data: Uint8List.fromList(_encodeCloseAccountInstruction()),
    );
  }

  /// Check if an account has sufficient balance for rent exemption
  ///
  /// [address] - The account address to check
  /// [sizeOverride] - Override the default account size for calculation
  Future<bool> isRentExempt(
    PublicKey address, {
    int? sizeOverride,
  }) async {
    final accountInfo = await _provider.connection.getAccountInfo(address);
    if (accountInfo == null) {
      return false;
    }

    final accountSize = sizeOverride ?? size;
    final requiredBalance = await _provider.connection
        .getMinimumBalanceForRentExemption(accountSize);

    return accountInfo.lamports >= requiredBalance;
  }

  /// Reallocate account space
  ///
  /// Note: This is a placeholder for reallocation functionality.
  /// In practice, reallocation is handled by specific program instructions
  /// that use the realloc constraint in Anchor programs.
  ///
  /// [address] - The account to reallocate
  /// [newSize] - The new size for the account
  /// [payer] - The account that pays for additional rent (if increasing size)
  Future<TransactionInstruction> createReallocInstruction({
    required PublicKey address,
    required int newSize,
    required PublicKey payer,
  }) async {
    // This would typically be implemented as part of a specific program instruction
    // that includes the realloc constraint. For now, we'll throw an error indicating
    // this should be handled by the specific program.
    throw UnsupportedError(
      'Account reallocation must be implemented by the specific program using '
      'Anchor realloc constraints. This is not a standalone instruction.',
    );
  }

  /// Calculate account data size including discriminator
  ///
  /// Returns the total size needed for this account type including
  /// the 8-byte discriminator that Anchor adds to all accounts.
  int get totalSize {
    return 8 + size; // 8 bytes for discriminator + account data size
  }

  /// Check if an account exists and is initialized
  ///
  /// [address] - The account address to check
  Future<bool> exists(PublicKey address) async {
    final accountInfo = await _provider.connection.getAccountInfo(address);
    if (accountInfo == null) {
      return false;
    }

    // Check if it's owned by our program and has the correct discriminator
    if (accountInfo.owner.toBase58() != _programId.toBase58()) {
      return false;
    }

    if (accountInfo.data == null ||
        accountInfo.data!.isEmpty ||
        accountInfo.data!.length < 8) {
      return false;
    }

    // Verify discriminator
    final decodedData = accountInfo.data != null
        ? (accountInfo.data is String
            ? base64.decode(accountInfo.data as String)
            : accountInfo.data as Uint8List)
        : Uint8List(0);
    final expectedDiscriminator = discriminator;

    if (decodedData.length < expectedDiscriminator.length) {
      return false;
    }

    for (int i = 0; i < expectedDiscriminator.length; i++) {
      if (decodedData[i] != expectedDiscriminator[i]) {
        return false;
      }
    }

    return true;
  }

  /// Encode a SystemProgram.createAccount instruction
  List<int> _encodeCreateAccountInstruction({
    required int lamports,
    required int space,
    required PublicKey owner,
  }) {
    // SystemProgram.createAccount has discriminator [0, 0, 0, 0]
    final buffer = <int>[];

    // Add instruction discriminator (4 bytes)
    buffer.addAll([0, 0, 0, 0]);

    // Add lamports (8 bytes, little endian)
    buffer.addAll(_encodeU64(lamports));

    // Add space (8 bytes, little endian)
    buffer.addAll(_encodeU64(space));

    // Add owner (32 bytes)
    buffer.addAll(owner.toBytes());

    return buffer;
  }

  /// Encode a close account instruction
  List<int> _encodeCloseAccountInstruction() {
    // This would need to be implemented based on the specific program's
    // close instruction format. For now, return empty data as a placeholder.
    return [];
  }

  /// Encode a u64 value as little-endian bytes
  List<int> _encodeU64(int value) {
    final bytes = <int>[];
    for (int i = 0; i < 8; i++) {
      bytes.add((value >> (i * 8)) & 0xFF);
    }
    return bytes;
  }

  @override
  String toString() {
    return 'AccountClient(name: ${_account.name})';
  }
}

/// A program account with its address and decoded data
class ProgramAccount {
  /// The account's public key
  final PublicKey publicKey;

  /// The decoded account data
  final Map<String, dynamic> account;

  const ProgramAccount({
    required this.publicKey,
    required this.account,
  });

  @override
  String toString() {
    return 'ProgramAccount(publicKey: $publicKey, account: $account)';
  }
}

/// Cached account data with timestamp
class _CachedAccount {
  final Map<String, dynamic> data;
  final DateTime timestamp;

  _CachedAccount(this.data, this.timestamp);

  bool isExpired(Duration timeout) {
    return DateTime.now().difference(timestamp) > timeout;
  }
}
