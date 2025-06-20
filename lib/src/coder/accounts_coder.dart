/// Accounts coder implementation for Anchor programs
///
/// This module provides the AccountsCoder interface and implementations
/// for encoding and decoding on-chain account data.

import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'dart:convert' show utf8;

import '../idl/idl.dart';
import './types_coder.dart';
import '../types/common.dart';

/// Interface for encoding and decoding on-chain account data
abstract class AccountsCoder<N extends String> {
  /// Encode account data
  ///
  /// [accountName] - The name of the account type as defined in the IDL
  /// [data] - The account data to encode (typically a Map<String, dynamic>)
  /// Returns the encoded account data as a byte buffer, including the discriminator
  Uint8List encode(N accountName, Map<String, dynamic> data);

  /// Decode account data
  ///
  /// [accountName] - The name of the account type as defined in the IDL
  /// [data] - The raw account data (byte buffer) to decode
  /// Returns the decoded account data (typically a Map<String, dynamic>)
  Map<String, dynamic> decode(N accountName, Uint8List data);

  /// Calculates the 8-byte discriminator for an account type.
  /// The discriminator is derived from the SHA256 hash of "account:<AccountName>".
  Uint8List accountDiscriminator(N accountName);
}

/// Borsh-based implementation of AccountsCoder
class BorshAccountsCoder<N extends String> implements AccountsCoder<N> {
  final Idl idl;
  final BorshTypesCoder typesCoder;

  BorshAccountsCoder(this.idl) : typesCoder = BorshTypesCoder(idl);

  @override
  Uint8List accountDiscriminator(N accountName) {
    final inputString = 'account:$accountName';
    final bytes = utf8.encode(inputString);
    final digest = sha256.convert(bytes);
    return Uint8List.fromList(digest.bytes.sublist(0, 8));
  }

  @override
  Uint8List encode(N accountName, Map<String, dynamic> data) {
    final IdlAccount? accountDef = idl.findAccount(accountName as String);
    if (accountDef == null) {
      throw AccountsCoderException(
          'Account type not found in IDL: $accountName');
    }

    // The actual data encoding is done by TypesCoder using a temporary IdlTypeDef
    // that represents the account's structure.
    final IdlTypeDef accountAsTypeDef = IdlTypeDef(
      name: accountDef.name,
      type: accountDef.type,
    );

    // Create a temporary IDL with only this type to use with TypesCoder
    // This is a workaround because TypesCoder expects IdlTypeDef from idl.types
    // A more integrated approach might involve TypesCoder directly accepting IdlTypeDefType
    final tempIdl = Idl(
      address: idl.address,
      metadata: idl.metadata,
      instructions: [],
      types: [accountAsTypeDef],
    );
    final tempTypesCoder = BorshTypesCoder(tempIdl);

    final encodedData = tempTypesCoder.encode(accountDef.name, data);

    final discriminator = accountDiscriminator(accountName);

    final buffer = BytesBuilder();
    buffer.add(discriminator);
    buffer.add(encodedData);

    return buffer.toBytes();
  }

  @override
  Map<String, dynamic> decode(N accountName, Uint8List data) {
    if (data.length < 8) {
      throw AccountsCoderException(
          'Account data too short to contain discriminator.');
    }

    final IdlAccount? accountDef = idl.findAccount(accountName as String);
    if (accountDef == null) {
      throw AccountsCoderException(
          'Account type not found in IDL: $accountName');
    }

    final expectedDiscriminator = accountDiscriminator(accountName);
    final actualDiscriminator = data.sublist(0, 8);

    for (int i = 0; i < 8; i++) {
      if (expectedDiscriminator[i] != actualDiscriminator[i]) {
        throw AccountsCoderException(
            'Discriminator mismatch for account $accountName. \n'
            'Expected: ${expectedDiscriminator.toString()}, \n'
            'Got: ${actualDiscriminator.toString()}');
      }
    }

    final accountDataBytes = data.sublist(8);

    // Similar to encode, use a temporary IdlTypeDef for TypesCoder
    final IdlTypeDef accountAsTypeDef = IdlTypeDef(
      name: accountDef.name,
      type: accountDef.type,
    );
    final tempIdl = Idl(
      address: idl.address,
      metadata: idl.metadata,
      instructions: [],
      types: [accountAsTypeDef],
    );
    final tempTypesCoder = BorshTypesCoder(tempIdl);

    return tempTypesCoder.decode(accountDef.name, accountDataBytes);
  }
}

/// Exception thrown by accounts coder operations
class AccountsCoderException extends AnchorException {
  const AccountsCoderException(String message, [dynamic cause])
      : super(message, cause);
}
