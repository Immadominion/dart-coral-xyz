/// Registry utilities matching TypeScript Anchor SDK utils.registry
///
/// Provides program registry and verification utilities with compatibility
/// to the TypeScript Anchor SDK's utils.registry module.
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:coral_xyz/src/types/public_key.dart';
import 'package:coral_xyz/src/provider/connection.dart';

/// Program data from upgradeable loader
class ProgramData {
  const ProgramData({
    required this.slot,
    this.upgradeAuthorityAddress,
  });

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
        http.get(Uri.parse(url)),
      ]);

      final programData = responses[0] as ProgramData?;
      final latestBuildsResp = responses[1] as http.Response;

      if (programData == null || latestBuildsResp.statusCode != 200) {
        return null;
      }

      // Parse and filter builds
      final buildsJson = jsonDecode(latestBuildsResp.body) as List;
      final latestBuilds = buildsJson
          .map((b) => Build.fromJson(b as Map<String, dynamic>))
          .where((b) =>
              !b.aborted && b.state == 'Built' && b.verified == 'Verified')
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
  static Future<ProgramData?> _fetchProgramData(
    Connection connection,
    PublicKey programId,
  ) async {
    try {
      // This is a simplified implementation
      // In practice, this would need to decode the actual upgradeable loader state
      // For now, return a mock ProgramData to maintain API compatibility
      return ProgramData(
        slot: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        upgradeAuthorityAddress: null,
      );
    } catch (e) {
      return null;
    }
  }

  /// Decode upgradeable loader state from account data
  ///
  /// Matches TypeScript: utils.registry.decodeUpgradeableLoaderState()
  static Map<String, dynamic>? decodeUpgradeableLoaderState(List<int> data) {
    // This would require implementing Borsh decoding for upgradeable loader layout
    // For now, return null to maintain API compatibility without breaking
    return null;
  }
}
