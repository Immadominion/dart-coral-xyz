/// Wrapper for Solana RPC client functionality
///
/// This module provides a consistent interface to Solana RPC operations
/// by wrapping the external solana package and providing additional
/// Anchor-specific functionality.

library;

import 'dart:typed_data';
import 'dart:convert';
import 'package:solana/solana.dart' as solana_lib;
import 'package:bs58/bs58.dart';
import '../error/rpc_error_parser.dart';

/// Wrapper around the Solana RPC client providing Anchor-specific enhancements
class SolanaRpcWrapper {
  final solana_lib.SolanaClient _client;

  SolanaRpcWrapper(String rpcUrl)
      : _client = solana_lib.SolanaClient(
          rpcUrl: Uri.parse(rpcUrl),
          websocketUrl: Uri.parse(rpcUrl.replaceFirst('http', 'ws')),
        );

  /// Get the underlying Solana client for direct access when needed
  solana_lib.SolanaClient get client => _client;

  /// Get account information with enhanced error handling
  Future<Map<String, dynamic>?> getAccountInfo(String address) async {
    try {
      // Note: Using dynamic return type as the actual API structure may vary
      final result = await _client.rpcClient.getAccountInfo(address);
      return result as Map<String, dynamic>?;
    } catch (e) {
      // Enhanced error handling for Anchor-specific scenarios
      throw SolanaRpcException('Failed to get account info for $address: $e');
    }
  }

  /// Get multiple accounts in a single RPC call
  /// TODO: Implement proper typing when API is stabilized
  Future<List<Map<String, dynamic>?>> getMultipleAccounts(
    List<String> addresses,
  ) async {
    try {
      // Call the API but use placeholder return for now
      await _client.rpcClient.getMultipleAccounts(addresses);
      // For now, return a placeholder structure
      return List<Map<String, dynamic>?>.generate(
          addresses.length, (index) => null);
    } catch (e) {
      throw SolanaRpcException('Failed to get multiple accounts: $e');
    }
  }

  /// Send and confirm transaction with enhanced options
  Future<String> sendAndConfirmTransaction(
    Map<String, dynamic> transactionData, {
    String? commitment,
  }) async {
    try {
      print(
          'DEBUG: Preparing transaction with ${transactionData['transaction']?['instructions']?.length ?? 0} instructions');

      // Extract transaction and signatures from the data
      final transaction =
          transactionData['transaction'] as Map<String, dynamic>? ??
              transactionData;
      final providedSignatures =
          transactionData['signatures'] as Map<String, Uint8List>? ?? {};
      final signatureCallback = transactionData['signatureCallback']
          as Future<Map<String, Uint8List>> Function(Uint8List)?;

      print('DEBUG: Transaction data keys: ${transactionData.keys.toList()}');
      print('DEBUG: Provided signatures count: ${providedSignatures.length}');
      print('DEBUG: Has signature callback: ${signatureCallback != null}');

      // Always fetch a fresh blockhash to ensure it's not expired
      // Even if transaction has a blockhash, we should use a fresh one for better reliability
      late final String recentBlockhash;
      try {
        print('DEBUG: Fetching fresh blockhash for transaction...');
        final blockhashResult = await _client.rpcClient.getLatestBlockhash();
        // Extract the actual blockhash string from the result
        final latestBlockhash = blockhashResult.value;
        recentBlockhash = latestBlockhash.blockhash;
        print('DEBUG: Retrieved fresh blockhash: $recentBlockhash');
      } catch (e) {
        print(
            'WARNING: Failed to fetch fresh blockhash, falling back to provided: $e');
        // Only fall back to provided blockhash if fresh fetch fails
        if (transaction['recentBlockhash'] != null) {
          recentBlockhash = transaction['recentBlockhash'] as String;
          print('DEBUG: Using provided blockhash: $recentBlockhash');
        } else {
          throw SolanaRpcException(
              'Failed to get blockhash and none provided: $e');
        }
      }

      // First, build the transaction message to get the bytes that need to be signed
      final messageBytes =
          _buildTransactionMessage(transaction, recentBlockhash);
      print('DEBUG: Built transaction message: ${messageBytes.length} bytes');

      // Get additional signatures from the callback if provided
      final signatures = <String, Uint8List>{};
      signatures.addAll(providedSignatures);

      if (signatureCallback != null) {
        print('DEBUG: Getting signatures from wallet...');
        final additionalSignatures = await signatureCallback(messageBytes);
        signatures.addAll(additionalSignatures);
        print(
            'DEBUG: Got ${additionalSignatures.length} additional signatures from wallet');
      }

      // Build the transaction in Solana's expected format with real signatures
      final serializedTransaction =
          _buildSolanaTransaction(transaction, recentBlockhash, signatures);

      print('DEBUG: Sending transaction to Solana network...');

      // Send the transaction using the raw RPC client
      final signature =
          await _client.rpcClient.sendTransaction(serializedTransaction);

      print('DEBUG: Transaction sent with signature: $signature');

      // TODO: Add confirmation polling here
      // We should poll getSignatureStatuses to wait for confirmation
      // For now, we'll return the signature immediately

      return signature;
    } catch (e) {
      print('ERROR: Failed to send transaction: $e');

      // Use RpcErrorParser to enhance error information
      final enhancedError = translateRpcError(e);
      throw SolanaRpcException(
          'Failed to send transaction: ${enhancedError.toString()}');
    }
  }

  /// Build a Solana transaction in the expected wire format
  String _buildSolanaTransaction(Map<String, dynamic> transaction,
      String recentBlockhash, Map<String, Uint8List> signatures) {
    try {
      print('DEBUG: Building transaction with blockhash: $recentBlockhash');

      // Extract transaction components
      final instructions = transaction['instructions'] as List<dynamic>? ?? [];
      final feePayerAddress = transaction['feePayer'] as String?;

      print('DEBUG: Transaction has ${instructions.length} instructions');
      print('DEBUG: Fee payer: $feePayerAddress');

      // Collect all account addresses referenced in the transaction
      final accountAddresses = <String>[];
      final addressToIndex = <String, int>{};

      // Add fee payer first (required to be index 0)
      if (feePayerAddress != null) {
        accountAddresses.add(feePayerAddress);
        addressToIndex[feePayerAddress] = 0;
      }

      // Add all accounts from instructions
      for (final instruction in instructions) {
        final instrData = instruction as Map<String, dynamic>;

        // Add program ID
        final programId = instrData['programId'] as String;
        if (!addressToIndex.containsKey(programId)) {
          addressToIndex[programId] = accountAddresses.length;
          accountAddresses.add(programId);
        }

        // Add instruction accounts
        final accounts = instrData['accounts'] as List<dynamic>? ?? [];
        for (final account in accounts) {
          final accData = account as Map<String, dynamic>;
          final pubkey = accData['pubkey'] as String;
          if (!addressToIndex.containsKey(pubkey)) {
            addressToIndex[pubkey] = accountAddresses.length;
            accountAddresses.add(pubkey);
          }
        }
      }

      print('DEBUG: Collected ${accountAddresses.length} unique accounts');

      // Count signers and readonly accounts
      int numRequiredSignatures = 0;
      int numReadonlySignedAccounts = 0;
      int numReadonlyUnsignedAccounts = 0;

      // Track which accounts are signers and writable
      final signerAccounts = <String>{};
      final writableAccounts = <String>{};

      // Fee payer is always a signer and writable
      if (feePayerAddress != null) {
        signerAccounts.add(feePayerAddress);
        writableAccounts.add(feePayerAddress);
        numRequiredSignatures = 1;
      }

      // Analyze instruction accounts
      for (final instruction in instructions) {
        final instrData = instruction as Map<String, dynamic>;
        final accounts = instrData['accounts'] as List<dynamic>? ?? [];

        for (final account in accounts) {
          final accData = account as Map<String, dynamic>;
          final pubkey = accData['pubkey'] as String;
          final isSigner = accData['isSigner'] as bool? ?? false;
          final isWritable = accData['isWritable'] as bool? ?? false;

          if (isSigner && !signerAccounts.contains(pubkey)) {
            signerAccounts.add(pubkey);
            numRequiredSignatures++;
          }

          if (isWritable) {
            writableAccounts.add(pubkey);
          }
        }
      }

      // Sort accounts: signers first, then non-signers
      final sortedAccounts = <String>[];
      final signerAccountsList = accountAddresses
          .where((addr) => signerAccounts.contains(addr))
          .toList();
      final nonSignerAccountsList = accountAddresses
          .where((addr) => !signerAccounts.contains(addr))
          .toList();

      sortedAccounts.addAll(signerAccountsList);
      sortedAccounts.addAll(nonSignerAccountsList);

      // Update address indices after sorting
      addressToIndex.clear();
      for (int i = 0; i < sortedAccounts.length; i++) {
        addressToIndex[sortedAccounts[i]] = i;
      }

      // Count readonly accounts
      for (final addr in signerAccountsList) {
        if (!writableAccounts.contains(addr)) {
          numReadonlySignedAccounts++;
        }
      }

      for (final addr in nonSignerAccountsList) {
        if (!writableAccounts.contains(addr)) {
          numReadonlyUnsignedAccounts++;
        }
      }

      print('DEBUG: Signatures required: $numRequiredSignatures');
      print('DEBUG: Readonly signed: $numReadonlySignedAccounts');
      print('DEBUG: Readonly unsigned: $numReadonlyUnsignedAccounts');

      // Build the message
      final messageData = BytesBuilder();

      // Message header (3 bytes)
      messageData.addByte(numRequiredSignatures);
      messageData.addByte(numReadonlySignedAccounts);
      messageData.addByte(numReadonlyUnsignedAccounts);

      // Account addresses (compact array)
      _writeCompactArrayLength(messageData, sortedAccounts.length);
      for (final address in sortedAccounts) {
        final pubkeyBytes = base58.decode(address);
        if (pubkeyBytes.length != 32) {
          throw Exception('Invalid public key length: ${pubkeyBytes.length}');
        }
        messageData.add(pubkeyBytes);
      }

      // Recent blockhash (32 bytes)
      final blockhashBytes = base58.decode(recentBlockhash);
      if (blockhashBytes.length != 32) {
        throw Exception('Invalid blockhash length: ${blockhashBytes.length}');
      }
      messageData.add(blockhashBytes);

      // Instructions (compact array)
      _writeCompactArrayLength(messageData, instructions.length);
      for (final instruction in instructions) {
        final instrData = instruction as Map<String, dynamic>;

        // Program ID index
        final programId = instrData['programId'] as String;
        final programIndex = addressToIndex[programId]!;
        messageData.addByte(programIndex);

        // Account indices
        final accounts = instrData['accounts'] as List<dynamic>? ?? [];
        _writeCompactArrayLength(messageData, accounts.length);
        for (final account in accounts) {
          final accData = account as Map<String, dynamic>;
          final pubkey = accData['pubkey'] as String;
          final accountIndex = addressToIndex[pubkey]!;
          messageData.addByte(accountIndex);
        }

        // Instruction data
        final data = instrData['data'] as Uint8List;
        _writeCompactArrayLength(messageData, data.length);
        messageData.add(data);
      }

      final messageBytes = messageData.toBytes();
      print('DEBUG: Message serialized: ${messageBytes.length} bytes');

      // Build legacy transaction (no version prefix)
      final transactionData = BytesBuilder();

      // Number of signatures (compact array length)
      _writeCompactArrayLength(transactionData, numRequiredSignatures);

      // Add real signatures for each signer account
      for (final signerAddress in signerAccountsList) {
        if (signatures.containsKey(signerAddress)) {
          final signature = signatures[signerAddress]!;
          if (signature.length != 64) {
            throw Exception(
                'Invalid signature length for $signerAddress: ${signature.length}, expected 64 bytes');
          }
          transactionData.add(signature);
          print('DEBUG: Added signature for $signerAddress');
        } else {
          throw Exception(
              'Missing signature for required signer: $signerAddress');
        }
      }

      // Message
      transactionData.add(messageBytes);

      final transactionBytes = transactionData.toBytes();
      print('DEBUG: Complete transaction: ${transactionBytes.length} bytes');

      // Encode as base64 for transmission (Solana RPC expects base64)
      final base64Transaction = base64Encode(transactionBytes);
      print('DEBUG: Base64 transaction length: ${base64Transaction.length}');

      return base64Transaction;
    } catch (e, stackTrace) {
      print('ERROR: Failed to build transaction: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Write a compact array length encoding (used in Solana serialization)
  void _writeCompactArrayLength(BytesBuilder builder, int length) {
    if (length < 0x80) {
      builder.addByte(length);
    } else if (length < 0x4000) {
      builder.addByte((length & 0x7F) | 0x80);
      builder.addByte(length >> 7);
    } else if (length < 0x200000) {
      builder.addByte((length & 0x7F) | 0x80);
      builder.addByte(((length >> 7) & 0x7F) | 0x80);
      builder.addByte(length >> 14);
    } else {
      throw Exception('Array length too large: $length');
    }
  }

  /// Get latest blockhash
  /// TODO: Implement proper typing when API is stabilized
  Future<Map<String, dynamic>> getLatestBlockhash() async {
    try {
      final result = await _client.rpcClient.getLatestBlockhash();
      return {'blockhash': result.toString(), 'lastValidBlockHeight': 0};
    } catch (e) {
      throw SolanaRpcException('Failed to get latest blockhash: $e');
    }
  }

  /// Subscribe to account changes (WebSocket)
  /// TODO: Implement when subscription API is available
  Stream<Map<String, dynamic>> subscribeToAccount(String address) {
    throw UnimplementedError(
        'Account subscription will be implemented in Phase 4');
  }

  /// Subscribe to program account changes
  /// TODO: Implement when subscription API is available
  Stream<List<Map<String, dynamic>>> subscribeToProgramAccounts(
    String programId, {
    String? commitment,
  }) {
    throw UnimplementedError(
        'Program account subscription will be implemented in Phase 4');
  }

  /// Build a transaction message for signing (without signatures)
  /// Returns the transaction message bytes that need to be signed
  Uint8List buildTransactionMessage(
      Map<String, dynamic> transaction, String recentBlockhash) {
    try {
      print(
          'DEBUG: Building transaction message for signing with blockhash: $recentBlockhash');

      // Extract transaction components
      final instructions = transaction['instructions'] as List<dynamic>? ?? [];
      final feePayerAddress = transaction['feePayer'] as String?;

      print('DEBUG: Transaction has ${instructions.length} instructions');
      print('DEBUG: Fee payer: $feePayerAddress');

      // Collect all account addresses referenced in the transaction
      final accountAddresses = <String>[];
      final addressToIndex = <String, int>{};

      // Add fee payer first (required to be index 0)
      if (feePayerAddress != null) {
        accountAddresses.add(feePayerAddress);
        addressToIndex[feePayerAddress] = 0;
      }

      // Add all accounts from instructions
      for (final instruction in instructions) {
        final instrData = instruction as Map<String, dynamic>;

        // Add program ID
        final programId = instrData['programId'] as String;
        if (!addressToIndex.containsKey(programId)) {
          addressToIndex[programId] = accountAddresses.length;
          accountAddresses.add(programId);
        }

        // Add instruction accounts
        final accounts = instrData['accounts'] as List<dynamic>? ?? [];
        for (final account in accounts) {
          final accData = account as Map<String, dynamic>;
          final pubkey = accData['pubkey'] as String;
          if (!addressToIndex.containsKey(pubkey)) {
            addressToIndex[pubkey] = accountAddresses.length;
            accountAddresses.add(pubkey);
          }
        }
      }

      print('DEBUG: Collected ${accountAddresses.length} unique accounts');

      // Count signers and readonly accounts
      int numRequiredSignatures = 0;
      int numReadonlySignedAccounts = 0;
      int numReadonlyUnsignedAccounts = 0;

      // Track which accounts are signers and writable
      final signerAccounts = <String>{};
      final writableAccounts = <String>{};

      // Fee payer is always a signer and writable
      if (feePayerAddress != null) {
        signerAccounts.add(feePayerAddress);
        writableAccounts.add(feePayerAddress);
        numRequiredSignatures = 1;
      }

      // Analyze instruction accounts
      for (final instruction in instructions) {
        final instrData = instruction as Map<String, dynamic>;
        final accounts = instrData['accounts'] as List<dynamic>? ?? [];

        for (final account in accounts) {
          final accData = account as Map<String, dynamic>;
          final pubkey = accData['pubkey'] as String;
          final isSigner = accData['isSigner'] as bool? ?? false;
          final isWritable = accData['isWritable'] as bool? ?? false;

          if (isSigner && !signerAccounts.contains(pubkey)) {
            signerAccounts.add(pubkey);
            numRequiredSignatures++;
          }

          if (isWritable) {
            writableAccounts.add(pubkey);
          }
        }
      }

      // Sort accounts: signers first, then non-signers
      final sortedAccounts = <String>[];
      final signerAccountsList = accountAddresses
          .where((addr) => signerAccounts.contains(addr))
          .toList();
      final nonSignerAccountsList = accountAddresses
          .where((addr) => !signerAccounts.contains(addr))
          .toList();

      sortedAccounts.addAll(signerAccountsList);
      sortedAccounts.addAll(nonSignerAccountsList);

      // Update address indices after sorting
      addressToIndex.clear();
      for (int i = 0; i < sortedAccounts.length; i++) {
        addressToIndex[sortedAccounts[i]] = i;
      }

      // Count readonly accounts
      for (final addr in signerAccountsList) {
        if (!writableAccounts.contains(addr)) {
          numReadonlySignedAccounts++;
        }
      }

      for (final addr in nonSignerAccountsList) {
        if (!writableAccounts.contains(addr)) {
          numReadonlyUnsignedAccounts++;
        }
      }

      print('DEBUG: Signatures required: $numRequiredSignatures');
      print('DEBUG: Readonly signed: $numReadonlySignedAccounts');
      print('DEBUG: Readonly unsigned: $numReadonlyUnsignedAccounts');

      // Build the message
      final messageData = BytesBuilder();

      // Message header (3 bytes)
      messageData.addByte(numRequiredSignatures);
      messageData.addByte(numReadonlySignedAccounts);
      messageData.addByte(numReadonlyUnsignedAccounts);

      // Account addresses (compact array)
      _writeCompactArrayLength(messageData, sortedAccounts.length);
      for (final address in sortedAccounts) {
        final pubkeyBytes = base58.decode(address);
        if (pubkeyBytes.length != 32) {
          throw Exception('Invalid public key length: ${pubkeyBytes.length}');
        }
        messageData.add(pubkeyBytes);
      }

      // Recent blockhash (32 bytes)
      final blockhashBytes = base58.decode(recentBlockhash);
      if (blockhashBytes.length != 32) {
        throw Exception('Invalid blockhash length: ${blockhashBytes.length}');
      }
      messageData.add(blockhashBytes);

      // Instructions (compact array)
      _writeCompactArrayLength(messageData, instructions.length);
      for (final instruction in instructions) {
        final instrData = instruction as Map<String, dynamic>;

        // Program ID index
        final programId = instrData['programId'] as String;
        final programIndex = addressToIndex[programId]!;
        messageData.addByte(programIndex);

        // Account indices
        final accounts = instrData['accounts'] as List<dynamic>? ?? [];
        _writeCompactArrayLength(messageData, accounts.length);
        for (final account in accounts) {
          final accData = account as Map<String, dynamic>;
          final pubkey = accData['pubkey'] as String;
          final accountIndex = addressToIndex[pubkey]!;
          messageData.addByte(accountIndex);
        }

        // Instruction data
        final data = instrData['data'] as Uint8List;
        _writeCompactArrayLength(messageData, data.length);
        messageData.add(data);
      }

      final messageBytes = messageData.toBytes();
      print(
          'DEBUG: Transaction message for signing: ${messageBytes.length} bytes');

      return messageBytes;
    } catch (e, stackTrace) {
      print('ERROR: Failed to build transaction message: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Build just the transaction message bytes (without signatures) for signing
  Uint8List _buildTransactionMessage(
      Map<String, dynamic> transaction, String recentBlockhash) {
    try {
      print('DEBUG: Building transaction message for signing');

      // Extract transaction components
      final instructions = transaction['instructions'] as List<dynamic>? ?? [];
      final feePayerAddress = transaction['feePayer'] as String?;

      // Collect all account addresses referenced in the transaction
      final accountAddresses = <String>[];
      final addressToIndex = <String, int>{};

      // Add fee payer first (required to be index 0)
      if (feePayerAddress != null) {
        accountAddresses.add(feePayerAddress);
        addressToIndex[feePayerAddress] = 0;
      }

      // Add all accounts from instructions
      for (final instruction in instructions) {
        final instrData = instruction as Map<String, dynamic>;

        // Add program ID
        final programId = instrData['programId'] as String;
        if (!addressToIndex.containsKey(programId)) {
          addressToIndex[programId] = accountAddresses.length;
          accountAddresses.add(programId);
        }

        // Add instruction accounts
        final accounts = instrData['accounts'] as List<dynamic>? ?? [];
        for (final account in accounts) {
          final accData = account as Map<String, dynamic>;
          final pubkey = accData['pubkey'] as String;
          if (!addressToIndex.containsKey(pubkey)) {
            addressToIndex[pubkey] = accountAddresses.length;
            accountAddresses.add(pubkey);
          }
        }
      }

      // Track which accounts are signers and writable
      final signerAccounts = <String>{};
      final writableAccounts = <String>{};

      // Fee payer is always a signer and writable
      if (feePayerAddress != null) {
        signerAccounts.add(feePayerAddress);
        writableAccounts.add(feePayerAddress);
      }

      // Analyze instruction accounts
      for (final instruction in instructions) {
        final instrData = instruction as Map<String, dynamic>;
        final accounts = instrData['accounts'] as List<dynamic>? ?? [];

        for (final account in accounts) {
          final accData = account as Map<String, dynamic>;
          final pubkey = accData['pubkey'] as String;
          final isSigner = accData['isSigner'] as bool? ?? false;
          final isWritable = accData['isWritable'] as bool? ?? false;

          if (isSigner) {
            signerAccounts.add(pubkey);
          }

          if (isWritable) {
            writableAccounts.add(pubkey);
          }
        }
      }

      // Sort accounts: signers first, then non-signers
      final sortedAccounts = <String>[];
      final signerAccountsList = accountAddresses
          .where((addr) => signerAccounts.contains(addr))
          .toList();
      final nonSignerAccountsList = accountAddresses
          .where((addr) => !signerAccounts.contains(addr))
          .toList();

      sortedAccounts.addAll(signerAccountsList);
      sortedAccounts.addAll(nonSignerAccountsList);

      // Update address indices after sorting
      addressToIndex.clear();
      for (int i = 0; i < sortedAccounts.length; i++) {
        addressToIndex[sortedAccounts[i]] = i;
      }

      // Count required signatures and readonly accounts
      int numRequiredSignatures = signerAccountsList.length;
      int numReadonlySignedAccounts = 0;
      int numReadonlyUnsignedAccounts = 0;

      for (final addr in signerAccountsList) {
        if (!writableAccounts.contains(addr)) {
          numReadonlySignedAccounts++;
        }
      }

      for (final addr in nonSignerAccountsList) {
        if (!writableAccounts.contains(addr)) {
          numReadonlyUnsignedAccounts++;
        }
      }

      // Build the message
      final messageData = BytesBuilder();

      // Message header (3 bytes)
      messageData.addByte(numRequiredSignatures);
      messageData.addByte(numReadonlySignedAccounts);
      messageData.addByte(numReadonlyUnsignedAccounts);

      // Account addresses (compact array)
      _writeCompactArrayLength(messageData, sortedAccounts.length);
      for (final address in sortedAccounts) {
        final pubkeyBytes = base58.decode(address);
        if (pubkeyBytes.length != 32) {
          throw Exception('Invalid public key length: ${pubkeyBytes.length}');
        }
        messageData.add(pubkeyBytes);
      }

      // Recent blockhash (32 bytes)
      final blockhashBytes = base58.decode(recentBlockhash);
      if (blockhashBytes.length != 32) {
        throw Exception('Invalid blockhash length: ${blockhashBytes.length}');
      }
      messageData.add(blockhashBytes);

      // Instructions (compact array)
      _writeCompactArrayLength(messageData, instructions.length);
      for (final instruction in instructions) {
        final instrData = instruction as Map<String, dynamic>;

        // Program ID index
        final programId = instrData['programId'] as String;
        final programIndex = addressToIndex[programId]!;
        messageData.addByte(programIndex);

        // Account indices
        final accounts = instrData['accounts'] as List<dynamic>? ?? [];
        _writeCompactArrayLength(messageData, accounts.length);
        for (final account in accounts) {
          final accData = account as Map<String, dynamic>;
          final pubkey = accData['pubkey'] as String;
          final accountIndex = addressToIndex[pubkey]!;
          messageData.addByte(accountIndex);
        }

        // Instruction data
        final data = instrData['data'] as Uint8List;
        _writeCompactArrayLength(messageData, data.length);
        messageData.add(data);
      }

      final messageBytes = messageData.toBytes();
      print('DEBUG: Transaction message built: ${messageBytes.length} bytes');

      return messageBytes;
    } catch (e, stackTrace) {
      print('ERROR: Failed to build transaction message: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }
}

/// Exception thrown by Solana RPC operations
class SolanaRpcException implements Exception {
  final String message;
  final dynamic cause;

  const SolanaRpcException(this.message, [this.cause]);

  @override
  String toString() =>
      'SolanaRpcException: $message${cause != null ? ' (caused by: $cause)' : ''}';
}
