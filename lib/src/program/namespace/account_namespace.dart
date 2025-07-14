import 'package:coral_xyz_anchor/src/types/public_key.dart';
import 'package:coral_xyz_anchor/src/types/commitment.dart';
import 'package:coral_xyz_anchor/src/coder/main_coder.dart';
import 'package:coral_xyz_anchor/src/idl/idl.dart';
import 'package:coral_xyz_anchor/src/provider/anchor_provider.dart';
import 'package:coral_xyz_anchor/src/provider/connection.dart';
import 'package:coral_xyz_anchor/src/program/namespace/account_fetcher.dart';

/// The account namespace provides handles to AccountClient objects for each
/// account type in a program.
///
/// ## Usage
///
/// ```dart
/// final account = await program.account.accountType.fetch(address);
/// ```
class AccountNamespace {

  AccountNamespace._();
  final Map<String, AccountClient> _clients = {};

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
  String toString() => 'AccountNamespace(accounts: ${_clients.keys.toList()})';

  /// Dispose of all account clients and clean up subscriptions
  void dispose() {
    for (final client in _clients.values) {
      client.dispose();
    }
  }
}

/// Client for fetching and managing accounts of a specific type
class AccountClient<T> {

  AccountClient({
    required IdlAccount account,
    required Coder coder,
    required PublicKey programId,
    required AnchorProvider provider,
    AccountFetcherConfig? config,
  })  : _fetcher = AccountFetcher<T>(
          idlAccount: account,
          coder: coder,
          programId: programId,
          provider: provider,
          config: config,
        ),
        _idlAccount = account;
  final AccountFetcher<T> _fetcher;
  final IdlAccount _idlAccount;

  /// Fetch an account by its public key
  Future<T?> fetch(
    PublicKey address, {
    Commitment? commitment,
    bool useCache = true,
  }) async => _fetcher.fetchNullable(
      address,
      commitment: commitment,
      useCache: useCache,
    );

  /// Fetch multiple accounts by their public keys
  Future<List<T?>> fetchMultiple(List<PublicKey> addresses) async => _fetcher.fetchMultiple(addresses);

  /// Fetch all accounts of this type based on filters
  Future<List<ProgramAccount<T>>> all() async => _fetcher.all();

  /// Fetch all accounts of this type based on filters (alias for all)
  Future<List<ProgramAccount<T>>> fetchAll({
    List<AccountFilter>? filters,
    Commitment? commitment,
    int?
        limit, // Note: limit parameter is accepted but ignored (for API compatibility)
  }) async => _fetcher.all(
      filters: filters,
      commitment: commitment,
    );

  /// Get the size of this account type in bytes
  int get size => _fetcher.size;

  /// Get the program ID
  PublicKey get programId => _fetcher.programId;

  /// Create a subscription to account changes
  Stream<T?> subscribe(PublicKey address) => _fetcher.subscribe(address);

  /// Unsubscribe from account changes
  void unsubscribe(PublicKey address) {
    _fetcher.unsubscribe(address);
  }

  /// Clear all caches
  void clearCache() {
    _fetcher.clearCache();
  }

  /// Clear expired cache entries (currently aliases clearCache)
  void clearExpiredCache() {
    _fetcher.clearCache();
  }

  /// Get account fetcher for advanced operations
  AccountFetcher<T> get fetcher => _fetcher;

  /// Get the account name
  String get name => _idlAccount.name;

  /// Get the account discriminator
  List<int> get discriminator => _idlAccount.discriminator ?? [];

  /// Dispose of the account client and clean up subscriptions
  void dispose() {
    _fetcher.dispose();
  }
}
