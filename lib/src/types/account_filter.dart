/// Account filter types for Solana account filtering
/// Provides TypeScript SDK compatible account filtering functionality

library;

import 'dart:typed_data';

/// Base class for account filters used in getProgramAccounts calls
/// Matches TypeScript SDK AccountFilter functionality
abstract class AccountFilter {
  const AccountFilter();
  
  /// Convert filter to JSON for RPC calls
  Map<String, dynamic> toJson();
}

/// Memory comparison filter - matches specific data at an offset
/// Equivalent to anchor/ts memcmp filter
class MemcmpFilter extends AccountFilter {
  final int offset;
  final String bytes;
  
  const MemcmpFilter({
    required this.offset,
    required this.bytes,
  });
  
  @override
  Map<String, dynamic> toJson() => {
    'memcmp': {
      'offset': offset,
      'bytes': bytes,
    }
  };
}

/// Data size filter - matches accounts with specific data size
/// Equivalent to anchor/ts dataSize filter
class DataSizeFilter extends AccountFilter {
  final int dataSize;
  
  const DataSizeFilter(this.dataSize);
  
  @override
  Map<String, dynamic> toJson() => {
    'dataSize': dataSize,
  };
}

/// Convenience factory for creating filters
class AccountFilters {
  static MemcmpFilter memcmp({required int offset, required String bytes}) =>
      MemcmpFilter(offset: offset, bytes: bytes);
  
  static MemcmpFilter memcmpFromBuffer({required int offset, required Uint8List buffer}) =>
      MemcmpFilter(offset: offset, bytes: buffer.toString());
      
  static DataSizeFilter dataSize(int size) => DataSizeFilter(size);
}
