/// Workspace configuration system for Anchor.toml parsing and program discovery
///
/// This module provides comprehensive workspace management with automatic program
/// discovery and configuration matching TypeScript's Anchor.toml parsing capabilities.

library;

import 'dart:io';
import 'dart:convert';
import 'package:toml/toml.dart';
import 'package:path/path.dart' as path;
import 'package:coral_xyz_anchor/src/idl/idl.dart';

/// Exception thrown when workspace configuration is invalid
class WorkspaceConfigException implements Exception {
  const WorkspaceConfigException(
    this.message, {
    this.filePath,
    this.cause,
  });
  final String message;
  final String? filePath;
  final dynamic cause;

  @override
  String toString() {
    final buffer = StringBuffer('WorkspaceConfigException: $message');
    if (filePath != null) {
      buffer.write(' (file: $filePath)');
    }
    if (cause != null) {
      buffer.write('\nCaused by: $cause');
    }
    return buffer.toString();
  }
}

/// Provider configuration section from Anchor.toml
class ProviderConfig {
  const ProviderConfig({
    required this.cluster,
    required this.wallet,
  });

  factory ProviderConfig.fromToml(Map<String, dynamic> toml) {
    return ProviderConfig(
      cluster: toml['cluster'] as String? ?? 'localnet',
      wallet: toml['wallet'] as String? ?? '~/.config/solana/id.json',
    );
  }
  final String cluster;
  final String wallet;

  Map<String, dynamic> toToml() => {
        'cluster': cluster,
        'wallet': wallet,
      };
}

/// Program entry configuration with optional IDL path and address
class ProgramEntry {
  const ProgramEntry({
    this.address,
    this.idl,
  });

  factory ProgramEntry.fromToml(dynamic toml) {
    if (toml is String) {
      // Simple format: just the address
      return ProgramEntry(address: toml);
    } else if (toml is Map<String, dynamic>) {
      // Complex format: address and IDL path
      return ProgramEntry(
        address: toml['address'] as String?,
        idl: toml['idl'] as String?,
      );
    } else {
      throw WorkspaceConfigException(
        'Invalid program entry format: expected String or Map, got ${toml.runtimeType}',
      );
    }
  }
  final String? address;
  final String? idl;

  dynamic toToml() {
    if (idl == null && address != null) {
      return address!; // Return just the string for simple format
    }
    return {
      if (address != null) 'address': address!,
      if (idl != null) 'idl': idl!,
    };
  }
}

/// Test configuration section from Anchor.toml
class TestConfig {
  const TestConfig({
    this.startupWait,
    this.validatorAccounts,
  });

  factory TestConfig.fromToml(Map<String, dynamic> toml) {
    final validatorConfig = toml['validator'] as Map<String, dynamic>?;
    List<ValidatorAccount>? accounts;

    if (validatorConfig != null) {
      final accountList = validatorConfig['account'] as List<dynamic>?;
      if (accountList != null) {
        accounts = accountList
            .map((account) =>
                ValidatorAccount.fromToml(account as Map<String, dynamic>))
            .toList();
      }
    }

    return TestConfig(
      startupWait: toml['startup_wait'] as int?,
      validatorAccounts: accounts,
    );
  }
  final int? startupWait;
  final List<ValidatorAccount>? validatorAccounts;

  Map<String, dynamic> toToml() {
    final result = <String, dynamic>{};

    if (startupWait != null) {
      result['startup_wait'] = startupWait;
    }

    if (validatorAccounts != null && validatorAccounts!.isNotEmpty) {
      result['validator'] = {
        'account':
            validatorAccounts!.map((account) => account.toToml()).toList(),
      };
    }

    return result;
  }
}

/// Validator account configuration for testing
class ValidatorAccount {
  const ValidatorAccount({
    required this.address,
    required this.filename,
  });

  factory ValidatorAccount.fromToml(Map<String, dynamic> toml) {
    return ValidatorAccount(
      address: toml['address'] as String,
      filename: toml['filename'] as String,
    );
  }
  final String address;
  final String filename;

  Map<String, dynamic> toToml() => {
        'address': address,
        'filename': filename,
      };
}

/// Features configuration section
class FeaturesConfig {
  const FeaturesConfig({
    this.seeds,
    this.skipLint,
  });

  factory FeaturesConfig.fromToml(Map<String, dynamic> toml) {
    return FeaturesConfig(
      seeds: toml['seeds'] as bool?,
      skipLint: toml['skip-lint'] as bool?,
    );
  }
  final bool? seeds;
  final bool? skipLint;

  Map<String, dynamic> toToml() {
    final result = <String, dynamic>{};
    if (seeds != null) result['seeds'] = seeds;
    if (skipLint != null) result['skip-lint'] = skipLint;
    return result;
  }
}

/// Scripts configuration section
class ScriptsConfig {
  const ScriptsConfig({
    required this.scripts,
  });

  factory ScriptsConfig.fromToml(Map<String, dynamic> toml) {
    final scripts = <String, String>{};
    toml.forEach((key, value) {
      if (value is String) {
        scripts[key] = value;
      }
    });
    return ScriptsConfig(scripts: scripts);
  }
  final Map<String, String> scripts;

  Map<String, dynamic> toToml() => Map<String, dynamic>.from(scripts);
}

/// Complete workspace configuration from Anchor.toml
class WorkspaceConfig {
  const WorkspaceConfig({
    required this.provider,
    required this.programs,
    this.test,
    this.features,
    this.scripts,
    this.workspaceRoot,
  });

  /// Load workspace configuration from Anchor.toml file
  factory WorkspaceConfig.fromFile(String filePath) {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        throw WorkspaceConfigException(
          'Anchor.toml file not found',
          filePath: filePath,
        );
      }

      final content = file.readAsStringSync();
      final tomlData = TomlDocument.parse(content).toMap();

      return WorkspaceConfig._fromToml(
        tomlData,
        workspaceRoot: path.canonicalize(path.dirname(filePath)),
      );
    } catch (e) {
      throw WorkspaceConfigException(
        'Failed to parse Anchor.toml',
        filePath: filePath,
        cause: e,
      );
    }
  }

  /// Load workspace configuration from directory containing Anchor.toml
  factory WorkspaceConfig.fromDirectory(String directoryPath) {
    final anchorTomlPath = path.join(directoryPath, 'Anchor.toml');
    return WorkspaceConfig.fromFile(anchorTomlPath);
  }

  /// Load workspace configuration from current directory
  factory WorkspaceConfig.fromCurrentDirectory() {
    return WorkspaceConfig.fromDirectory(Directory.current.path);
  }

  factory WorkspaceConfig._fromToml(
    Map<String, dynamic> toml, {
    String? workspaceRoot,
  }) {
    // Parse provider configuration
    final providerData = toml['provider'] as Map<String, dynamic>?;
    if (providerData == null) {
      throw const WorkspaceConfigException(
        'Missing required [provider] section in Anchor.toml',
      );
    }
    final provider = ProviderConfig.fromToml(providerData);

    // Parse programs configuration
    final programsData = toml['programs'] as Map<String, dynamic>?;
    final programs = <String, Map<String, ProgramEntry>>{};

    if (programsData != null) {
      for (final entry in programsData.entries) {
        final cluster = entry.key;
        final clusterPrograms = entry.value as Map<String, dynamic>;

        programs[cluster] = {};
        for (final programEntry in clusterPrograms.entries) {
          final programName = programEntry.key;
          programs[cluster]![programName] =
              ProgramEntry.fromToml(programEntry.value);
        }
      }
    }

    // Parse optional sections
    TestConfig? test;
    if (toml['test'] is Map<String, dynamic>) {
      test = TestConfig.fromToml(toml['test'] as Map<String, dynamic>);
    }

    FeaturesConfig? features;
    if (toml['features'] is Map<String, dynamic>) {
      features =
          FeaturesConfig.fromToml(toml['features'] as Map<String, dynamic>);
    }

    ScriptsConfig? scripts;
    if (toml['scripts'] is Map<String, dynamic>) {
      scripts = ScriptsConfig.fromToml(toml['scripts'] as Map<String, dynamic>);
    }

    return WorkspaceConfig(
      provider: provider,
      programs: programs,
      test: test,
      features: features,
      scripts: scripts,
      workspaceRoot: workspaceRoot,
    );
  }
  final ProviderConfig provider;
  final Map<String, Map<String, ProgramEntry>> programs;
  final TestConfig? test;
  final FeaturesConfig? features;
  final ScriptsConfig? scripts;
  final String? workspaceRoot;

  /// Get programs for the current cluster
  Map<String, ProgramEntry> getProgramsForCluster([String? cluster]) {
    cluster ??= provider.cluster;
    return programs[cluster] ?? {};
  }

  /// Get a specific program entry
  ProgramEntry? getProgram(String programName, [String? cluster]) {
    cluster ??= provider.cluster;
    return programs[cluster]?[programName];
  }

  /// Discover IDL files from the workspace structure
  List<String> discoverIdlFiles() {
    if (workspaceRoot == null) {
      throw const WorkspaceConfigException(
        'Cannot discover IDL files without workspace root',
      );
    }

    final idlDir = Directory(path.join(workspaceRoot!, 'target', 'idl'));
    if (!idlDir.existsSync()) {
      return [];
    }

    return idlDir
        .listSync()
        .where((entity) => entity is File && entity.path.endsWith('.json'))
        .map((entity) => entity.path)
        .toList();
  }

  /// Load IDL for a specific program
  Idl? loadProgramIdl(String programName, [String? cluster]) {
    final programEntry = getProgram(programName, cluster);
    if (programEntry == null) {
      return null;
    }

    String? idlPath;

    // Use explicit IDL path if provided
    if (programEntry.idl != null) {
      idlPath = programEntry.idl;
      if (!path.isAbsolute(idlPath ?? '') && workspaceRoot != null) {
        idlPath = path.join(workspaceRoot!, idlPath);
      }
    } else {
      // Auto-discover IDL file
      if (workspaceRoot == null) {
        return null;
      }

      final idlDir = Directory(path.join(workspaceRoot!, 'target', 'idl'));
      if (!idlDir.existsSync()) {
        return null;
      }

      // Look for snake_case version of program name
      final snakeCaseName = _camelToSnakeCase(programName);
      final possibleFiles = [
        '$snakeCaseName.json',
        '$programName.json',
      ];

      for (final fileName in possibleFiles) {
        final filePath = path.join(idlDir.path, fileName);
        if (File(filePath).existsSync()) {
          idlPath = filePath;
          break;
        }
      }

      // If not found, try to match camelCase version
      if (idlPath == null) {
        final files = idlDir
            .listSync()
            .where((entity) => entity is File && entity.path.endsWith('.json'))
            .map((entity) => path.basename(entity.path))
            .toList();

        for (final fileName in files) {
          final baseName = path.basenameWithoutExtension(fileName);
          if (_snakeToCamelCase(baseName) == programName) {
            idlPath = path.join(idlDir.path, fileName);
            break;
          }
        }
      }
    }

    if (idlPath == null || !File(idlPath).existsSync()) {
      return null;
    }

    try {
      final content = File(idlPath).readAsStringSync();
      final jsonData = json.decode(content) as Map<String, dynamic>;

      // Add program address if available
      if (programEntry.address != null && jsonData['address'] == null) {
        jsonData['address'] = programEntry.address;
      }

      return Idl.fromJson(jsonData);
    } catch (e) {
      throw WorkspaceConfigException(
        'Failed to load IDL from $idlPath',
        filePath: idlPath,
        cause: e,
      );
    }
  }

  /// Validate workspace configuration
  List<String> validate() {
    final errors = <String>[];

    // Validate provider configuration
    if (provider.cluster.isEmpty) {
      errors.add('Provider cluster cannot be empty');
    }

    if (provider.wallet.isEmpty) {
      errors.add('Provider wallet cannot be empty');
    }

    // Validate programs
    for (final entry in programs.entries) {
      final cluster = entry.key;
      final clusterPrograms = entry.value;

      if (cluster.isEmpty) {
        errors.add('Cluster name cannot be empty');
      }

      for (final programEntry in clusterPrograms.entries) {
        final programName = programEntry.key;
        final program = programEntry.value;

        if (programName.isEmpty) {
          errors.add('Program name cannot be empty');
        }

        // Validate IDL path if provided
        if (program.idl != null && workspaceRoot != null) {
          String idlPath = program.idl!;
          if (!path.isAbsolute(idlPath)) {
            idlPath = path.join(workspaceRoot!, idlPath);
          }

          if (!File(idlPath).existsSync()) {
            errors.add('IDL file not found: $idlPath');
          }
        }
      }
    }

    return errors;
  }

  /// Convert to TOML format
  Map<String, dynamic> toToml() {
    final result = <String, dynamic>{
      'provider': provider.toToml(),
    };

    if (programs.isNotEmpty) {
      result['programs'] = {};
      for (final entry in programs.entries) {
        final cluster = entry.key;
        final clusterPrograms = entry.value;

        result['programs'][cluster] = {};
        for (final programEntry in clusterPrograms.entries) {
          final programName = programEntry.key;
          final program = programEntry.value;
          result['programs'][cluster][programName] = program.toToml();
        }
      }
    }

    if (test != null) {
      result['test'] = test!.toToml();
    }

    if (features != null) {
      result['features'] = features!.toToml();
    }

    if (scripts != null) {
      result['scripts'] = scripts!.toToml();
    }

    return result;
  }

  /// Convert camelCase to snake_case
  String _camelToSnakeCase(String camelCase) => camelCase
      .replaceAllMapped(
        RegExp(r'([A-Z])'),
        (match) => '_${match.group(1)!.toLowerCase()}',
      )
      .replaceFirst(RegExp(r'^_'), '');

  /// Convert snake_case to camelCase
  String _snakeToCamelCase(String snakeCase) {
    final parts = snakeCase.split('_');
    if (parts.isEmpty) return snakeCase;

    final result = StringBuffer(parts.first);
    for (int i = 1; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        result.write(parts[i][0].toUpperCase());
        if (parts[i].length > 1) {
          result.write(parts[i].substring(1));
        }
      }
    }
    return result.toString();
  }
}

/// Advanced workspace discovery and initialization tools
class WorkspaceDiscovery {
  /// Discover all Anchor workspaces in a directory tree
  static List<String> discoverWorkspaces(String rootPath, {int maxDepth = 3}) {
    final workspaces = <String>[];
    _searchWorkspaces(Directory(rootPath), workspaces, 0, maxDepth);
    return workspaces;
  }

  /// Search for Anchor.toml files recursively
  static void _searchWorkspaces(
    Directory dir,
    List<String> workspaces,
    int currentDepth,
    int maxDepth,
  ) {
    if (currentDepth > maxDepth || !dir.existsSync()) {
      return;
    }

    // Check if current directory has Anchor.toml
    final anchorTomlPath = path.join(dir.path, 'Anchor.toml');
    if (File(anchorTomlPath).existsSync()) {
      workspaces.add(dir.path);
    }

    // Search subdirectories
    try {
      for (final entity in dir.listSync()) {
        if (entity is Directory) {
          _searchWorkspaces(entity, workspaces, currentDepth + 1, maxDepth);
        }
      }
    } catch (e) {
      // Skip directories we can't read
    }
  }

  /// Auto-detect workspace configuration based on directory structure
  static WorkspaceConfigTemplate? autoDetectTemplate(String workspacePath) {
    final dir = Directory(workspacePath);
    if (!dir.existsSync()) {
      return null;
    }

    // Check for common Anchor project structures
    final programsDir = Directory(path.join(workspacePath, 'programs'));
    final targetDir = Directory(path.join(workspacePath, 'target'));
    final testsDir = Directory(path.join(workspacePath, 'tests'));

    if (programsDir.existsSync() || targetDir.existsSync()) {
      return WorkspaceConfigTemplate(
        name: path.basename(workspacePath),
        type: WorkspaceType.anchor,
        hasPrograms: programsDir.existsSync(),
        hasTests: testsDir.existsSync(),
        hasBuild: targetDir.existsSync(),
        estimatedComplexity: _estimateComplexity(workspacePath),
      );
    }

    return null;
  }

  /// Estimate workspace complexity based on directory structure
  static WorkspaceComplexity _estimateComplexity(String workspacePath) {
    int programCount = 0;
    int testCount = 0;

    // Count programs
    final programsDir = Directory(path.join(workspacePath, 'programs'));
    if (programsDir.existsSync()) {
      programCount = programsDir.listSync().whereType<Directory>().length;
    }

    // Count test files
    final testsDir = Directory(path.join(workspacePath, 'tests'));
    if (testsDir.existsSync()) {
      testCount = testsDir
          .listSync()
          .where(
            (entity) =>
                entity is File &&
                (entity.path.endsWith('.ts') || entity.path.endsWith('.js')),
          )
          .length;
    }

    if (programCount > 5 || testCount > 10) {
      return WorkspaceComplexity.complex;
    } else if (programCount > 2 || testCount > 5) {
      return WorkspaceComplexity.medium;
    } else {
      return WorkspaceComplexity.simple;
    }
  }

  /// Validate workspace directory structure
  static WorkspaceValidationResult validateStructure(String workspacePath) {
    final issues = <String>[];
    final warnings = <String>[];

    // Check if Anchor.toml exists
    final anchorTomlPath = path.join(workspacePath, 'Anchor.toml');
    if (!File(anchorTomlPath).existsSync()) {
      issues.add('Missing Anchor.toml configuration file');
    }

    // Check for programs directory
    final programsDir = Directory(path.join(workspacePath, 'programs'));
    if (!programsDir.existsSync()) {
      warnings.add('No programs directory found');
    }

    // Check for target/idl directory
    final idlDir = Directory(path.join(workspacePath, 'target', 'idl'));
    if (!idlDir.existsSync()) {
      warnings.add('No target/idl directory found - programs may not be built');
    }

    return WorkspaceValidationResult(
      isValid: issues.isEmpty,
      issues: issues,
      warnings: warnings,
      workspacePath: workspacePath,
    );
  }

  /// Initialize a new workspace with template
  static Future<void> initializeWorkspace(
    String workspacePath,
    WorkspaceInitializationTemplate template,
  ) async {
    final dir = Directory(workspacePath);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }

    // Create Anchor.toml
    final anchorTomlPath = path.join(workspacePath, 'Anchor.toml');
    final anchorTomlContent = template.generateAnchorToml();
    await File(anchorTomlPath).writeAsString(anchorTomlContent);

    // Create directory structure
    if (template.createPrograms) {
      await Directory(path.join(workspacePath, 'programs')).create();
    }

    if (template.createTests) {
      await Directory(path.join(workspacePath, 'tests')).create();
    }

    if (template.createApp) {
      await Directory(path.join(workspacePath, 'app')).create();
    }

    // Create additional directories
    for (final dirName in template.additionalDirectories) {
      await Directory(path.join(workspacePath, dirName)).create();
    }
  }
}

/// Workspace configuration template detection
class WorkspaceConfigTemplate {
  const WorkspaceConfigTemplate({
    required this.name,
    required this.type,
    required this.hasPrograms,
    required this.hasTests,
    required this.hasBuild,
    required this.estimatedComplexity,
  });
  final String name;
  final WorkspaceType type;
  final bool hasPrograms;
  final bool hasTests;
  final bool hasBuild;
  final WorkspaceComplexity estimatedComplexity;
}

/// Workspace types
enum WorkspaceType {
  anchor,
  solana,
  unknown,
}

/// Workspace complexity levels
enum WorkspaceComplexity {
  simple,
  medium,
  complex,
}

/// Workspace validation result
class WorkspaceValidationResult {
  const WorkspaceValidationResult({
    required this.isValid,
    required this.issues,
    required this.warnings,
    required this.workspacePath,
  });
  final bool isValid;
  final List<String> issues;
  final List<String> warnings;
  final String workspacePath;

  @override
  String toString() =>
      'WorkspaceValidationResult(valid: $isValid, issues: ${issues.length}, warnings: ${warnings.length})';
}

/// Workspace initialization template
class WorkspaceInitializationTemplate {
  const WorkspaceInitializationTemplate({
    required this.name,
    this.cluster = 'localnet',
    this.wallet = '~/.config/solana/id.json',
    this.createPrograms = true,
    this.createTests = true,
    this.createApp = false,
    this.additionalDirectories = const [],
    this.customConfig = const {},
  });
  final String name;
  final String cluster;
  final String wallet;
  final bool createPrograms;
  final bool createTests;
  final bool createApp;
  final List<String> additionalDirectories;
  final Map<String, dynamic> customConfig;

  /// Generate Anchor.toml content
  String generateAnchorToml() {
    final buffer = StringBuffer();

    buffer.writeln('[provider]');
    buffer.writeln('cluster = "$cluster"');
    buffer.writeln('wallet = "$wallet"');
    buffer.writeln();

    buffer.writeln('[programs.$cluster]');
    buffer.writeln('# Add your programs here');
    buffer.writeln();

    if (createTests) {
      buffer.writeln('[test]');
      buffer.writeln('startup_wait = 5000');
      buffer.writeln();
    }

    // Add custom configuration
    for (final entry in customConfig.entries) {
      buffer.writeln('[${entry.key}]');
      if (entry.value is Map<String, dynamic>) {
        final map = entry.value as Map<String, dynamic>;
        for (final subEntry in map.entries) {
          buffer.writeln('${subEntry.key} = "${subEntry.value}"');
        }
      } else {
        buffer.writeln('value = "${entry.value}"');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Basic template for new projects
  static WorkspaceInitializationTemplate basic(String name) =>
      WorkspaceInitializationTemplate(name: name);

  /// Template for complex multi-program workspaces
  static WorkspaceInitializationTemplate multiProgram(String name) =>
      WorkspaceInitializationTemplate(
        name: name,
        createPrograms: true,
        createTests: true,
        createApp: true,
        additionalDirectories: ['scripts', 'migrations', 'docs'],
      );

  /// Template for client-side applications
  static WorkspaceInitializationTemplate clientApp(String name) =>
      WorkspaceInitializationTemplate(
        name: name,
        createPrograms: false,
        createTests: true,
        createApp: true,
        additionalDirectories: ['src', 'public'],
      );
}
