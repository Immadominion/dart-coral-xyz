/// Registry utilities matching TypeScript Anchor SDK utils.registry
///
/// Provides program registry and verification utilities with compatibility
/// to the TypeScript Anchor SDK's utils.registry module.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:solana/dto.dart' as dto;
import 'package:coral_xyz/src/types/public_key.dart';
import 'package:coral_xyz/src/provider/connection.dart';

/// Program data from upgradeable loader
class ProgramData {
  const ProgramData({required this.slot, this.upgradeAuthorityAddress});

  final int slot;
  final PublicKey? upgradeAuthorityAddress;

  Map<String, dynamic> toJson() => {
    'slot': slot,
    'upgradeAuthorityAddress': upgradeAuthorityAddress?.toBase58(),
  };
}

/// Build information from registry
class Build {
  const Build({
    required this.aborted,
    required this.address,
    required this.createdAt,
    required this.updatedAt,
    required this.descriptor,
    required this.docker,
    required this.id,
    required this.name,
    required this.sha256,
    required this.upgradeAuthority,
    required this.verified,
    required this.verifiedSlot,
    required this.state,
  });

  final bool aborted;
  final String address;
  final String createdAt;
  final String updatedAt;
  final List<String> descriptor;
  final String docker;
  final int id;
  final String name;
  final String sha256;
  final String upgradeAuthority;
  final String verified;
  final int verifiedSlot;
  final String state;

  factory Build.fromJson(Map<String, dynamic> json) => Build(
    aborted: json['aborted'] as bool,
    address: json['address'] as String,
    createdAt: json['created_at'] as String,
    updatedAt: json['updated_at'] as String,
    descriptor: (json['descriptor'] as List).cast<String>(),
    docker: json['docker'] as String,
    id: json['id'] as int,
    name: json['name'] as String,
    sha256: json['sha256'] as String,
    upgradeAuthority: json['upgrade_authority'] as String,
    verified: json['verified'] as String,
    verifiedSlot: json['verified_slot'] as int,
    state: json['state'] as String,
  );

  Map<String, dynamic> toJson() => {
    'aborted': aborted,
    'address': address,
    'created_at': createdAt,
    'updated_at': updatedAt,
    'descriptor': descriptor,
    'docker': docker,
    'id': id,
    'name': name,
    'sha256': sha256,
    'upgrade_authority': upgradeAuthority,
    'verified': verified,
    'verified_slot': verifiedSlot,
    'state': state,
  };
}

/// Registry utilities for program verification and builds
///
/// Matches TypeScript: utils.registry.*
class RegistryUtils {
  /// Returns a verified build from the anchor registry
  ///
  /// Matches TypeScript: utils.registry.verifiedBuild()
  static Future<Build?> verifiedBuild(
    Connection connection,
    PublicKey programId, {
    int limit = 5,
  }) async {
    try {
      final url =
          'https://api.apr.dev/api/v0/program/${programId.toBase58()}/latest?limit=$limit';

      // Fetch program data and latest builds in parallel
      final responses = await Future.wait([
        _fetchProgramData(connection, programId),
        _httpGet(url),
      ]);

      final programData = responses[0] as ProgramData?;
      final latestBuildsResp = responses[1] as Map<String, dynamic>?;

      if (programData == null || latestBuildsResp == null) {
        return null;
      }

      // Parse and filter builds
      final buildsJson = latestBuildsResp['body'] as List;
      final latestBuilds = buildsJson
          .map((b) => Build.fromJson(b as Map<String, dynamic>))
          .where(
            (b) => !b.aborted && b.state == 'Built' && b.verified == 'Verified',
          )
          .toList();

      if (latestBuilds.isEmpty) {
        return null;
      }

      // Get the latest build
      final build = latestBuilds.first;

      // Check if program has been upgraded since last build
      if (programData.slot != build.verifiedSlot) {
        return null;
      }

      return build;
    } catch (e) {
      // Return null on any error (network, parsing, etc.)
      return null;
    }
  }

  /// Internal HTTP GET helper using dart:io
  static Future<Map<String, dynamic>?> _httpGet(String url) async {
    try {
      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse(url));
        final response = await request.close();
        if (response.statusCode != 200) return null;
        final body = await response.transform(utf8.decoder).join();
        return {'body': jsonDecode(body)};
      } finally {
        client.close();
      }
    } catch (_) {
      return null;
    }
  }

  /// Fetch program data account information
  ///
  /// Matches TypeScript: utils.registry.fetchData()
  static Future<ProgramData?> fetchData(
    Connection connection,
    PublicKey programId,
  ) async {
    return _fetchProgramData(connection, programId);
  }

  /// Internal helper to fetch program data
  ///
  /// Fetches the on-chain account for [programId], decodes the upgradeable
  /// loader state to find the programdata address, then fetches that account
  /// to extract the deployment slot and upgrade authority.
  /// Matches TypeScript: utils.registry.fetchData()
  static Future<ProgramData?> _fetchProgramData(
    Connection connection,
    PublicKey programId,
  ) async {
    try {
      // 1. Fetch the program account
      final accountInfo = await connection.getAccountInfo(
        programId.toBase58(),
        encoding: dto.Encoding.base64,
      );
      if (accountInfo == null) return null;

      final programAccountData = _decodeAccountData(accountInfo);
      if (programAccountData == null) return null;

      // 2. Decode as UpgradeableLoaderState::Program to get programdata address
      final programState = decodeUpgradeableLoaderState(programAccountData);
      if (programState == null) return null;

      final programdataAddress =
          programState['program']?['programdataAddress'] as PublicKey?;
      if (programdataAddress == null) return null;

      // 3. Fetch the programdata account
      final programdataAccountInfo = await connection.getAccountInfo(
        programdataAddress.toBase58(),
        encoding: dto.Encoding.base64,
      );
      if (programdataAccountInfo == null) return null;

      final programdataData = _decodeAccountData(programdataAccountInfo);
      if (programdataData == null) return null;

      // 4. Decode as UpgradeableLoaderState::ProgramData
      final programdataState = decodeUpgradeableLoaderState(programdataData);
      if (programdataState == null) return null;

      final pdEntry = programdataState['programData'];
      if (pdEntry == null) return null;

      return ProgramData(
        slot: pdEntry['slot'] as int,
        upgradeAuthorityAddress:
            pdEntry['upgradeAuthorityAddress'] as PublicKey?,
      );
    } catch (e) {
      return null;
    }
  }

  /// Extract raw bytes from an espresso-cash Account DTO.
  static Uint8List? _decodeAccountData(dto.Account account) {
    final data = account.data;
    if (data is dto.BinaryAccountData) {
      return Uint8List.fromList(data.data);
    }
    return null;
  }

  /// Decode the Borsh-serialised UpgradeableLoaderState enum.
  ///
  /// Layout (matching the Rust enum used by the BPF Upgradeable Loader):
  /// ```
  /// u32 variant_index
  ///   0 → Uninitialized
  ///   1 → Buffer  { option<Pubkey> authorityAddress }
  ///   2 → Program { Pubkey programdataAddress }
  ///   3 → ProgramData { u64 slot, option<Pubkey> upgradeAuthorityAddress }
  /// ```
  ///
  /// Returns a map keyed by the variant name for the decoded fields,
  /// or `null` if the data cannot be parsed.
  static Map<String, dynamic>? decodeUpgradeableLoaderState(Uint8List data) {
    if (data.length < 4) return null;

    final byteData = ByteData.sublistView(data);
    final variant = byteData.getUint32(0, Endian.little);

    switch (variant) {
      case 0:
        return {'uninitialized': <String, dynamic>{}};

      case 1:
        // Buffer { option<Pubkey> authorityAddress }
        if (data.length < 5) return null;
        final hasAuthority = data[4] == 1;
        PublicKey? authorityAddress;
        if (hasAuthority) {
          if (data.length < 37) return null; // 4 + 1 + 32
          authorityAddress = PublicKeyUtils.fromBytes(data.sublist(5, 37));
        }
        return {
          'buffer': {'authorityAddress': authorityAddress},
        };

      case 2:
        // Program { Pubkey programdataAddress }
        if (data.length < 36) return null; // 4 + 32
        final programdataAddress = PublicKeyUtils.fromBytes(
          data.sublist(4, 36),
        );
        return {
          'program': {'programdataAddress': programdataAddress},
        };

      case 3:
        // ProgramData { u64 slot, option<Pubkey> upgradeAuthorityAddress }
        if (data.length < 13) return null; // 4 + 8 + 1
        final slot = byteData.getUint64(4, Endian.little);
        final hasUpgradeAuthority = data[12] == 1;
        PublicKey? upgradeAuthorityAddress;
        if (hasUpgradeAuthority) {
          if (data.length < 45) return null; // 4 + 8 + 1 + 32
          upgradeAuthorityAddress = PublicKeyUtils.fromBytes(
            data.sublist(13, 45),
          );
        }
        return {
          'programData': {
            'slot': slot,
            'upgradeAuthorityAddress': upgradeAuthorityAddress,
          },
        };

      default:
        return null;
    }
  }
}
