/// Workspace functionality for managing Anchor programs and IDLs.
/// Provides TypeScript-like workspace management for multiple programs.
library;

import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:coral_xyz_anchor/src/types/public_key.dart';
import 'package:coral_xyz_anchor/src/types/keypair.dart';
import 'package:coral_xyz_anchor/src/idl/idl.dart';
import 'package:coral_xyz_anchor/src/program/program_class.dart';
import 'package:coral_xyz_anchor/src/provider/anchor_provider.dart';
import 'package:coral_xyz_anchor/src/provider/wallet.dart';
import 'package:coral_xyz_anchor/src/provider/connection.dart';

// Export workspace configuration system
export 'workspace_config.dart';

// Export program manager and coordination system
export 'program_manager.dart';

// Import workspace configuration
import 'package:coral_xyz_anchor/src/workspace/workspace_config.dart';

/// TypeScript-like workspace for managing multiple Anchor programs
class Workspace extends Object {
  Workspace(this._provider);
  final Map<String, Program> _programs = {};
  final AnchorProvider _provider;
  final Map<String, Idl> _idls = {};

  /// Get provider instance
  AnchorProvider get provider => _provider;

  /// Get all program names
  List<String> get programNames => _programs.keys.toList();

  /// Get all programs
  Map<String, Program> get programs => Map.unmodifiable(_programs);

  /// Add a program to the workspace
  void addProgram(String name, Program program) {
    _programs[name] = program;
  }

  /// Get a program by name
  Program? getProgram(String name) => _programs[name];

  /// Remove a program from workspace
  bool removeProgram(String name) => _programs.remove(name) != null;

  /// Dynamic proxy for TypeScript-like workspace.ProgramName access
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isGetter) {
      final memberName = invocation.memberName;
      final name = _symbolToProgramName(memberName);
      final program = getProgram(name);
      if (program != null) return program;
      throw ArgumentError('Program "$name" not found in workspace');
    }
    return super.noSuchMethod(invocation);
  }

  String _symbolToProgramName(Symbol symbol) {
    final s = symbol.toString();
    // Symbol("ProgramName") => ProgramName
    final match = RegExp(r'"(.*)"').firstMatch(s);
    return match != null ? match.group(1)! : s;
  }

  /// Load program from IDL and program ID
  Future<Program> loadProgram(
    String name,
    Idl idl,
    PublicKey programId,
  ) async {
    final program = Program.withProgramId(
      idl,
      programId,
      provider: _provider,
    );
    _programs[name] = program;
    _idls[name] = idl;
    return program;
  }

  /// Load program from IDL JSON string
  Future<Program> loadProgramFromJson(
    String name,
    String idlJson,
    PublicKey programId,
  ) async {
    final idlMap = jsonDecode(idlJson) as Map<String, dynamic>;
    final idl = Idl.fromJson(idlMap);
    return loadProgram(name, idl, programId);
  }

  /// Load multiple programs from configuration
  Future<void> loadPrograms(Map<String, ProgramConfig> configs) async {
    for (final entry in configs.entries) {
      final name = entry.key;
      final config = entry.value;

      await loadProgram(name, config.idl, config.programId);
    }
  }

  /// Load multiple programs from configuration
  Future<Map<String, Program>> loadProgramsFromConfig(
    WorkspaceConfig config,
  ) async {
    final loadedPrograms = <String, Program>{};

    // Load programs from all clusters
    for (final clusterEntry in config.programs.entries) {
      final programs = clusterEntry.value;

      for (final entry in programs.entries) {
        final name = entry.key;
        final programEntry = entry.value;

        if (programEntry.address != null) {
          try {
            final programId = PublicKey.fromBase58(programEntry.address!);
            late Idl idl;

            if (programEntry.idl != null) {
              // Load from specified IDL path
              idl = await _loadIdlFromPath(programEntry.idl!);
            } else {
              // Try to fetch IDL from on-chain
              idl = await _fetchIdlFromChain(programId);
            }

            final program = await loadProgram(name, idl, programId);
            loadedPrograms[name] = program;
          } catch (e) {
            // Log error but continue with other programs
            print('Warning: Failed to load program "$name": $e');
          }
        }
      }
    }

    return loadedPrograms;
  }

  /// Discover and load workspace from Anchor.toml
  static Future<Workspace> fromAnchorWorkspace({
    String? workspaceDir,
    AnchorProvider? provider,
    String? cluster,
  }) async {
    workspaceDir ??= await _findWorkspaceRoot();

    final config = await WorkspaceConfig.fromFile(
      path.join(workspaceDir, 'Anchor.toml'),
    );

    // Create provider if not provided
    provider ??= await _createProviderFromConfig(config, cluster);

    final workspace = Workspace(provider);

    // Load all programs from configuration
    await workspace.loadProgramsFromConfig(config);

    // Add development mode features
    await workspace._enableDevelopmentMode(workspaceDir, config);

    return workspace;
  }

  /// Discover workspace from directory
  static Future<Workspace> discover({
    String? workspaceDir,
    AnchorProvider? provider,
    String? cluster,
  }) async {
    return await fromAnchorWorkspace(
      workspaceDir: workspaceDir,
      provider: provider,
      cluster: cluster,
    );
  }

  /// Initialize workspace from template
  static Future<Workspace> initializeFromTemplate(
    AnchorProvider provider,
    WorkspaceTemplate template,
  ) async {
    final workspace = Workspace(provider);

    // Load programs from template
    for (final entry in template.programs.entries) {
      final name = entry.key;
      final programConfig = entry.value;
      await workspace.loadProgram(
          name, programConfig.idl, programConfig.programId);
    }

    return workspace;
  }

  /// Get program by camelCase name
  Program? getProgramCamelCase(String name) {
    // Try exact match first
    var program = getProgram(name);
    if (program != null) return program;

    // Try converting snake_case to camelCase
    final camelCase = name.replaceAllMapped(
      RegExp(r'_([a-z])'),
      (match) => match.group(1)!.toUpperCase(),
    );
    program = getProgram(camelCase);
    if (program != null) return program;

    // Try converting camelCase to snake_case
    final snakeCase = name.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => '_${match.group(1)!.toLowerCase()}',
    );
    return getProgram(snakeCase);
  }

  /// Check if workspace has program
  bool hasProgram(String name) {
    return getProgram(name) != null || getProgramCamelCase(name) != null;
  }

  /// Validate workspace health
  Future<WorkspaceHealthReport> validateHealth() async {
    final issues = <WorkspaceIssue>[];
    final warnings = <String>[];
    final programStatuses = <String, ProgramStatus>{};

    // Check provider health
    try {
      final connection = _provider.connection;
      await connection.checkHealth();
    } catch (e) {
      issues.add(WorkspaceIssue(
        type: WorkspaceIssueType.connectionError,
        message: 'Provider connection failed: ${e.toString()}',
      ));
    }

    // Check each program
    for (final entry in _programs.entries) {
      final name = entry.key;
      final program = entry.value;

      try {
        // Try to get account info for program
        final accountInfo =
            await _provider.connection.getAccountInfo(program.programId);
        if (accountInfo != null) {
          programStatuses[name] = accountInfo.executable
              ? ProgramStatus.healthy
              : ProgramStatus.notExecutable;
        } else {
          programStatuses[name] = ProgramStatus.notFound;
          issues.add(WorkspaceIssue(
            type: WorkspaceIssueType.programNotFound,
            programName: name,
            message: 'Program not found on-chain',
          ));
        }
      } catch (e) {
        programStatuses[name] = ProgramStatus.error;
        issues.add(WorkspaceIssue(
          type: WorkspaceIssueType.programNotFound,
          programName: name,
          message: 'Error checking program: ${e.toString()}',
        ));
      }
    }

    return WorkspaceHealthReport(
      isHealthy: issues.isEmpty,
      issues: issues,
      warnings: warnings,
      programStatuses: programStatuses,
      checkedAt: DateTime.now(),
    );
  }

  /// Load wallet from file path
  static Future<Wallet> _loadWalletFromPath(String walletPath) async {
    // Expand home directory
    final expandedPath = walletPath.startsWith('~/')
        ? path.join(Platform.environment['HOME'] ?? '', walletPath.substring(2))
        : walletPath;

    final walletFile = File(expandedPath);

    if (!await walletFile.exists()) {
      throw WorkspaceConfigException(
        'Wallet file not found: $expandedPath',
      );
    }

    final walletData = await walletFile.readAsString();
    final keyData = jsonDecode(walletData)
        as List<dynamic>; // Convert to Uint8List and create keypair
    final secretKey = Uint8List.fromList(keyData.cast<int>());
    final keypair = Keypair.fromSecretKey(secretKey);

    return KeypairWallet(keypair);
  }

  /// Load IDL from file path
  Future<Idl> _loadIdlFromPath(String idlPath) async {
    final idlFile = File(idlPath);

    if (!await idlFile.exists()) {
      throw WorkspaceConfigException(
        'IDL file not found: $idlPath',
      );
    }

    final idlContent = await idlFile.readAsString();
    final idlMap = jsonDecode(idlContent) as Map<String, dynamic>;

    return Idl.fromJson(idlMap);
  }

  /// Fetch IDL from on-chain
  Future<Idl> _fetchIdlFromChain(PublicKey programId) async {
    // Implementation depends on the IDL fetching utilities
    // This is a placeholder that would use the IDL utilities
    throw UnimplementedError(
      'On-chain IDL fetching not yet implemented. Please provide IDL path in Anchor.toml',
    );
  }

  /// Enable development mode features
  Future<void> _enableDevelopmentMode(
      String workspaceDir, WorkspaceConfig config) async {
    // Set up file watching for IDL changes
    await _watchIdlFiles(workspaceDir);

    // Enable test environment features
    await _enableTestEnvironment(config);

    // Enable hot reload if supported
    await _enableHotReload();
  }

  /// Watch IDL files for changes and reload programs
  Future<void> _watchIdlFiles(String workspaceDir) async {
    final targetDir = Directory(path.join(workspaceDir, 'target', 'idl'));

    if (!await targetDir.exists()) {
      return; // No IDL directory to watch
    }

    // Watch for IDL file changes
    await for (final event in targetDir.watch(recursive: true)) {
      if (event.path.endsWith('.json') &&
          event.type == FileSystemEvent.modify) {
        await _reloadProgramFromIdl(event.path);
      }
    }
  }

  /// Reload program from IDL file change
  Future<void> _reloadProgramFromIdl(String idlPath) async {
    try {
      final idlFile = File(idlPath);
      final fileName = path.basenameWithoutExtension(idlPath);

      // Find program by IDL filename
      final programName = _findProgramNameByIdlFile(fileName);
      if (programName == null) return;

      // Load new IDL
      final idlContent = await idlFile.readAsString();
      final idlMap = jsonDecode(idlContent) as Map<String, dynamic>;
      final newIdl = Idl.fromJson(idlMap);

      // Get existing program ID
      final existingProgram = _programs[programName];
      if (existingProgram == null) return;

      // Create new program with updated IDL
      final newProgram = Program.withProgramId(
        newIdl,
        existingProgram.programId,
        provider: _provider,
      );

      // Replace program in workspace
      _programs[programName] = newProgram;
      _idls[programName] = newIdl;

      print('Reloaded program "$programName" from updated IDL');
    } catch (e) {
      print('Warning: Failed to reload program from IDL: $e');
    }
  }

  /// Find program name by IDL filename
  String? _findProgramNameByIdlFile(String idlFileName) {
    // This is a simple heuristic - in practice, you might want to
    // maintain a mapping of IDL files to program names
    return _programs.keys
            .firstWhere(
              (name) =>
                  name.toLowerCase().replaceAll('_', '') ==
                  idlFileName.toLowerCase().replaceAll('_', ''),
              orElse: () => '',
            )
            .isNotEmpty
        ? _programs.keys.first
        : null;
  }

  /// Enable test environment features
  Future<void> _enableTestEnvironment(WorkspaceConfig config) async {
    if (config.test == null) return;

    // Set up test configuration
    final testConfig = config.test!;

    // Configure startup wait time
    if (testConfig.startupWait != null) {
      await Future<void>.delayed(Duration(seconds: testConfig.startupWait!));
    }

    // Enable test mode logging
    print('Test environment enabled');
  }

  /// Enable hot reload functionality
  Future<void> _enableHotReload() async {
    // Hot reload implementation would go here
    // This is a placeholder for future implementation
    print('Hot reload enabled (placeholder)');
  }

  /// Create a test environment setup
  static Future<Workspace> createTestEnvironment({
    String? cluster,
    Keypair? payer,
    Map<String, String>? programIds,
  }) async {
    cluster ??= 'http://localhost:8899';
    payer ??= await Keypair.generate();

    final connection = Connection(cluster);

    final wallet = KeypairWallet(payer);
    final provider = AnchorProvider(connection, wallet);

    final workspace = Workspace(provider);

    // Load programs from provided IDs
    if (programIds != null) {
      for (final entry in programIds.entries) {
        final programName = entry.key;
        final programId = PublicKey.fromBase58(entry.value);

        try {
          // Try to fetch IDL from on-chain or use minimal IDL
          final idl = await workspace._createMinimalIdl(programName);
          await workspace.loadProgram(programName, idl, programId);
        } catch (e) {
          print('Warning: Failed to load test program "$programName": $e');
        }
      }
    }

    return workspace;
  }

  /// Create minimal IDL for testing
  Future<Idl> _createMinimalIdl(String programName) async {
    // Create a minimal IDL for testing purposes
    return Idl(
      version: '0.1.0',
      name: programName,
      instructions: [],
      accounts: [],
      types: [],
      events: [],
      errors: [],
      constants: [],
    );
  }

  /// Get program deployment status
  Future<Map<String, dynamic>> getDeploymentStatus(String programName) async {
    final program = _programs[programName];
    if (program == null) {
      throw ArgumentError('Program "$programName" not found');
    }

    return {
      'programId': program.programId.toBase58(),
      'isDeployed': true, // Placeholder - would check on-chain
      'upgradeAuthority': null, // Placeholder
      'dataSize': 0, // Placeholder
      'lastModified': DateTime.now().toIso8601String(),
    };
  }

  /// Find the workspace root directory by looking for Anchor.toml
  static Future<String> _findWorkspaceRoot([String? startDir]) async {
    startDir ??= Directory.current.path;

    var currentDir = Directory(startDir);

    // Walk up the directory tree looking for Anchor.toml
    while (true) {
      final anchorTomlPath = path.join(currentDir.path, 'Anchor.toml');
      final anchorToml = File(anchorTomlPath);

      if (await anchorToml.exists()) {
        return currentDir.path;
      }

      // Move to parent directory
      final parent = currentDir.parent;
      if (parent.path == currentDir.path) {
        // We've reached the root directory
        break;
      }
      currentDir = parent;
    }

    // If not found, return current directory
    return startDir;
  }

  /// Create provider from workspace configuration
  static Future<AnchorProvider> _createProviderFromConfig(
    WorkspaceConfig config,
    String? cluster,
  ) async {
    // Use provided cluster or default from config
    cluster ??= config.provider.cluster;

    // Create connection
    final connection = Connection(cluster);

    // Create wallet from wallet path
    final walletPath = config.provider.wallet;
    final wallet = await _loadWalletFromPath(walletPath);

    // Create provider
    return AnchorProvider(connection, wallet);
  }

  /// Deploy program to cluster
  Future<DeploymentResult> deployProgram(
    String programName,
    Uint8List programData,
    Keypair programKeypair, {
    String? cluster,
  }) async {
    try {
      // This is a placeholder implementation
      // In a real implementation, this would:
      // 1. Calculate rent for the program account
      // 2. Create and send deployment transaction
      // 3. Wait for confirmation

      return DeploymentResult(
        success: true,
        programId: programKeypair.publicKey,
        transactionId: 'placeholder_tx_id',
        deployedAt: DateTime.now(),
      );
    } catch (e) {
      return DeploymentResult(
        success: false,
        error: e.toString(),
        deployedAt: DateTime.now(),
      );
    }
  }

  /// Upgrade program on cluster
  Future<UpgradeResult> upgradeProgram(
    String programName,
    Uint8List newProgramData,
  ) async {
    try {
      final program = _programs[programName];
      if (program == null) {
        throw ArgumentError('Program "$programName" not found');
      }

      // This is a placeholder implementation
      // In a real implementation, this would:
      // 1. Check upgrade authority
      // 2. Create upgrade transaction
      // 3. Send and confirm transaction

      return UpgradeResult(
        success: true,
        programId: program.programId,
        transactionId: 'placeholder_upgrade_tx_id',
        upgradedAt: DateTime.now(),
      );
    } catch (e) {
      return UpgradeResult(
        success: false,
        error: e.toString(),
        upgradedAt: DateTime.now(),
      );
    }
  }

  /// Create development configuration
  Map<String, dynamic> createDevConfig() {
    final programs = <String, dynamic>{};

    for (final entry in _programs.entries) {
      final name = entry.key;
      final program = entry.value;

      programs[name] = {
        'programId': program.programId.toBase58(),
        'idl': program.idl.toJson(),
      };
    }

    return {
      'workspace': {
        'cluster': 'localnet',
        'development': true,
        'hotReload': true,
        'watchFiles': true,
        'logLevel': 'debug',
        'testMode': true,
      },
      'programs': programs,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  /// Export workspace for deployment
  Future<Map<String, dynamic>> exportForDeployment() async {
    final programs = <String, dynamic>{};

    for (final entry in _programs.entries) {
      final name = entry.key;
      final program = entry.value;

      programs[name] = {
        'programId': program.programId.toBase58(),
        'idl': program.idl.toJson(),
        'metadata': {
          'name': name,
          'version': program.idl.version,
          'exportedAt': DateTime.now().toIso8601String(),
        },
      };
    }

    return {
      'workspace': {
        'version': '1.0.0',
        'cluster': _provider.connection.endpoint,
        'wallet': _provider.wallet?.publicKey.toBase58(),
        'exportedAt': DateTime.now().toIso8601String(),
      },
      'programs': programs,
    };
  }
}

/// Configuration for a single program in the workspace
class ProgramConfig {
  const ProgramConfig({
    required this.idl,
    required this.programId,
    this.name,
    this.metadata,
  });

  /// Create from JSON configuration
  factory ProgramConfig.fromJson(Map<String, dynamic> json) {
    return ProgramConfig(
      idl: Idl.fromJson(json['idl'] as Map<String, dynamic>),
      programId: PublicKey.fromBase58(json['programId'] as String),
      name: json['name'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
  final Idl idl;
  final PublicKey programId;
  final String? name;
  final Map<String, dynamic>? metadata;

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
        'idl': idl.toJson(),
        'programId': programId.toBase58(),
        if (name != null) 'name': name,
        if (metadata != null) 'metadata': metadata,
      };
}

/// Statistics about the workspace
class WorkspaceStats {
  const WorkspaceStats({
    required this.programCount,
    required this.totalInstructions,
    required this.totalAccounts,
    required this.programNames,
  });
  final int programCount;
  final int totalInstructions;
  final int totalAccounts;
  final List<String> programNames;

  @override
  String toString() => 'WorkspaceStats('
      'programs: $programCount, '
      'instructions: $totalInstructions, '
      'accounts: $totalAccounts'
      ')';
}

/// Workspace builder for fluent API
class WorkspaceBuilder {
  WorkspaceBuilder(this._provider);
  final AnchorProvider _provider;
  final Map<String, ProgramConfig> _programConfigs = {};

  /// Add a program configuration
  WorkspaceBuilder addProgram(String name, ProgramConfig config) {
    _programConfigs[name] = config;
    return this;
  }

  /// Add program with IDL and program ID
  WorkspaceBuilder addProgramWithIdl(
    String name,
    Idl idl,
    PublicKey programId,
  ) {
    _programConfigs[name] = ProgramConfig(
      idl: idl,
      programId: programId,
      name: name,
    );
    return this;
  }

  /// Build the workspace
  Future<Workspace> build() async {
    final workspace = Workspace(_provider);
    await workspace.loadPrograms(_programConfigs);
    return workspace;
  }
}

/// Workspace health report with validation results
class WorkspaceHealthReport {
  const WorkspaceHealthReport({
    required this.isHealthy,
    required this.issues,
    required this.warnings,
    required this.programStatuses,
    required this.checkedAt,
  });
  final bool isHealthy;
  final List<WorkspaceIssue> issues;
  final List<String> warnings;
  final Map<String, ProgramStatus> programStatuses;
  final DateTime checkedAt;

  @override
  String toString() {
    final buffer = StringBuffer('WorkspaceHealthReport(');
    buffer.write('healthy: $isHealthy, ');
    buffer.write('issues: ${issues.length}, ');
    buffer.write('warnings: ${warnings.length}, ');
    buffer.write('programs: ${programStatuses.length}');
    buffer.write(')');
    return buffer.toString();
  }
}

/// Workspace issue types
enum WorkspaceIssueType {
  programNotFound,
  programNotExecutable,
  idlValidationFailed,
  connectionError,
  configurationError,
  dependencyError,
}

/// Individual workspace issue
class WorkspaceIssue {
  WorkspaceIssue({
    required this.type,
    this.programName,
    required this.message,
    DateTime? detectedAt,
  }) : detectedAt = detectedAt ?? DateTime.now();
  final WorkspaceIssueType type;
  final String? programName;
  final String message;
  final DateTime detectedAt;

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('[${type.name}]');
    if (programName != null) {
      buffer.write(' $programName:');
    }
    buffer.write(' $message');
    return buffer.toString();
  }
}

/// Program status enumeration
enum ProgramStatus {
  healthy,
  notFound,
  notExecutable,
  error,
  loading,
  unknown,
}

/// Deployment result
class DeploymentResult {
  const DeploymentResult({
    required this.success,
    this.programId,
    this.transactionId,
    this.error,
    required this.deployedAt,
  });
  final bool success;
  final PublicKey? programId;
  final String? transactionId;
  final String? error;
  final DateTime deployedAt;

  @override
  String toString() {
    if (success) {
      return 'DeploymentResult(success: true, programId: $programId, txId: $transactionId)';
    } else {
      return 'DeploymentResult(success: false, error: $error)';
    }
  }
}

/// Upgrade result
class UpgradeResult {
  const UpgradeResult({
    required this.success,
    this.programId,
    this.transactionId,
    this.error,
    required this.upgradedAt,
  });
  final bool success;
  final PublicKey? programId;
  final String? transactionId;
  final String? error;
  final DateTime upgradedAt;

  @override
  String toString() {
    if (success) {
      return 'UpgradeResult(success: true, programId: $programId, txId: $transactionId)';
    } else {
      return 'UpgradeResult(success: false, error: $error)';
    }
  }
}

/// Workspace template for initialization
class WorkspaceTemplate {
  const WorkspaceTemplate({
    required this.name,
    required this.version,
    required this.programs,
    this.configuration = const {},
  });

  factory WorkspaceTemplate.basic({
    required String name,
    required Map<String, ProgramConfig> programs,
  }) {
    return WorkspaceTemplate(
      name: name,
      version: '1.0.0',
      programs: programs,
    );
  }

  factory WorkspaceTemplate.fromJson(Map<String, dynamic> json) {
    final programsData = json['programs'] as Map<String, dynamic>;
    final programs = <String, ProgramConfig>{};

    for (final entry in programsData.entries) {
      programs[entry.key] =
          ProgramConfig.fromJson(entry.value as Map<String, dynamic>);
    }

    return WorkspaceTemplate(
      name: json['name'] as String,
      version: json['version'] as String,
      programs: programs,
      configuration: json['configuration'] as Map<String, dynamic>? ?? {},
    );
  }
  final String name;
  final String version;
  final Map<String, ProgramConfig> programs;
  final Map<String, dynamic> configuration;

  Map<String, dynamic> toJson() => {
        'name': name,
        'version': version,
        'programs': programs.map((key, value) => MapEntry(key, value.toJson())),
        'configuration': configuration,
      };
}

/// Enhanced workspace builder with TypeScript-like features
class EnhancedWorkspaceBuilder {
  EnhancedWorkspaceBuilder(this._provider);
  final AnchorProvider _provider;
  final Map<String, ProgramConfig> _programConfigs = {};
  final Map<String, dynamic> _metadata = {};
  String? _workspacePath;
  bool _autoDiscover = false;

  /// Set workspace path for auto-discovery
  EnhancedWorkspaceBuilder withWorkspacePath(String path) {
    _workspacePath = path;
    return this;
  }

  /// Enable auto-discovery of programs
  EnhancedWorkspaceBuilder withAutoDiscover() {
    _autoDiscover = true;
    return this;
  }

  /// Add metadata to the workspace
  EnhancedWorkspaceBuilder withMetadata(String key, dynamic value) {
    _metadata[key] = value;
    return this;
  }

  /// Add a program configuration
  EnhancedWorkspaceBuilder addProgram(String name, ProgramConfig config) {
    _programConfigs[name] = config;
    return this;
  }

  /// Add program with IDL and program ID
  EnhancedWorkspaceBuilder addProgramWithIdl(
    String name,
    Idl idl,
    PublicKey programId,
  ) {
    _programConfigs[name] = ProgramConfig(
      idl: idl,
      programId: programId,
      name: name,
    );
    return this;
  }

  /// Build the workspace with enhanced features
  Future<Workspace> build() async {
    Workspace workspace;

    if (_autoDiscover) {
      workspace = await Workspace.fromAnchorWorkspace(
        workspaceDir: _workspacePath,
        provider: _provider,
      );
    } else {
      workspace = Workspace(_provider);
    }

    // Load configured programs
    await workspace.loadPrograms(_programConfigs);

    return workspace;
  }
}
