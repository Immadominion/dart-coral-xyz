/// PDA (Program Derived Address) caching system
///
/// This module provides caching capabilities for computed PDAs to improve
/// performance in synchronous API calls and reduce redundant computations.

library;

import 'dart:convert';
import 'package:coral_xyz_anchor/src/types/public_key.dart';

/// Global PDA cache for storing computed program derived addresses
class PdaCache {
  static final Map<String, PublicKey> _cache = {};
  static final Map<String, Map<String, dynamic>> _resolvedAccountsCache = {};

  /// Generate cache key for PDA
  static String _generatePdaKey(List<List<int>> seeds, PublicKey programId) {
    final seedsStr = seeds.map(base64Encode).join(':');
    return '$seedsStr:${programId.toBase58()}';
  }

  /// Generate cache key for resolved accounts
  static String _generateAccountsKey(
      Map<String, dynamic> accounts, PublicKey programId,) {
    final accountsJson = jsonEncode(accounts);
    final accountsHash = accountsJson.hashCode;
    return '${programId.toBase58()}:$accountsHash';
  }

  /// Get cached PDA
  static PublicKey? getCachedPda(List<List<int>> seeds, PublicKey programId) {
    final key = _generatePdaKey(seeds, programId);
    return _cache[key];
  }

  /// Cache a computed PDA
  static void setCachedPda(
      List<List<int>> seeds, PublicKey programId, PublicKey pda,) {
    final key = _generatePdaKey(seeds, programId);
    _cache[key] = pda;
  }

  /// Get cached resolved accounts
  static Map<String, dynamic>? getCachedResults(
      Map<String, dynamic> accounts, PublicKey programId,) {
    final key = _generateAccountsKey(accounts, programId);
    return _resolvedAccountsCache[key];
  }

  /// Cache resolved accounts
  static void setCachedResults(Map<String, dynamic> accounts,
      PublicKey programId, Map<String, dynamic> resolved,) {
    final key = _generateAccountsKey(accounts, programId);
    _resolvedAccountsCache[key] = Map<String, dynamic>.from(resolved);
  }

  /// Clear all cached PDAs
  static void clearPdaCache() {
    _cache.clear();
  }

  /// Clear all cached resolved accounts
  static void clearAccountsCache() {
    _resolvedAccountsCache.clear();
  }

  /// Clear all caches
  static void clearAll() {
    clearPdaCache();
    clearAccountsCache();
  }

  /// Get cache statistics
  static CacheStatistics getStatistics() => CacheStatistics(
      pdaCacheSize: _cache.length,
      accountsCacheSize: _resolvedAccountsCache.length,
    );

  /// Remove old entries from cache (simple LRU-like cleanup)
  static void cleanup({int maxPdaEntries = 1000, int maxAccountEntries = 500}) {
    if (_cache.length > maxPdaEntries) {
      final keysToRemove = _cache.keys.take(_cache.length - maxPdaEntries);
      for (final key in keysToRemove) {
        _cache.remove(key);
      }
    }

    if (_resolvedAccountsCache.length > maxAccountEntries) {
      final keysToRemove = _resolvedAccountsCache.keys
          .take(_resolvedAccountsCache.length - maxAccountEntries);
      for (final key in keysToRemove) {
        _resolvedAccountsCache.remove(key);
      }
    }
  }
}

/// PDA cache statistics
class CacheStatistics {

  const CacheStatistics({
    required this.pdaCacheSize,
    required this.accountsCacheSize,
  });
  final int pdaCacheSize;
  final int accountsCacheSize;

  @override
  String toString() => 'CacheStatistics(pdaCacheSize: $pdaCacheSize, accountsCacheSize: $accountsCacheSize)';
}
