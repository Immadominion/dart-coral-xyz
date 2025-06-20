/// Solana commitment level definitions
///
/// This module defines the various commitment levels used by Solana
/// for transaction confirmations and account state consistency.

library;

/// Commitment level for Solana transactions and queries
///
/// These levels indicate how confirmed a transaction should be
/// before being considered "final" by the client.
enum Commitment {
  /// The most recent block processed by the RPC node
  /// - Lowest latency, highest risk of rollback
  /// - Not recommended for production use
  processed('processed'),

  /// The most recent block that has been voted on by supermajority
  /// - Medium latency and risk
  /// - Good balance for most applications
  confirmed('confirmed'),

  /// The most recent block that has been finalized
  /// - Highest latency, lowest risk
  /// - Recommended for high-value transactions
  finalized('finalized'),

  /// Alias for finalized (legacy compatibility)
  max('max'),

  /// Alias for finalized (legacy compatibility)
  root('root'),

  /// Alias for confirmed (legacy compatibility)
  single('single'),

  /// Alias for confirmed (legacy compatibility)
  singleGossip('singleGossip'),

  /// Alias for confirmed (legacy compatibility)
  recent('recent');

  const Commitment(this.value);

  /// The string value used in RPC calls
  final String value;

  /// Convert from string value
  static Commitment fromString(String value) {
    switch (value.toLowerCase()) {
      case 'processed':
        return Commitment.processed;
      case 'confirmed':
        return Commitment.confirmed;
      case 'finalized':
        return Commitment.finalized;
      case 'max':
        return Commitment.max;
      case 'root':
        return Commitment.root;
      case 'single':
        return Commitment.single;
      case 'singlegossip':
        return Commitment.singleGossip;
      case 'recent':
        return Commitment.recent;
      default:
        throw ArgumentError('Unknown commitment level: $value');
    }
  }

  @override
  String toString() => value;
}

/// Configuration for commitment in RPC requests
class CommitmentConfig {
  final Commitment commitment;

  const CommitmentConfig(this.commitment);

  /// Convert to JSON representation for RPC calls
  Map<String, dynamic> toJson() {
    return {'commitment': commitment.value};
  }

  /// Create from JSON
  factory CommitmentConfig.fromJson(Map<String, dynamic> json) {
    final commitmentStr = json['commitment'] as String? ?? 'finalized';
    return CommitmentConfig(Commitment.fromString(commitmentStr));
  }

  @override
  String toString() => 'CommitmentConfig(${commitment.value})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CommitmentConfig && other.commitment == commitment;
  }

  @override
  int get hashCode => commitment.hashCode;
}

/// Convenience constructors for common commitment configurations
class CommitmentConfigs {
  /// Processed commitment (fastest, least secure)
  static const processed = CommitmentConfig(Commitment.processed);

  /// Confirmed commitment (balanced)
  static const confirmed = CommitmentConfig(Commitment.confirmed);

  /// Finalized commitment (slowest, most secure)
  static const finalized = CommitmentConfig(Commitment.finalized);

  /// Default commitment level (finalized)
  static const defaultConfig = finalized;
}
